import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/lesson_service.dart';

/// Age 6-7: builds a simple sentence around the lesson word (e.g.
/// "I see a COW") and scrambles it into draggable blocks. The child drags
/// each block into the correct slot, in order, to complete the sentence.
class SentenceBuilderCard extends StatefulWidget {
  final LessonWord word;
  final VoidCallback onComplete;

  const SentenceBuilderCard({super.key, required this.word, required this.onComplete});

  @override
  State<SentenceBuilderCard> createState() => _SentenceBuilderCardState();
}

class _SentenceBuilderCardState extends State<SentenceBuilderCard> {
  final FlutterTts tts = FlutterTts();
  late List<String> sentenceTokens; // correct order
  late List<String?> slots;         // what's currently placed in each slot
  late List<String> bank;           // remaining draggable tokens
  bool revealed = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    final word = widget.word.word;
    final startsWithVowel = 'AEIOU'.contains(word.isNotEmpty ? word[0] : '');
    sentenceTokens = ['I', 'see', startsWithVowel ? 'an' : 'a', word];
    slots = List.filled(sentenceTokens.length, null);
    bank = List.from(sentenceTokens)..shuffle();
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  void _placeInSlot(int slotIndex, String token) {
    if (revealed || slots[slotIndex] != null) return;
    if (token != sentenceTokens[slotIndex]) {
      // Wrong slot — bounce back, no penalty, just don't place it.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Try a different spot!'),
          duration: Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE85D5D),
        ),
      );
      return;
    }
    setState(() {
      slots[slotIndex] = token;
      bank.remove(token);
    });
    if (slots.every((s) => s != null)) {
      _reveal();
    }
  }

  void _reveal() {
    setState(() => revealed = true);
    tts.speak(sentenceTokens.join(' '));
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFE0FDF4), borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(widget.word.imageAsset, width: 110, height: 110, fit: BoxFit.contain),
          const SizedBox(height: 20),
          const Text('Build the sentence!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333), fontSize: 15)),
          const SizedBox(height: 16),
          // Slots
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(sentenceTokens.length, (i) {
              final filled = slots[i];
              return DragTarget<String>(
                onWillAcceptWithDetails: (_) => !revealed && slots[i] == null,
                onAcceptWithDetails: (details) => _placeInSlot(i, details.data),
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    width: 78,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled != null ? const Color(0xFF4DD9C0) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: candidateData.isNotEmpty ? const Color(0xFF4DD9C0) : const Color(0xFFCCCCCC),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      filled ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: filled != null ? Colors.white : const Color(0xFF333333),
                        fontSize: 15,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 28),
          // Draggable word bank
          if (!revealed)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: bank.map((token) {
                return Draggable<String>(
                  data: token,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _WordChip(text: token, color: const Color(0xFFFFAB40)),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: _WordChip(text: token, color: const Color(0xFFFFAB40))),
                  child: _WordChip(text: token, color: const Color(0xFFFFAB40)),
                );
              }).toList(),
            )
          else
            const Text('Great sentence! 🎉',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4DD9C0))),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String text;
  final Color color;
  const _WordChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}
