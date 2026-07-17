import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/lesson_service.dart';
import 'world_map_screen.dart';

/// Phase 2: the top-down grid sandbox for one biome, in Play Mode.
/// - Terrain is a themed grid (CustomPainter, one paint call — not 400
///   individual widgets, for performance).
/// - A locked "Magic Supply Trunk" sits at grid-center holding the
///   assigned lesson's words; tapping it opens the word list, and tapping
///   a locked word is meant to launch the Universal Learning Panel
///   (Phase 3 — [onOpenWord] is the hook for that, not yet built).
/// - A few animals wander the grid on a timer, bouncing off the trunk's
///   footprint and the grid edges, flipping horizontally when blocked.
class BiomeSandboxScreen extends StatefulWidget {
  final Biome biome;
  final Lesson lesson;
  final String kidId;
  final void Function(LessonWord word) onOpenWord;

  const BiomeSandboxScreen({
    super.key,
    required this.biome,
    required this.lesson,
    required this.kidId,
    required this.onOpenWord,
  });

  @override
  State<BiomeSandboxScreen> createState() => _BiomeSandboxScreenState();
}

class _RoamingAnimal {
  double gridX, gridY;
  bool facingRight = true;
  final String emoji;
  _RoamingAnimal({required this.gridX, required this.gridY, required this.emoji});
}

class _BiomeSandboxScreenState extends State<BiomeSandboxScreen> {
  static const int gridCols = 20;
  static const int gridRows = 20;
  static const double cellSize = 48;

  // Trunk footprint: 3x3, roughly centered horizontally, near the top.
  static const int trunkX = (gridCols ~/ 2) - 1;
  static const int trunkY = 2;
  static const int trunkSize = 3;

  late List<_RoamingAnimal> animals;
  Timer? _roamTimer;
  final Random rand = Random();
  final TransformationController _viewController = TransformationController();

  @override
  void initState() {
    super.initState();
    animals = List.generate(3, (i) {
      return _RoamingAnimal(
        gridX: (5 + i * 4).toDouble(),
        gridY: (gridRows - 4).toDouble(),
        emoji: ['🐔', '🐑', '🐰'][i % 3],
      );
    });
    _roamTimer = Timer.periodic(const Duration(seconds: 2, milliseconds: 500), (_) => _stepAnimals());

    // Lock the initial camera on the trunk, per the spec.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dx = (trunkX + trunkSize / 2) * cellSize - 150;
      final dy = (trunkY + trunkSize / 2) * cellSize - 150;
      _viewController.value = Matrix4.identity()..translate(-dx, -dy);
    });
  }

  @override
  void dispose() {
    _roamTimer?.cancel();
    super.dispose();
  }

  bool _isTrunkCell(int x, int y) =>
      x >= trunkX && x < trunkX + trunkSize && y >= trunkY && y < trunkY + trunkSize;

  bool _isBlocked(int x, int y) {
    if (x < 0 || x >= gridCols || y < 0 || y >= gridRows) return true;
    return _isTrunkCell(x, y);
  }

  void _stepAnimals() {
    setState(() {
      for (final animal in animals) {
        final dir = rand.nextInt(4);
        int dx = 0, dy = 0;
        switch (dir) {
          case 0: dx = 1; break;
          case 1: dx = -1; break;
          case 2: dy = 1; break;
          case 3: dy = -1; break;
        }
        final targetX = animal.gridX.round() + dx;
        final targetY = animal.gridY.round() + dy;
        if (!_isBlocked(targetX, targetY)) {
          animal.gridX = targetX.toDouble();
          animal.gridY = targetY.toDouble();
          if (dx != 0) animal.facingRight = dx > 0;
        }
        // If blocked, animal just stays put this tick (a tiny "bounce" is
        // implied by the AnimatedPositioned curve not moving) and will
        // pick a fresh random direction next tick.
      }
    });
  }

  void _openTrunk() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Magic Supply Trunk ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.lesson.words.map((word) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onOpenWord(word);
                    },
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ]), // grayscale — item art shown locked/desaturated
                              child: SizedBox(
                                width: 64, height: 64,
                                child: Image.asset(word.imageAsset, fit: BoxFit.contain),
                              ),
                            ),
                            const Icon(Icons.lock_rounded, color: Colors.black54, size: 22),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(word.word, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Return to main map?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _viewController,
            minScale: 0.8,
            maxScale: 2.5,
            boundaryMargin: EdgeInsets.zero,
            constrained: false,
            child: SizedBox(
              width: gridCols * cellSize,
              height: gridRows * cellSize,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(gridCols * cellSize, gridRows * cellSize),
                    painter: _TerrainPainter(biome: widget.biome, cols: gridCols, rows: gridRows, cellSize: cellSize),
                  ),
                  // Trunk landmark
                  Positioned(
                    left: trunkX * cellSize,
                    top: trunkY * cellSize,
                    child: GestureDetector(
                      onTap: _openTrunk,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) => Transform.translate(
                          offset: Offset(0, -4 * (0.5 - (value - 0.5).abs()) * 2),
                          child: child,
                        ),
                        child: Container(
                          width: trunkSize * cellSize,
                          height: trunkSize * cellSize,
                          alignment: Alignment.center,
                          child: const Text('🎁', style: TextStyle(fontSize: 56)),
                        ),
                      ),
                    ),
                  ),
                  // Roaming animals
                  for (final animal in animals)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                      left: animal.gridX * cellSize,
                      top: animal.gridY * cellSize,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(animal.facingRight ? 1.0 : -1.0, 1.0),
                        child: Text(animal.emoji, style: const TextStyle(fontSize: 36)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _confirmExit,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.map_rounded, color: Color(0xFF333333)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerrainPainter extends CustomPainter {
  final Biome biome;
  final int cols, rows;
  final double cellSize;
  _TerrainPainter({required this.biome, required this.cols, required this.rows, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = biome.color.withOpacity(0.85);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    final gridLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int x = 0; x <= cols; x++) {
      canvas.drawLine(Offset(x * cellSize, 0), Offset(x * cellSize, rows * cellSize), gridLinePaint);
    }
    for (int y = 0; y <= rows; y++) {
      canvas.drawLine(Offset(0, y * cellSize), Offset(cols * cellSize, y * cellSize), gridLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter oldDelegate) => false;
}
