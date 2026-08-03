import 'dart:async'; // 💡 引入 Timer 需要的库
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../widgets/word_image.dart';

class SpeakingStep extends StatefulWidget {
  final String word;
  final String imageAsset;
  final String ageGroup;
  final VoidCallback onComplete;

  const SpeakingStep({
    super.key, 
    required this.word, 
    required this.imageAsset, 
    required this.ageGroup, 
    required this.onComplete
  });

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
  
  Timer? _fallbackTimer; // 💡 防卡死的 Timer

  bool get isStrict => widget.ageGroup == '6-7';

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool ready = await speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && isListening) {
            setState(() => isListening = false);
            _evaluate();
          }
        }
      },
      onError: (error) {
        if (mounted && isListening) {
          setState(() => isListening = false);
          _evaluate();
        }
      },
    );
    if (mounted) setState(() => speechReady = ready);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel(); // 💡 离开页面时清理 Timer
    speech.stop();
    tts.stop();
    super.dispose();
  }

  bool _isMatch(String spoken, String target) {
    final s = spoken.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final t = target.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    if (s.contains(t)) return true;

    if (t == 'dog' && (s.contains('log') || s.contains('long') || s.contains('dark') || s.contains('dot'))) return true;
    
    return false;
  }

  Future<void> _startListening() async {
    if (!speechReady) {
      await _initSpeech();
      if (!speechReady) return; 
    }
    if (isListening) return;

    // 💡 开启防卡死倒数计时：如果 11 秒后还在 Listening，强制关闭
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 11), () {
      if (mounted && isListening) {
        _stopListening();
      }
    });

    setState(() {
      isListening = true;
      recognizedText = '';
      maxSoundLevel = 0;
      listenStartedAt = DateTime.now();
    });
    
    await speech.listen(
      localeId: 'en-US',
      cancelOnError: false,  // 💡 遇到小杂音不要中断
      partialResults: true,  // 💡 即时回传部分结果
      listenMode: stt.ListenMode.dictation, // 💡 听写模式，对单字更敏锐
      onResult: (result) {
        if (mounted) {
          setState(() => recognizedText = result.recognizedWords);
          
          if (_isMatch(recognizedText, widget.word)) {
            _fallbackTimer?.cancel(); // 💡 匹配成功，取消 Timer
            speech.stop();
            if (isListening) {
              setState(() => isListening = false);
              _pass();
            }
          }
        }
      },
      onSoundLevelChange: (level) {
        if (mounted && level > maxSoundLevel) setState(() => maxSoundLevel = level);
      },
      listenFor: const Duration(seconds: 10), // 💡 增加整体聆听上限
      pauseFor: const Duration(seconds: 4),   // 💡 增加停顿宽容度
    );
  }

  Future<void> _stopListening() async {
    _fallbackTimer?.cancel(); // 💡 手动停止时，清理 Timer
    await speech.stop();
  }

  void _evaluate() {
    final heldMs = listenStartedAt == null ? 0 : DateTime.now().difference(listenStartedAt!).inMilliseconds;
    
    if (_isMatch(recognizedText, widget.word)) {
      _pass();
      return;
    }

    if (isStrict) {
      attemptCount++;
      return; 
    }

    attemptCount++;
    if (attemptCount >= 2 && heldMs > 1000 && maxSoundLevel > 8) {
      tts.speak(widget.word); 
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
        SizedBox(
          width: 300,
          height: 300,
          child: WordImage(imageAsset: widget.imageAsset),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Say "${widget.word}"', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9), 
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
          ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isListening ? 'Tap to stop' : 'Tap to speak',
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ],
    );
  }
}