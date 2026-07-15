import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/lesson_service.dart';
import '../../services/farm_progress_service.dart';

/// The Listening subject's map hub ("Savanna" theme). The system prompts
/// "Where is the CAMEL?" and the child must tap the correct animal among
/// the other words on the map (distractors). No text is shown for the
/// prompt — audio only, with a replay button, since kids this age can't
/// reliably read instructions.
class SavannaMapScreen extends StatefulWidget {
  final Lesson lesson;
  final String kidId;
  final VoidCallback onAllWordsExplored;

  const SavannaMapScreen({
    super.key,
    required this.lesson,
    required this.kidId,
    required this.onAllWordsExplored,
  });

  @override
  State<SavannaMapScreen> createState() => _SavannaMapScreenState();
}

class _SavannaMapScreenState extends State<SavannaMapScreen> {
  static const List<Offset> _scatterPositions = [
    Offset(0.20, 0.28),
    Offset(0.70, 0.32),
    Offset(0.42, 0.50),
    Offset(0.16, 0.70),
    Offset(0.75, 0.68),
    Offset(0.48, 0.20),
  ];

  final FlutterTts tts = FlutterTts();
  final Random rand = Random();
  Map<String, int> stars = {};
  String? targetWord;      // the word currently being asked for
  String? feedbackWord;    // word just tapped, for flash feedback
  bool feedbackCorrect = false;
  String? pressedWord;     // tap-down pop feedback
  bool bgFailed = false;   // true if savanna_bg.png couldn't load

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    _init();
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    final loaded = await FarmProgressService.loadStars(widget.kidId, 'listening');
    if (!mounted) return;
    setState(() => stars = loaded);
    _pickNextTarget();
  }

  void _pickNextTarget() {
    if (widget.lesson.words.length < 2) {
      // Not enough words for a hide-and-seek round — just finish immediately.
      widget.onAllWordsExplored();
      return;
    }
    final remaining = widget.lesson.words.where((w) => (stars[w.word] ?? 0) < 3).toList();
    if (remaining.isEmpty) {
      widget.onAllWordsExplored();
      return;
    }
    final next = remaining[rand.nextInt(remaining.length)];
    setState(() => targetWord = next.word);
    _speakPrompt();
  }

  Future<void> _speakPrompt() async {
    if (targetWord == null) return;
    await tts.speak('Where is the $targetWord?');
  }

  Future<void> _onTapWord(LessonWord word) async {
    if (targetWord == null) return;
    final correct = word.word == targetWord;
    setState(() {
      feedbackWord = word.word;
      feedbackCorrect = correct;
    });

    if (correct) {
      final newStars = ((stars[word.word] ?? 0) + 1).clamp(0, 3);
      setState(() => stars[word.word] = newStars);
      await FarmProgressService.setStars(widget.kidId, 'listening', word.word, newStars);
      await tts.speak('Yes! ${word.word}!');
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() => feedbackWord = null);
      _pickNextTarget();
    } else {
      // Wrong guess — no penalty, just a gentle nudge and let them try again.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => feedbackWord = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: bgFailed
                  ? const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFD98A), Color(0xFFE8B95E), Color(0xFFC79A46)],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    )
                  : BoxDecoration(
                      image: DecorationImage(
                        image: const AssetImage('assets/images/savanna_bg.png'),
                        fit: BoxFit.cover,
                        onError: (error, stackTrace) {
                          if (mounted) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => bgFailed = true);
                            });
                          }
                        },
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
                          child: Text('${widget.lesson.title} 🦁', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _speakPrompt,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: Color(0xFFFFAB40), shape: BoxShape.circle),
                          child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: List.generate(widget.lesson.words.length, (i) {
                  final word = widget.lesson.words[i];
                  final pos = (word.positionX != null && word.positionY != null)
                      ? Offset(word.positionX!, word.positionY!)
                      : _scatterPositions[i % _scatterPositions.length];
                  final wordStars = stars[word.word] ?? 0;
                  final isFeedback = feedbackWord == word.word;

                  return Positioned(
                    left: pos.dx * size.width - 58,
                    top: pos.dy * size.height - 58,
                    child: GestureDetector(
                      onTap: () => _onTapWord(word),
                      onTapDown: (_) => setState(() => pressedWord = word.word),
                      onTapUp: (_) => setState(() => pressedWord = null),
                      onTapCancel: () => setState(() => pressedWord = null),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: pressedWord == word.word ? 0.88 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOut,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isFeedback)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 128,
                                    height: 128,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (feedbackCorrect ? const Color(0xFF4DD9C0) : const Color(0xFFE85D5D)).withOpacity(0.35),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (feedbackCorrect ? const Color(0xFF4DD9C0) : const Color(0xFFE85D5D)).withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 116,
                                      height: 116,
                                      child: Image.asset(
                                        word.imageAsset,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.pets_rounded, size: 70, color: Colors.white),
                                      ),
                                    ),
                                    Container(
                                      width: 56,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (wordStars > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(3, (s) => Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: s < wordStars ? const Color(0xFFFFC107) : Colors.white54,
                                      )),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
