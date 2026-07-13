import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/lesson_service.dart';

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
  final FlutterTts tts = FlutterTts();
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    // Speak the first word automatically so the child hears it right away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _speakCurrent() async {
    await tts.speak(widget.lesson.words[currentIndex].word);
  }

  void _next() {
    if (currentIndex < widget.lesson.words.length - 1) {
      setState(() => currentIndex++);
      _speakCurrent();
    } else {
      widget.onFinished();
    }
  }

  void _previous() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
      _speakCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.lesson.words[currentIndex];
    final isLast = currentIndex == widget.lesson.words.length - 1;

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
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _speakCurrent,
                            child: Container(
                              width: 220,
                              height: 220,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0FDF4),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4DD9C0).withOpacity(0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                word.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          GestureDetector(
                            onTap: _speakCurrent,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  word.word,
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A8C7A),
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.volume_up_rounded, color: Color(0xFF4DD9C0), size: 30),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the word or picture to hear it',
                            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (currentIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previous,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF4DD9C0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Back',
                                style: TextStyle(color: Color(0xFF4DD9C0), fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (currentIndex > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4DD9C0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isLast ? 'Start Quiz' : 'Next',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
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
