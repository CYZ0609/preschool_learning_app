import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/lesson_service.dart';

/// Age 4-5: the picture is hidden under a "mist" layer. The child drags a
/// finger across the screen to wipe the mist away; once enough of it is
/// cleared, the picture + word are fully revealed and spoken aloud.
class ScratchRevealCard extends StatefulWidget {
  final LessonWord word;
  final VoidCallback onComplete;

  const ScratchRevealCard({super.key, required this.word, required this.onComplete});

  @override
  State<ScratchRevealCard> createState() => _ScratchRevealCardState();
}

class _ScratchRevealCardState extends State<ScratchRevealCard> {
  final FlutterTts tts = FlutterTts();
  final List<Offset> erasedPoints = [];
  bool revealed = false;

  static const int gridSize = 12;
  late List<List<bool>> touchedGrid;

  @override
  void initState() {
    super.initState();
    touchedGrid = List.generate(gridSize, (_) => List.filled(gridSize, false));
    tts.setLanguage('en-US');
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  void _onDrag(Offset localPos, Size size) {
    if (revealed) return;
    setState(() {
      erasedPoints.add(localPos);
      final gx = (localPos.dx / size.width * gridSize).floor().clamp(0, gridSize - 1);
      final gy = (localPos.dy / size.height * gridSize).floor().clamp(0, gridSize - 1);
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final nx = gx + dx, ny = gy + dy;
          if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
            touchedGrid[ny][nx] = true;
          }
        }
      }
    });

    final touchedCount = touchedGrid.expand((r) => r).where((t) => t).length;
    if (touchedCount / (gridSize * gridSize) > 0.45 && !revealed) {
      _reveal();
    }
  }

  void _reveal() {
    setState(() => revealed = true);
    tts.speak(widget.word.word);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0xFFE0FDF4),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(widget.word.imageAsset, width: 160, height: 160, fit: BoxFit.contain),
                      const SizedBox(height: 16),
                      Text(
                        widget.word.word,
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF1A8C7A), letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
              ),
              if (!revealed)
                GestureDetector(
                  onPanUpdate: (details) => _onDrag(details.localPosition, size),
                  onPanStart: (details) => _onDrag(details.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _MistPainter(erasedPoints: erasedPoints),
                  ),
                ),
              if (!revealed)
                const Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('Wipe the mist away! ✨',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MistPainter extends CustomPainter {
  final List<Offset> erasedPoints;
  _MistPainter({required this.erasedPoints});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    final mistPaint = Paint()..color = const Color(0xFFB0BEC5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), mistPaint);

    final erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 55
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < erasedPoints.length; i++) {
      canvas.drawCircle(erasedPoints[i], 30, erasePaint);
      if (i > 0) {
        canvas.drawLine(erasedPoints[i - 1], erasedPoints[i], erasePaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MistPainter oldDelegate) => true;
}
