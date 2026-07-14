import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/lesson_service.dart';

/// Age 5-6: the screen is dark. The child's finger acts as a flashlight —
/// swiping around reveals scattered letters of the word. Once every letter
/// has been found, the full picture + word are revealed.
class FlashlightHuntCard extends StatefulWidget {
  final LessonWord word;
  final VoidCallback onComplete;

  const FlashlightHuntCard({super.key, required this.word, required this.onComplete});

  @override
  State<FlashlightHuntCard> createState() => _FlashlightHuntCardState();
}

class _LetterSpot {
  final String letter;
  final Offset position; // fractional (0..1) within the card
  bool found = false;
  _LetterSpot(this.letter, this.position);
}

class _FlashlightHuntCardState extends State<FlashlightHuntCard> {
  final FlutterTts tts = FlutterTts();
  Offset? beamPosition;
  late List<_LetterSpot> letters;
  bool revealed = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    final rand = Random();
    final chars = widget.word.word.split('');
    // Scatter letters at random-ish, non-overlapping fractional positions.
    letters = [];
    for (int i = 0; i < chars.length; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final jitterX = (rand.nextDouble() - 0.5) * 0.12;
      final jitterY = (rand.nextDouble() - 0.5) * 0.1;
      letters.add(_LetterSpot(
        chars[i],
        Offset(0.2 + col * 0.3 + jitterX, 0.25 + row * 0.3 + jitterY),
      ));
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  void _updateBeam(Offset localPos, Size size) {
    if (revealed) return;
    setState(() => beamPosition = localPos);
    for (final spot in letters) {
      if (spot.found) continue;
      final spotPx = Offset(spot.position.dx * size.width, spot.position.dy * size.height);
      if ((spotPx - localPos).distance < 45) {
        setState(() => spot.found = true);
        tts.speak(spot.letter);
      }
    }
    if (letters.every((s) => s.found) && !revealed) {
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
                      Image.asset(widget.word.imageAsset, width: 150, height: 150, fit: BoxFit.contain),
                      const SizedBox(height: 12),
                      Text(widget.word.word,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1A8C7A), letterSpacing: 3)),
                    ],
                  ),
                ),
              ),
              if (!revealed) ...[
                // Scattered letters, dimly visible so kids know roughly where to look.
                for (final spot in letters)
                  Positioned(
                    left: spot.position.dx * size.width - 20,
                    top: spot.position.dy * size.height - 20,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: spot.found ? const Color(0xFF80DEEA) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: spot.found
                            ? [BoxShadow(color: const Color(0xFF80DEEA).withOpacity(0.6), blurRadius: 12, spreadRadius: 2)]
                            : [],
                      ),
                      child: Text(spot.letter,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: spot.found ? Colors.white : const Color(0xFF333333))),
                    ),
                  ),
                GestureDetector(
                  onPanUpdate: (d) => _updateBeam(d.localPosition, size),
                  onPanStart: (d) => _updateBeam(d.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _DarknessPainter(beamPosition: beamPosition),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('Swipe to shine your flashlight! 🔦  (${letters.where((s) => s.found).length}/${letters.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DarknessPainter extends CustomPainter {
  final Offset? beamPosition;
  _DarknessPainter({required this.beamPosition});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black87);
    if (beamPosition != null) {
      canvas.drawCircle(
        beamPosition!,
        70,
        Paint()..blendMode = BlendMode.clear,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DarknessPainter oldDelegate) => true;
}
