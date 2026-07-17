import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Step 4 (5-6, 6-7 only): the child taps the mic and speaks. Their words
/// are echoed live into a text bubble as they're recognized.
/// - 5-6 (High Tolerance): if the recognized text doesn't match after 2
///   attempts, falls back to a volume/duration check — if they clearly
///   said *something* with enough voice, it still passes.
/// - 6-7 (Strict): exact match required (case-insensitive), no fallback.
class SpeakingStep extends StatefulWidget {
  final String word;
  final String ageGroup;
  final VoidCallback onComplete;

  const SpeakingStep({super.key, required this.word, required this.ageGroup, required this.onComplete});

  @override
  State<SpeakingStep> createState() => _SpeakingStepState();
}

class _SpeakingStepState extends State<SpeakingStep> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  bool isListening = false;
  bool speechReady = false;
  String recognizedText = '';
  double maxSoundLevel = 0;
  DateTime? listenStartedAt;
  int attemptCount = 0;

  bool get isStrict => widget.ageGroup == '6-7';

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    speech.initialize().then((ready) {
      if (mounted) setState(() => speechReady = ready);
    });
  }

  @override
  void dispose() {
    speech.stop();
    tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!speechReady || isListening) return;
    setState(() {
      isListening = true;
      recognizedText = '';
      maxSoundLevel = 0;
      listenStartedAt = DateTime.now();
    });
    await speech.listen(
      onResult: (result) {
        if (mounted) setState(() => recognizedText = result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        if (mounted && level > maxSoundLevel) setState(() => maxSoundLevel = level);
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
    );
  }

  Future<void> _stopListening() async {
    await speech.stop();
    if (!mounted) return;
    setState(() => isListening = false);
    _evaluate();
  }

  void _evaluate() {
    final heldMs = listenStartedAt == null ? 0 : DateTime.now().difference(listenStartedAt!).inMilliseconds;
    final matches = recognizedText.trim().toLowerCase() == widget.word.toLowerCase();

    if (matches) {
      _pass();
      return;
    }

    if (isStrict) {
      attemptCount++;
      return; // no fallback — must try again
    }

    attemptCount++;
    if (attemptCount >= 2 && heldMs > 1000 && maxSoundLevel > 8) {
      tts.speak(widget.word); // corrective playback of the flawless pronunciation
      _pass();
    }
  }

  void _pass() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Say "${widget.word}"', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
          child: Text(
            recognizedText.isEmpty ? (isListening ? 'Listening...' : '...') : recognizedText,
            style: const TextStyle(fontSize: 18, color: Color(0xFF333333)),
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: isListening ? _stopListening : _startListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isListening ? 110 : 96,
            height: isListening ? 110 : 96,
            decoration: BoxDecoration(
              color: isListening ? const Color(0xFFE85D5D) : const Color(0xFFFFAB40),
              shape: BoxShape.circle,
              boxShadow: isListening
                  ? [BoxShadow(color: const Color(0xFFE85D5D).withOpacity(0.4), blurRadius: 20, spreadRadius: 4)]
                  : [],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isListening ? 'Tap to stop' : 'Tap to speak',
          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
      ],
    );
  }
}
