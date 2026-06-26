import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  static Future<void> saveProgress({
    required String subject,
    required String module,
    required String ageGroup,
    required int score,
    required int totalQuestions,
    int difficultyLevel = 1, // 1. 根据截图要求，新增了 difficultyLevel 可选参数，并设定默认值为 1
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
      'studentUid': user.uid,
      'subject': subject,
      'module': module,
      'ageGroup': ageGroup,
      'score': score,
      'totalQuestions': totalQuestions,
      'accuracy': accuracy,
      'difficultyLevel': difficultyLevel, // 2. 这里修改为了写入你传进来的动态难度级别
      'starsEarned': starsEarned,
      'sessionDate': Timestamp.now(),
    });
  }
}