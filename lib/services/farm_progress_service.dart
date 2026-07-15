import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks per-word "star" progress within the sandbox map experience,
/// scoped per subject so the same word text in two subjects doesn't
/// collide (per SCHEMA_SANDBOX_ENGINE.md).
class FarmProgressService {
  static CollectionReference<Map<String, dynamic>> _subjectDoc(String kidId, String subject) =>
      FirebaseFirestore.instance
          .collection('farmProgress')
          .doc(kidId)
          .collection('subjects');

  static Future<Map<String, int>> loadStars(String kidId, String subject) async {
    final doc = await _subjectDoc(kidId, subject).doc(subject).get();
    if (!doc.exists) return {};
    final words = (doc.data()?['words'] as Map<String, dynamic>? ?? {});
    return words.map((k, v) => MapEntry(k, (v['stars'] as num?)?.toInt() ?? 0));
  }

  static Future<void> setStars(String kidId, String subject, String word, int stars) async {
    await _subjectDoc(kidId, subject).doc(subject).set({
      'words': {
        word: {'stars': stars, 'lastPlayed': Timestamp.now()},
      },
    }, SetOptions(merge: true));
  }
}
