import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/lesson_service.dart';
import '../../../services/unlock_service.dart';

enum _FinaleStage { locked, cracking, shattering, colorAwaken, flyToBackpack, done }

/// Section 6: the reward payoff shown after finishing the final required
/// step of the Universal Learning Panel. Independent cinematic canvas:
/// locked grayscale silhouette -> crack -> shatter -> color awakening ->
/// flies into the backpack corner -> writes isUnlocked:true to Firestore.
class UnlockFinaleScreen extends StatefulWidget {
  final LessonWord word;
  final String kidId;
  final VoidCallback onDone;

  const UnlockFinaleScreen({
    super.key,
    required this.word,
    required this.kidId,
    required this.onDone,
  });

  @override
  State<UnlockFinaleScreen> createState() => _UnlockFinaleScreenState();
}

class _UnlockFinaleScreenState extends State<UnlockFinaleScreen> with TickerProviderStateMixin {
  _FinaleStage stage = _FinaleStage.locked;
  late AnimationController shakeController;
  late AnimationController colorController;
  final List<_Particle> particles = [];
  final Random rand = Random();

  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    colorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _runSequence();
  }

  @override
  void dispose() {
    shakeController.dispose();
    colorController.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => stage = _FinaleStage.cracking);
    await shakeController.forward(from: 0);
    if (!mounted) return;

    setState(() {
      stage = _FinaleStage.shattering;
      particles.addAll(List.generate(24, (i) {
        final angle = (i / 24) * 2 * pi + rand.nextDouble() * 0.3;
        return _Particle(angle: angle, speed: 60 + rand.nextDouble() * 40);
      }));
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => stage = _FinaleStage.colorAwaken);
    await colorController.forward(from: 0);
    if (!mounted) return;

    await UnlockService.setUnlocked(widget.kidId, widget.word.word);
    if (!mounted) return;

    setState(() => stage = _FinaleStage.flyToBackpack);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => stage = _FinaleStage.done);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isFlying = stage == _FinaleStage.flyToBackpack || stage == _FinaleStage.done;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInBack,
              alignment: isFlying ? Alignment.bottomRight : Alignment.center,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInBack,
                scale: isFlying ? 0.15 : 1.0,
                child: Padding(
                  padding: EdgeInsets.only(right: isFlying ? 24 : 0, bottom: isFlying ? 24 : 0),
                  child: AnimatedBuilder(
                    animation: shakeController,
                    builder: (context, child) {
                      final shakeOffset = stage == _FinaleStage.cracking
                          ? sin(shakeController.value * pi * 10) * 6
                          : 0.0;
                      return Transform.translate(offset: Offset(shakeOffset, 0), child: child);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: colorController,
                          builder: (context, child) {
                            final t = stage.index >= _FinaleStage.colorAwaken.index ? colorController.value : 0.0;
                            return ColorFiltered(
                              colorFilter: ColorFilter.matrix(_grayscaleMatrix(1 - t)),
                              child: child,
                            );
                          },
                          child: Container(
                            width: 220,
                            height: 220,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(28)),
                            child: Image.asset(widget.word.imageAsset, fit: BoxFit.contain),
                          ),
                        ),
                        if (stage == _FinaleStage.locked || stage == _FinaleStage.cracking)
                          const Icon(Icons.lock_rounded, color: Colors.white70, size: 90),
                        if (stage == _FinaleStage.cracking)
                          CustomPaint(
                            size: const Size(220, 220),
                            painter: _FractureLinesPainter(progress: shakeController.value),
                          ),
                        if (particles.isNotEmpty && stage == _FinaleStage.shattering)
                          ...particles.map((p) => _ParticleDot(particle: p)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (stage != _FinaleStage.done)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  stage == _FinaleStage.locked
                      ? '...'
                      : (stage.index >= _FinaleStage.colorAwaken.index ? '${widget.word.word} unlocked! ✨' : 'Unlocking...'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<double> _grayscaleMatrix(double amount) {
  final inv = 1 - amount;
  return [
    0.2126 + 0.7874 * inv, 0.7152 - 0.7152 * inv, 0.0722 - 0.0722 * inv, 0, 0,
    0.2126 - 0.2126 * inv, 0.7152 + 0.2848 * inv, 0.0722 - 0.0722 * inv, 0, 0,
    0.2126 - 0.2126 * inv, 0.7152 - 0.7152 * inv, 0.0722 + 0.9278 * inv, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class _Particle {
  final double angle;
  final double speed;
  _Particle({required this.angle, required this.speed});
}

class _ParticleDot extends StatelessWidget {
  final _Particle particle;
  const _ParticleDot({required this.particle});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final dx = cos(particle.angle) * particle.speed * t;
        final dy = sin(particle.angle) * particle.speed * t;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: 1 - t,
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}

class _FractureLinesPainter extends CustomPainter {
  final double progress;
  _FractureLinesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final rand = Random(7);
    final lineCount = (progress * 6).clamp(0, 6).toInt();
    for (int i = 0; i < lineCount; i++) {
      final angle = (i / 6) * 2 * pi + rand.nextDouble() * 0.4;
      final length = 40 + rand.nextDouble() * 30;
      final end = Offset(center.dx + cos(angle) * length, center.dy + sin(angle) * length);
      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FractureLinesPainter oldDelegate) => oldDelegate.progress != progress;
}
