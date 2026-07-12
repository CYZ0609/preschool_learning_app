import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../home_screen.dart';
import 'listening_game_screen.dart';
import 'speaking_game_screen.dart';
import 'reading_game_screen.dart';
import 'writing_game_screen.dart';
import 'arithmetic_game_screen.dart';
import 'writing_tracing_screen.dart';
import '../../services/screen_time_service.dart';

class StudentHome extends StatefulWidget {
  final String kidName;
  final String ageGroup;
  final String kidId;
  final String parentId;

  const StudentHome({
    super.key,
    required this.kidName,
    required this.ageGroup,
    required this.kidId,
    required this.parentId,
  });

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> with WidgetsBindingObserver {
  DateTime? _startTime;
  Timer? _checkTimer;
  List<Map<String, dynamic>> allKids = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkScreenTimeLimit();
    });
  }

  @override
  void dispose() {
    _saveScreenTime();
    _checkTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadAllKids() async {
    try {
      final List<Map<String, dynamic>> kids = [];
      final parents = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get()
          .timeout(const Duration(seconds: 10));

      for (var parent in parents.docs) {
        final children = await FirebaseFirestore.instance
            .collection('users')
            .doc(parent.id)
            .collection('children')
            .get()
            .timeout(const Duration(seconds: 10));

        for (var child in children.docs) {
          kids.add({
            'id': child.id,
            'parentId': parent.id,
            'name': child.data()['name'] ?? 'Unknown',
            'ageGroup': child.data()['ageGroup'] ?? '4-5',
          });
        }
      }

      if (mounted) {
        setState(() {
          allKids = kids;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveScreenTime() async {
    if (_startTime == null) return;
    final minutes = DateTime.now().difference(_startTime!).inMinutes;
    if (minutes > 0) {
      await ScreenTimeService.updateScreenTime(minutes, widget.kidId);
    }
    _startTime = null;
  }

  Future<void> _checkScreenTimeLimit() async {
    // Logic for checking screen time limit
    final data = await ScreenTimeService.getTodayScreenTime(widget.kidId);
    final total = (data['totalMinutes'] ?? 0) as int;
    final limit = (data['limitMinutes'] ?? 30) as int;
    
    final currentSessionMinutes = _startTime == null
        ? 0
        : DateTime.now().difference(_startTime!).inMinutes;

    if (total + currentSessionMinutes >= limit) {
      // Show Dialog logic here if needed
    }
  }

  void _navigateToGame(BuildContext context, String subject) {
    Widget screen;
    switch (subject) {
      case 'listening':
        screen = ListeningGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'speaking':
        screen = SpeakingGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'reading':
        screen = ReadingGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'writing':
        screen = WritingGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'arithmetic':
        screen = ArithmeticGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      default:
        screen = ListeningGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFFFFB7C5), shape: BoxShape.circle))),
          Positioned(top: 20, right: 20, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFFFF8FAB), shape: BoxShape.circle))),
          Positioned(bottom: -40, left: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFF80DEEA), shape: BoxShape.circle))),
          Positioned(bottom: 20, left: 20, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFF4DD9C0), shape: BoxShape.circle))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                    ),
                    const SizedBox(height: 24),
                    Text('Hello, ${widget.kidName}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    const SizedBox(height: 8),
                    const Text('Topics', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                    const SizedBox(height: 20),
                    _subjectCard(context, icon: Icons.hearing_rounded, label: 'Listening Game', color: const Color(0xFFFFAB40), subject: 'listening'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.mic_rounded, label: 'Speaking Game', color: const Color(0xFFFF8FAB), subject: 'speaking'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.menu_book_rounded, label: 'Reading Game', color: const Color(0xFF4DD9C0), subject: 'reading'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.edit_rounded, label: 'Writing Game', color: const Color(0xFFFFAB40), subject: 'writing'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.calculate_rounded, label: 'Arithmetic Game', color: const Color(0xFFFF8FAB), subject: 'arithmetic'),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WritingTracingScreen(
                            word: 'CAT',
                            ageGroup: widget.ageGroup,
                          ),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4DD9C0).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF4DD9C0), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.draw_rounded, color: Colors.white, size: 24)),
                            const SizedBox(width: 16),
                            const Text('Test Tracing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4DD9C0))),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF4DD9C0), size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _saveScreenTime();
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF8FAB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Exit', style: TextStyle(color: Color(0xFFFF8FAB), fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(BuildContext context, {required IconData icon, required String label, required Color color, required String subject}) {
    return GestureDetector(
      onTap: () => _navigateToGame(context, subject),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}