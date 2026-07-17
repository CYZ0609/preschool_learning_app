import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Step 2: the word appears as empty letter slots. The child taps letter
/// tiles (scrambled, with distractors) to fill them in order.
/// - Guided (4-5, 5-6): the correct next letter bounces/flashes in full
///   color; all others are grayed out and disabled — a simple guided
///   "Whack-a-Mole" so the child can't get it wrong.
/// - Unguided (6-7): no highlighting, no disabling — the child must
///   construct the word entirely from memory.
class ReadingStep extends StatefulWidget {
  final String word;
  final String ageGroup;
  final VoidCallback onComplete;

  const ReadingStep({super.key, required this.word, required this.ageGroup, required this.onComplete});

  @override
  State<ReadingStep> createState() => _ReadingStepState();
}

class _ReadingStepState extends State<ReadingStep> {
  final FlutterTts tts = FlutterTts();
  late List<String?> slots;
  late List<String> tileLetters;
  final Set<int> usedTileIndices = {};

  bool get isGuided => widget.ageGroup != '6-7';

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    slots = List.filled(widget.word.length, null);

    final distractors = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        .split('')
        .where((c) => !widget.word.contains(c))
        .toList()
      ..shuffle();
    tileLetters = [...widget.word.split(''), ...distractors.take(3)]..shuffle(Random());
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  int get _nextSlotIndex => slots.indexWhere((s) => s == null);

  void _tapTile(int tileIndex) {
    if (usedTileIndices.contains(tileIndex)) return;
    final nextIndex = _nextSlotIndex;
    if (nextIndex == -1) return;
    final requiredLetter = widget.word[nextIndex];
    final tappedLetter = tileLetters[tileIndex];

    if (tappedLetter != requiredLetter) {
      // Only reachable in unguided mode — no penalty, just ignore it.
      return;
    }

    setState(() {
      slots[nextIndex] = tappedLetter;
      usedTileIndices.add(tileIndex);
    });

    if (slots.every((s) => s != null)) {
      tts.speak(widget.word);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = _nextSlotIndex;
    final requiredLetter = nextIndex == -1 ? null : widget.word[nextIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(slots.length, (i) {
            return Container(
              width: 52,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: slots[i] != null ? const Color(0xFF4DD9C0) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
              ),
              child: Text(
                slots[i] ?? '',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: slots[i] != null ? Colors.white : Colors.transparent),
              ),
            );
          }),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(tileLetters.length, (i) {
            final letter = tileLetters[i];
            final isUsed = usedTileIndices.contains(i);
            final isTheOne = isGuided && letter == requiredLetter && !isUsed;
            final isEnabled = isUsed ? false : (isGuided ? isTheOne : true);

            return GestureDetector(
              onTap: isEnabled ? () => _tapTile(i) : null,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: isTheOne ? 1 : 0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, bounce, child) => Transform.translate(
                  offset: Offset(0, -8 * bounce),
                  child: child,
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isUsed
                        ? Colors.transparent
                        : (isTheOne ? const Color(0xFFFFAB40) : (isGuided ? const Color(0xFFEEEEEE) : Colors.white)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isTheOne ? const Color(0xFFFFAB40) : const Color(0xFFCCCCCC), width: 2),
                  ),
                  child: Text(
                    isUsed ? '' : letter,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isUsed ? Colors.transparent : (isGuided && !isTheOne ? const Color(0xFFAAAAAA) : const Color(0xFF333333)),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
