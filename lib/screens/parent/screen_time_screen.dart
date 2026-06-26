import 'package:flutter/material.dart';
import '../../services/screen_time_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  Map<String, dynamic> todayData = {};
  bool isLoading = true;
  int limitMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ScreenTimeService.getTodayScreenTime();
    setState(() {
      todayData = data;
      limitMinutes = data['limitMinutes'] ?? 30;
      isLoading = false;
    });
  }

  Future<void> _updateLimit(int newLimit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${user.uid}_$dateStr';

    await FirebaseFirestore.instance
        .collection('screenTime')
        .doc(docId)
        .set({'limitMinutes': newLimit}, SetOptions(merge: true));

    setState(() => limitMinutes = newLimit);
  }

  @override
  Widget build(BuildContext context) {
    final total = todayData['totalMinutes'] ?? 0;
    final limit = limitMinutes;
    final progress = (total / limit).clamp(0.0, 1.0);
    final limitReached = total >= limit;

    final progressColor = limitReached
        ? Colors.redAccent
        : progress >= 0.7
            ? const Color(0xFFFFAB40)
            : const Color(0xFF4DD9C0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: const Text('Screen Time',
            style: TextStyle(
                color: Color(0xFF333333), fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8FAB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Today's usage card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Today's Usage",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333)),
                        ),
                        const SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                backgroundColor: Colors.white,
                                color: progressColor,
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '$total',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: progressColor,
                                  ),
                                ),
                                const Text('minutes',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF888888))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          limitReached
                              ? '⚠️ Daily limit reached!'
                              : '${limit - total} minutes remaining',
                          style: TextStyle(
                            fontSize: 14,
                            color: limitReached
                                ? Colors.redAccent
                                : const Color(0xFF888888),
                            fontWeight: limitReached
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Set limit
                  const Text('Set Daily Limit',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [15, 30, 45, 60].map((mins) {
                      final isSelected = limitMinutes == mins;
                      return GestureDetector(
                        onTap: () => _updateLimit(mins),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8FAB)
                                : const Color(0xFFFFF3F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$mins min',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF888888),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}