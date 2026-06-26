import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScreenTimeService {
  static Future<void> updateScreenTime(int minutes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${user.uid}_$dateStr';

    final ref = FirebaseFirestore.instance.collection('screenTime').doc(docId);
    final doc = await ref.get();

    if (doc.exists) {
      final current = (doc.data()?['totalMinutes'] ?? 0) as int;
      final limit = (doc.data()?['limitMinutes'] ?? 30) as int;
      await ref.update({
        'totalMinutes': current + minutes,
        'limitReached': (current + minutes) >= limit,
      });
    } else {
      await ref.set({
        'studentUid': user.uid,
        'date': dateStr,
        'totalMinutes': minutes,
        'limitMinutes': 30,
        'limitReached': false,
      });
    }
  }

  static Future<Map<String, dynamic>> getTodayScreenTime() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${user.uid}_$dateStr';

    final doc = await FirebaseFirestore.instance
        .collection('screenTime')
        .doc(docId)
        .get();

    if (doc.exists) return doc.data() ?? {};
    return {'totalMinutes': 0, 'limitMinutes': 30, 'limitReached': false};
  }
}