import 'package:flutter/material.dart';
import '../../services/progress_service.dart';

class WritingGameScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  const WritingGameScreen({super.key, required this.ageGroup, required this.kidId});

  @override
  State<WritingGameScreen> createState() => _WritingGameScreenState();
}

class _WritingGameScreenState extends State<WritingGameScreen> {
  int currentItem = 0;
  int score = 0;
  List<Offset?> userPoints = [];
  bool checked = false;
  double coverage = 0.0;

  // true for 4-5 (letters, no picture needed), false for 5-7 (words + picture)
  late bool isLetterMode;
  late List<Map<String, String>> items;

  // 4-5: just the alphabet, no picture required — keeps it simple
  List<Map<String, String>> _generateLetters() {
    return List.generate(26, (i) {
      final letter = String.fromCharCode(65 + i); // A-Z
      return {'word': letter, 'image': ''};
    });
  }

  // 5-7: simple words with a picture for context
  List<Map<String, String>> _generateWords(String age) {
    switch (age) {
      case '5-6':
        return [
          {'word': 'CAT', 'image': 'assets/images/cat.png'},
          {'word': 'DOG', 'image': 'assets/images/dog.png'},
          {'word': 'SUN', 'image': 'assets/images/sun.png'},
          {'word': 'HAT', 'image': 'assets/images/hat.png'},
          {'word': 'PIG', 'image': 'assets/images/pig.png'},
          {'word': 'COW', 'image': 'assets/images/cow.png'},
          {'word': 'BIRD', 'image': 'assets/images/bird.png'},
          {'word': 'FROG', 'image': 'assets/images/frog.png'},
        ];
      case '6-7':
      default:
        return [
          {'word': 'APPLE', 'image': 'assets/images/apple.png'},
          {'word': 'RABBIT', 'image': 'assets/images/rabbit.png'},
          {'word': 'TABLE', 'image': 'assets/images/table.png'},
          {'word': 'WATER', 'image': 'assets/images/water.png'},
          {'word': 'BANANA', 'image': 'assets/images/banana.png'},
          {'word': 'MONKEY', 'image': 'assets/images/monkey.png'},
          {'word': 'PENCIL', 'image': 'assets/images/pencil.png'},
          {'word': 'FLOWER', 'image': 'assets/images/flower.png'},
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    // 4-5 -> letters only. 5-6 and 6-7 -> simple words with a picture.
    isLetterMode = widget.ageGroup == '4-5';
    items = isLetterMode ? _generateLetters() : _generateWords(widget.ageGroup);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      userPoints.add(local);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      userPoints.add(null); // stroke break
    });
  }

  void _clearDrawing() {
    setState(() {
      userPoints = [];
      checked = false;
      coverage = 0.0;
    });
  }

  // Compares user strokes against the guide text's sampled points.
  void _checkTracing() {
    final text = items[currentItem]['word']!;
    final guidePoints = _GuideTextPainter(text: text, isLetterMode: isLetterMode).samplePoints();

    if (userPoints.where((p) => p != null).isEmpty || guidePoints.isEmpty) {
      setState(() {
        checked = true;
        coverage = 0.0;
      });
      return;
    }

    int covered = 0;
    final tolerance = isLetterMode ? 30.0 : 22.0;
    for (final gp in guidePoints) {
      final hit = userPoints.any((up) => up != null && (up - gp).distance < tolerance);
      if (hit) covered++;
    }

    final pct = covered / guidePoints.length;
    setState(() {
      checked = true;
      coverage = pct;
      if (pct >= 0.55) score++;
    });
  }

  void _nextItem() {
    if (currentItem < items.length - 1) {
      setState(() {
        currentItem++;
        userPoints = [];
        checked = false;
        coverage = 0.0;
      });
    } else {
      _showResult();
    }
  }

