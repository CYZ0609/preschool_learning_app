import 'package:flutter/material.dart';
import 'listening_game_screen.dart';
import 'speaking_game_screen.dart';
import 'reading_game_screen.dart';
import 'writing_game_screen.dart';
import 'arithmetic_game_screen.dart';

class AgeSelectionScreen extends StatelessWidget {
  const AgeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB7C5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFFF8FAB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFF80DEEA),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF4DD9C0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'How old are you?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your age group',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 48),
                  _ageCard(
                    context,
                    label: '4 - 5',
                    subtitle: 'Beginner',
                    color: const Color(0xFFFFAB40),
                    ageGroup: '4-5',
                  ),
                  const SizedBox(height: 16),
                  _ageCard(
                    context,
                    label: '5 - 6',
                    subtitle: 'Elementary',
                    color: const Color(0xFFFF8FAB),
                    ageGroup: '5-6',
                  ),
                  const SizedBox(height: 16),
                  _ageCard(
                    context,
                    label: '6 - 7',
                    subtitle: 'Intermediate',
                    color: const Color(0xFF4DD9C0),
                    ageGroup: '6-7',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ageCard(
    BuildContext context, {
    required String label,
    required String subtitle,
    required Color color,
    required String ageGroup,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to subject menu, pass ageGroup
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectMenuScreen(ageGroup: ageGroup),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.child_care_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age $label',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

class SubjectMenuScreen extends StatelessWidget {
  final String ageGroup;
  const SubjectMenuScreen({super.key, required this.ageGroup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB7C5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFFF8FAB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFF80DEEA),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF4DD9C0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Let's Play!",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age group: $ageGroup',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _subjectCard(
                    context,
                    icon: Icons.hearing_rounded,
                    label: 'Listening Game',
                    color: const Color(0xFFFFAB40),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ListeningGameScreen(ageGroup: ageGroup),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _subjectCard(
                    context,
                    icon: Icons.mic_rounded,
                    label: 'Speaking Game',
                    color: const Color(0xFFFF8FAB),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SpeakingGameScreen(ageGroup: ageGroup),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _subjectCard(
                    context,
                    icon: Icons.menu_book_rounded,
                    label: 'Reading Game',
                    color: const Color(0xFF4DD9C0),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadingGameScreen(ageGroup: ageGroup),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _subjectCard(
                    context,
                    icon: Icons.edit_rounded,
                    label: 'Writing Game',
                    color: const Color(0xFFFFAB40),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WritingGameScreen(ageGroup: ageGroup),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _subjectCard(
                    context,
                    icon: Icons.calculate_rounded,
                    label: 'Arithmetic Game',
                    color: const Color(0xFFFF8FAB),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArithmeticGameScreen(ageGroup: ageGroup),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}