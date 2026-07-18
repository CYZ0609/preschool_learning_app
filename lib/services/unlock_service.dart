import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks which sandbox items a student has unlocked, per Section 6 of the
/// spec ("Database Synchronization": writes isUnlocked: true).
class UnlockService {
  static Future<void> setUnlocked(String kidId, String word) async {
    await FirebaseFirestore.instance.collection('unlocks').doc(kidId).set({
      'words': {
        word: {'isUnlocked': true, 'unlockedAt': Timestamp.now()},
      },
    }, SetOptions(merge: true));
  }

  static Future<bool> isUnlocked(String kidId, String word) async {
    final doc = await FirebaseFirestore.instance.collection('unlocks').doc(kidId).get();
    if (!doc.exists) return false;
    final words = doc.data()?['words'] as Map<String, dynamic>? ?? {};
    return words[word]?['isUnlocked'] == true;
  }

  static Future<List<String>> loadUnlockedWords(String kidId) async {
    final doc = await FirebaseFirestore.instance.collection('unlocks').doc(kidId).get();
    if (!doc.exists) return [];
    final words = doc.data()?['words'] as Map<String, dynamic>? ?? {};
    return words.entries.where((e) => e.value['isUnlocked'] == true).map((e) => e.key).toList();
  }
}
