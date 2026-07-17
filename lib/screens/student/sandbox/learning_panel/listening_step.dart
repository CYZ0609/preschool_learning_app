import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Step 1 (all ages): a massive jelly-like button. Tapping it speaks the
/// word twice with a pause between. Only after the second playback
/// finishes does the Next arrow appear — no way to skip ahead by luck.
class ListeningStep extends StatefulWidget {
  final String word;
  final VoidCallback onComplete;

  const ListeningStep({super.key, required this.word, required this.onComplete});

  @override
  State<ListeningStep> createState() => _ListeningStepState();
}

class _ListeningStepState extends State<ListeningStep> {
  final FlutterTts tts = FlutterTts();
  bool isPlaying = false;
  bool canAdvance = false;
  bool pressed = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _playTwice() async {
    if (isPlaying) return;
    setState(() => isPlaying = true);
    await tts.speak(widget.word);
    await Future.delayed(const Duration(milliseconds: 1500));
    await tts.speak(widget.word);
    if (!mounted) return;
    setState(() {
      isPlaying = false;
      canAdvance = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: _playTwice,
          child: AnimatedScale(
            scale: pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFFFAB40),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFAB40).withOpacity(0.5), blurRadius: 30, spreadRadius: 6),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 80,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isPlaying ? 'Listening...' : 'Tap to hear!',
          style: const TextStyle(fontSize: 16, color: Color(0xFF888888), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        if (canAdvance)
          GestureDetector(
            onTap: widget.onComplete,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Color(0xFF4DD9C0), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 36),
            ),
          ),
      ],
    );
  }
}
