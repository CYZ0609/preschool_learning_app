import 'package:cloud_firestore/cloud_firestore.dart';

class ScreenTimeService {
  static Future<void> updateScreenTime(int minutes, String kidId) async {
    if (kidId.isEmpty) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${kidId}_$dateStr';

    final ref =
        FirebaseFirestore.instance.collection('screenTime').doc(docId);
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
        'kidId': kidId,
        'date': dateStr,
        'totalMinutes': minutes,
        'limitMinutes': 30,
        'limitReached': false,
      });
    }
  }

  static Future<Map<String, dynamic>> getTodayScreenTime(String kidId) async {
    if (kidId.isEmpty) {
      return {'totalMinutes': 0, 'limitMinutes': 30, 'limitReached': false};
    }

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${kidId}_$dateStr';

    final doc = await FirebaseFirestore.instance
        .collection('screenTime')
        .doc(docId)
        .get();

    if (doc.exists) return doc.data() ?? {};
    return {'totalMinutes': 0, 'limitMinutes': 30, 'limitReached': false};
  }

  static Future<void> updateLimit(String kidId, int newLimit) async {
    if (kidId.isEmpty) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${kidId}_$dateStr';

    await FirebaseFirestore.instance
        .collection('screenTime')
        .doc(docId)
        .set({'limitMinutes': newLimit}, SetOptions(merge: true));
  }
}