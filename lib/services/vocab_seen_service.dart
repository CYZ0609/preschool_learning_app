import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks which vocabulary words a kid has already seen inside the
/// sandbox Inventory, so the game can show a "new content" prompt (the
/// yellow exclamation mark above the Trunk) whenever a teacher adds new
/// custom words the kid hasn't looked at yet.
///
/// Storage: one small document per kid, `vocabSeen/{kidId}`, holding a
/// flat list of word strings already seen. This is intentionally
/// separate from [UnlockService] — "seen" and "unlocked" are different
/// concepts: a word can be visible-but-locked in the Inventory (so the
/// child knows it exists and can go practice it) without being unlocked.
class VocabSeenService {
  static final _docs = FirebaseFirestore.instance.collection('vocabSeen');

  static Future<Set<String>> loadSeenWords(String kidId) async {
    try {
      final doc = await _docs.doc(kidId).get();
      if (!doc.exists) return {};
      final words = (doc.data()?['words'] as List<dynamic>? ?? []);
      return words.map((w) => w.toString()).toSet();
    } catch (e) {
      // Fail safe: if this read fails, act as if nothing has been seen
      // yet rather than crashing the sandbox over a notification badge.
      return {};
    }
  }

  /// Marks every word in [words] as seen (merges with whatever was
  /// already recorded — never shrinks the seen set).
  static Future<void> markWordsSeen(String kidId, Iterable<String> words) async {
    if (words.isEmpty) return;
    try {
      final existing = await loadSeenWords(kidId);
      final merged = {...existing, ...words}.toList();
      await _docs.doc(kidId).set({'words': merged}, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal — worst case the exclamation mark reappears next
      // session and gets re-dismissed. Never let this crash the game.
    }
  }
}
