import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/screen_time_service.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  final TextEditingController _limitController = TextEditingController();
  List<Map<String, dynamic>> children = [];
  String? selectedKidId;
  String? selectedKidName;
  Map<String, dynamic> todayData = {};
  bool isLoading = true;
  int limitMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final parentUid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .collection('children')
        .get();

    final kids = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'name': doc.data()['name'] ?? 'Unknown',
            })
        .toList();

    setState(() {
      children = kids;
      if (kids.isNotEmpty) {
        selectedKidId = kids[0]['id'];
        selectedKidName = kids[0]['name'];
      }
    });

    await _loadScreenTime();
  }

  Future<void> _loadScreenTime() async {
    if (selectedKidId == null) return;
    final data = await ScreenTimeService.getTodayScreenTime(selectedKidId!);
    setState(() {
      todayData = data;
      limitMinutes = data['limitMinutes'] ?? 30;
      isLoading = false;
    });
  }

  Future<void> _updateLimit(int newLimit) async {
  if (selectedKidId == null) return;
  await ScreenTimeService.updateLimit(selectedKidId!, newLimit);
  setState(() => limitMinutes = newLimit);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Daily limit set to $newLimit minutes ✅'),
      backgroundColor: const Color(0xFF4DD9C0),
      duration: const Duration(seconds: 2),
    ),
  );
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
                  // Child selector
                  if (children.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedKidId,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFFFF8FAB)),
                          items: children.map((child) {
                            return DropdownMenuItem<String>(
                              value: child['id'],
                              child: Text(child['name']),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            setState(() {
                              selectedKidId = val;
                              selectedKidName = children
                                  .firstWhere((c) => c['id'] == val)['name'];
                              isLoading = true;
                            });
                            await _loadScreenTime();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
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
                        Text(
                          "${selectedKidName ?? 'Child'}'s Usage Today",
                          style: const TextStyle(
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
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text('Set Daily Limit',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333))),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4DD9C0).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Current: $limitMinutes min',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4DD9C0),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 16),
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _limitController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter minutes',
          suffixText: 'min',
          filled: true,
          fillColor: const Color(0xFFFFF3F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ),
    const SizedBox(width: 12),
    ElevatedButton(
      onPressed: () {
        final value = int.tryParse(_limitController.text);
        if (value != null && value > 0) {
          _updateLimit(value);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF8FAB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 18),
      ),
      child: const Text('Set',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  ],
),
const SizedBox(height: 12),
Wrap(
  spacing: 8,
  children: [15, 30, 45, 60].map((mins) {
    return GestureDetector(
      onTap: () => _updateLimit(mins),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: limitMinutes == mins
              ? const Color(0xFFFF8FAB)
              : const Color(0xFFFFF3F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$mins',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: limitMinutes == mins
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