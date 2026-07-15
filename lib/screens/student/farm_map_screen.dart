import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/lesson_service.dart';
import '../../services/farm_progress_service.dart';

/// The Reading subject's map hub ("Farm" theme). Renders every word in the
/// lesson as a tappable asset positioned on the map (using each word's
/// positionX/positionY if the teacher set them, otherwise an automatic
/// grid layout as a fallback so older lessons still work with zero
/// migration). Tapping an asset triggers "Free Exploration": a scale-bounce
/// animation, the word spoken aloud, and an age-appropriate text reveal.
class FarmMapScreen extends StatefulWidget {
  final Lesson lesson;
  final String kidId;
  final VoidCallback onAllWordsExplored;

  const FarmMapScreen({
    super.key,
    required this.lesson,
    required this.kidId,
    required this.onAllWordsExplored,
  });

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen> {
  final FlutterTts tts = FlutterTts();
  Map<String, int> stars = {}; // word -> star count (0-3)
  String? activeWord; // which word currently shows its bounce/text popup
  String? pressedWord; // which word is currently being tap-pressed (pop feedback)
  bool bgFailed = false; // true if farm_bg.png couldn't load — fall back to gradient

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    _loadStars();
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _loadStars() async {
    final loaded = await FarmProgressService.loadStars(widget.kidId, 'reading');
    if (mounted) setState(() => stars = loaded);
  }

  /// Hand-placed "organic" scatter positions (fractional 0.0-1.0), used
  /// when a word doesn't have a teacher-set positionX/positionY. Cycles if
  /// the lesson has more words than presets.
  static const List<Offset> _scatterPositions = [
    Offset(0.18, 0.30), // upper-left
    Offset(0.72, 0.22), // upper-right
    Offset(0.45, 0.42), // center
    Offset(0.15, 0.68), // lower-left
    Offset(0.78, 0.62), // lower-right
    Offset(0.50, 0.78), // bottom-center
  ];

  Offset _positionFor(LessonWord word, int index) {
    if (word.positionX != null && word.positionY != null) {
      return Offset(word.positionX!, word.positionY!);
    }
    return _scatterPositions[index % _scatterPositions.length];
  }

  Future<void> _onTapWord(LessonWord word) async {
    setState(() => activeWord = word.word);
    await tts.speak(word.word);

    final newStars = ((stars[word.word] ?? 0) + 1).clamp(0, 3);
    setState(() => stars[word.word] = newStars);
    await FarmProgressService.setStars(widget.kidId, 'reading', word.word, newStars);

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => activeWord = null);

    if (stars.values.where((s) => s > 0).length >= widget.lesson.words.length &&
        stars.values.every((s) => s > 0)) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) widget.onAllWordsExplored();
    }
  }

  /// Age-appropriate text reveal style for the popup above a tapped word.
  Widget _textRevealFor(LessonWord word) {
    final age = widget.lesson.ageGroup;
    if (age == '6-7') {
      final startsWithVowel = 'AEIOU'.contains(word.word.isNotEmpty ? word.word[0] : '');
      return Text('I see a${startsWithVowel ? 'n' : ''} ${word.word}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white));
    }
    if (age == '5-6') {
      return Text(
        word.word.split('').join('  '),
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
      );
    }
    return Text(word.word,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white));
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
                        colors: [Color(0xFF87CEEB), Color(0xFFA8D8A0), Color(0xFF7CB86D)],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    )
                  : BoxDecoration(
                      image: DecorationImage(
                        image: const AssetImage('assets/images/farm_bg.png'),
                        fit: BoxFit.cover,
                        onError: (error, stackTrace) {
                          // farm_bg.png missing/broken — fall back to gradient
                          // instead of crashing or showing a blank screen.
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
              child: Row(
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
                      child: Text(
                        '${widget.lesson.title} 🚜',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                      ),
                    ),
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
                  final pos = _positionFor(word, i);
                  final wordStars = stars[word.word] ?? 0;
                  final isActive = activeWord == word.word;

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
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                              child: _textRevealFor(word),
                            ),
                          AnimatedScale(
                            // Quick pop on press, bigger bounce when actively speaking.
                            scale: isActive ? 1.25 : (pressedWord == word.word ? 0.88 : 1.0),
                            duration: Duration(milliseconds: isActive ? 300 : 100),
                            curve: isActive ? Curves.elasticOut : Curves.easeOut,
                            child: Column(
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
                                // Soft ground shadow so the character reads as
                                // standing on the map, not floating in a box.
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
