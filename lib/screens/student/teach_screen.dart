import 'package:flutter/material.dart';
import '../../services/lesson_service.dart';
import 'games/scratch_reveal_card.dart';
import 'games/flashlight_hunt_card.dart';
import 'games/sentence_builder_card.dart';

/// Shown to a student before their quiz when a teacher has attached a
/// Lesson to the assignment. Swipe/tap through the words one at a time;
/// each card speaks the word aloud. After the last card, [onFinished] is
/// called (the caller decides what happens next, e.g. start the quiz).
class TeachScreen extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onFinished;

  const TeachScreen({super.key, required this.lesson, required this.onFinished});

  @override
  State<TeachScreen> createState() => _TeachScreenState();
}

class _TeachScreenState extends State<TeachScreen> {
  int currentIndex = 0;

  void _next() {
    if (currentIndex < widget.lesson.words.length - 1) {
      setState(() => currentIndex++);
    } else {
      widget.onFinished();
    }
  }

  // Picks the right mini-game for the lesson's age group. Keyed by
  // currentIndex so each word gets a fresh game instance (not reused state).
  Widget _buildGameForWord(LessonWord word) {
    switch (widget.lesson.ageGroup) {
      case '4-5':
        return ScratchRevealCard(key: ValueKey(currentIndex), word: word, onComplete: _next);
      case '5-6':
        return FlashlightHuntCard(key: ValueKey(currentIndex), word: word, onComplete: _next);
      case '6-7':
        return SentenceBuilderCard(key: ValueKey(currentIndex), word: word, onComplete: _next);
      default:
        return ScratchRevealCard(key: ValueKey(currentIndex), word: word, onComplete: _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.lesson.words[currentIndex];

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(widget.lesson.words.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentIndex ? const Color(0xFF4DD9C0) : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Word ${currentIndex + 1} of ${widget.lesson.words.length}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.lesson.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildGameForWord(word)),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _next,
                      child: const Text('Skip this word',
                          style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
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
}
