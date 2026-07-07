import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WritingTracingScreen extends StatefulWidget {
  final String word;
  final String ageGroup;
  const WritingTracingScreen({super.key, required this.word, required this.ageGroup});

  @override
  State<WritingTracingScreen> createState() => _WritingTracingScreenState();
}

class _WritingTracingScreenState extends State<WritingTracingScreen> {
  final FlutterTts tts = FlutterTts();
  int currentLetterIndex = 0;
  List<List<Offset>> strokes = [];
  List<Offset> currentStroke = [];
  bool letterCompleted = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    _speakWord();
  }

  Future<void> _speakWord() async {
    await tts.speak(widget.word);
  }

  Future<void> _speakLetter(String letter) async {
    await tts.speak(letter);
  }

  void _nextLetter() {
    if (currentLetterIndex < widget.word.length - 1) {
      setState(() {
        currentLetterIndex++;
        strokes = [];
        currentStroke = [];
        letterCompleted = false;
      });
      _speakLetter(widget.word[currentLetterIndex]);
    } else {
      _showCompleteDialog();
    }
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Great job! ✅',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'You wrote "${widget.word}" correctly!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFAB40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done!',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLetter = widget.word[currentLetterIndex];

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
                  // Progress
                  Row(
                    children: List.generate(widget.word.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentLetterIndex
                                ? const Color(0xFFFFAB40)
                                : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Word display
                  Center(
                    child: GestureDetector(
                      onTap: _speakWord,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(widget.word.length, (i) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: i == currentLetterIndex
                                    ? const Color(0xFFFFAB40)
                                    : i < currentLetterIndex
                                        ? const Color(0xFF4DD9C0)
                                        : const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.word[i],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: i <= currentLetterIndex
                                      ? Colors.white
                                      : const Color(0xFF888888),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          const Icon(Icons.volume_up_rounded, color: Color(0xFFFFAB40)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Trace the letter "$currentLetter"',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tracing area
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9F0),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFFAB40).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            // Ghost letter (guide)
                            Center(
                              child: Text(
                                currentLetter,
                                style: TextStyle(
                                  fontSize: 200,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFAB40).withOpacity(0.15),
                                ),
                              ),
                            ),
                            // Drawing area
                            GestureDetector(
                              onPanStart: (details) {
                                setState(() {
                                  currentStroke = [details.localPosition];
                                });
                              },
                              onPanUpdate: (details) {
                                setState(() {
                                  currentStroke.add(details.localPosition);
                                });
                              },
                              onPanEnd: (details) {
                                setState(() {
                                  strokes.add(List.from(currentStroke));
                                  currentStroke = [];
                                  letterCompleted = true;
                                });
                              },
                              child: CustomPaint(
                                painter: _TracingPainter(
                                  strokes: strokes,
                                  currentStroke: currentStroke,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Clear button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              strokes = [];
                              currentStroke = [];
                              letterCompleted = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFAB40)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Clear',
                              style: TextStyle(
                                  color: Color(0xFFFFAB40),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Next button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: letterCompleted ? _nextLetter : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAB40),
                            disabledBackgroundColor: const Color(0xFFEEEEEE),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            currentLetterIndex < widget.word.length - 1
                                ? 'Next Letter →'
                                : 'Done! ✅',
                            style: TextStyle(
                              color: letterCompleted
                                  ? Colors.white
                                  : const Color(0xFF888888),
                              fontWeight: FontWeight.bold,
                            ),
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

class _TracingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _TracingPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF8FAB)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}