  void _showResult() {
    ProgressService.saveProgress(
      subject: 'writing',
      module: 'writing',
      ageGroup: widget.ageGroup,
      score: score,
      totalQuestions: items.length,
      kidId: widget.kidId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tracing Complete!',
            textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score / ${items.length}',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFFFAB40)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final starsEarned = score == items.length
                    ? 3
                    : score >= (items.length * 0.6).ceil()
                        ? 2
                        : 1;
                return Icon(
                  Icons.star_rounded,
                  size: 40,
                  color: i < starsEarned ? const Color(0xFFFFC107) : const Color(0xFFE0E0E0),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              score == items.length
                  ? (isLetterMode ? 'Perfect letters!' : 'Perfect spelling!')
                  : score >= (items.length * 0.6).ceil()
                      ? 'Great writing!'
                      : 'Keep practicing!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888)),
            ),
          ],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Menu', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = items[currentItem];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFFFFB7C5), shape: BoxShape.circle))),
          Positioned(bottom: -40, left: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFF80DEEA), shape: BoxShape.circle))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                      ),
                      const Spacer(),
                      Text('${currentItem + 1} / ${items.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF888888))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(items.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentItem ? const Color(0xFFFFAB40) : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Only show a picture in word mode (5-7). Letters skip the image.
                  if (!isLetterMode) ...[
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(item['image']!, fit: BoxFit.contain)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    isLetterMode ? 'Trace the letter!' : 'Trace the word!',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF888888), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFFE0B2), width: 2),
                      ),
                      child: GestureDetector(
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _TracingPainter(
                            text: item['word']!,
                            userPoints: userPoints,
                            isLetterMode: isLetterMode,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (checked) ...[
                    const SizedBox(height: 12),
                    Text(
                      coverage >= 0.55
                          ? 'Nice tracing! ${(coverage * 100).round()}% covered'
                          : 'Try to follow the guide more closely (${(coverage * 100).round()}%)',
                      style: TextStyle(
                        color: coverage >= 0.55 ? const Color(0xFF4DD9C0) : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearDrawing,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFFFAB40)),
                          ),
                          child: const Text('Clear', style: TextStyle(color: Color(0xFFFFAB40), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: checked ? _nextItem : _checkTracing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAB40),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(checked ? 'Next' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

/// Draws the hollow guide letter(s)/word with tracing dots, plus the kid's strokes on top.
class _TracingPainter extends CustomPainter {
  final String text;
  final List<Offset?> userPoints;
  final bool isLetterMode;

  _TracingPainter({required this.text, required this.userPoints, required this.isLetterMode});

  @override
  void paint(Canvas canvas, Size size) {
    // Bigger font for single letters (4-5), smaller for full words (5-7)
    final fontSize = isLetterMode
        ? (size.height * 0.6).clamp(80.0, 220.0)
        : (size.width / (text.length + 1)).clamp(36.0, 90.0);

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: isLetterMode ? 0 : 8,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLetterMode ? 3 : 2
        ..color = const Color(0xFFFFC987),
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width - 20);
    final offset = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );
    tp.paint(canvas, offset);

    // Dots along the baseline for a "tracing book" feel
    final dotPaint = Paint()..color = const Color(0xFFFFD699);
    for (double x = offset.dx; x < offset.dx + tp.width; x += 14) {
      canvas.drawCircle(Offset(x, offset.dy + tp.height * 0.82), 1.8, dotPaint);
    }

    // Kid's drawn strokes
    final strokePaint = Paint()
      ..color = const Color(0xFF4DD9C0)
      ..strokeWidth = isLetterMode ? 10 : 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < userPoints.length - 1; i++) {
      final p1 = userPoints[i];
      final p2 = userPoints[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter old) => true;
}

/// Samples approximate guide-text pixel positions for coverage scoring.
class _GuideTextPainter {
  final String text;
  final bool isLetterMode;
  _GuideTextPainter({required this.text, required this.isLetterMode});

  List<Offset> samplePoints() {
    final fontSize = isLetterMode ? 160.0 : 70.0;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: isLetterMode ? 0 : 8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final points = <Offset>[];
    for (double x = 0; x < tp.width; x += 6) {
      // sample a vertical band through the middle of the text for rough coverage
      for (double y = tp.height * 0.2; y < tp.height * 0.8; y += 10) {
        points.add(Offset(x, y));
      }
    }
    return points;
  }
}