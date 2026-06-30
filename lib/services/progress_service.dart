import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  static Future<void> saveProgress({
    required String subject,
    required String module,
    required String ageGroup,
    required int score,
    required int totalQuestions,
    int difficultyLevel = 1,
    String? kidId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final accuracy = totalQuestions == 0 ? 0.0 : score / totalQuestions;
    final starsEarned = accuracy == 1.0
        ? 3
        : accuracy >= 0.6
            ? 2
            : 1;

    await FirebaseFirestore.instance.collection('progress').add({
      'studentUid': kidId ?? user.uid,
      'subject': subject,
      'module': module,
      'ageGroup': ageGroup,
      'score': score,
      'totalQuestions': totalQuestions,
      'accuracy': accuracy,
      'difficultyLevel': difficultyLevel,
      'starsEarned': starsEarned,
      'sessionDate': Timestamp.now(),
    });
  }

  static Future<int> getDifficultyLevel(String module, String ageGroup) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 1;

    final doc = await FirebaseFirestore.instance
        .collection('difficulty')
        .doc('${user.uid}_${module}_$ageGroup')
        .get();

    if (doc.exists) return doc.data()?['level'] ?? 1;
    return 1;
  }

  static Future<void> updateDifficultyLevel(
      String module, String ageGroup, int newLevel) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('difficulty')
        .doc('${user.uid}_${module}_$ageGroup')
        .set({'level': newLevel});
  }
}