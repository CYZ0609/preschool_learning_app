import 'dart:async'; // ✨ 新增：用于防卡死的 Timer
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/progress_service.dart';
import '../../../services/sandbox_item_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/word_image.dart';

class SpeakingGameScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  const SpeakingGameScreen({super.key, required this.ageGroup, required this.kidId});

  @override
  State<SpeakingGameScreen> createState() => _SpeakingGameScreenState();
}

class _SpeakingGameScreenState extends State<SpeakingGameScreen> {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  int currentQuestion = 0;
  int score = 0;
  bool answered = false;
  bool? isCorrect;
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;

  // ✨ 引入了第一个方法的高级状态控制
  bool isListening = false;
  bool speechReady = false;
  String recognizedText = '';
  double maxSoundLevel = 0;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    _initSpeech(); // ✨ 初始化语音引擎
    _initGameData();
  }

  // ✨ 新增：更严谨的初始化逻辑
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
    _fallbackTimer?.cancel(); // ✨ 清理 Timer
    speech.stop();
    tts.stop();
    super.dispose();
  }

  Future<void> _initGameData() async {
   final allCustomItems = await SandboxItemService.loadGlobalItems();

// 过滤出：只属于当前小朋友年龄段的词，或者老师设定为全年龄通用的词
final customItems = allCustomItems.where((item) {
  // 假设你的 Item 模型里加了一个 targetAge 属性
  return item.targetAge == widget.ageGroup || item.targetAge == 'all'; 
}).toList();
    final builtInWords = defaultMapWordsFor(widget.ageGroup);
    final activeWords = mergeCustomVocabulary(builtIn: builtInWords, custom: customItems);
    
    activeWords.shuffle();
    final targetWords = activeWords.take(10).toList();

    List<Map<String, dynamic>> generatedQuestions = [];
    for (var target in targetWords) {
      generatedQuestions.add({
        'word': target.word,
        'image': target.imageAsset,
      });
    }

    if (!mounted) return;
    
    setState(() {
      questions = generatedQuestions;
      isLoading = false;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _speakWord();
    });
  }

  Future<void> _speakWord() async {
    if (questions.isNotEmpty) {
      await tts.speak(questions[currentQuestion]['word']);
    }
  }

  // ✨ 新增：第一个方法里的模糊匹配逻辑
  bool _isMatch(String spoken, String target) {
final s = spoken.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final t = target.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (s.contains(t)) return true;
    if (t == 'dog' && (s.contains('log') || s.contains('long') || s.contains('dark') || s.contains('dot'))) return true;
    
    return false;
  }

  // ✨ 新增：替换掉原来死板的 5 秒录音，改用高级监听模式
  Future<void> _startListening() async {
    if (!speechReady) {
      await _initSpeech();
      if (!speechReady) return; 
    }
    if (isListening || answered) return;

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
    });
    
    final targetWord = questions[currentQuestion]['word'] as String;

    await speech.listen(
      localeId: 'en-US',
      cancelOnError: false,
      partialResults: true, 
      listenMode: stt.ListenMode.dictation, // 更适合单字识别
      onResult: (result) {
        if (mounted) {
          setState(() => recognizedText = result.recognizedWords);
          
          // 如果识别结果匹配到了目标单词，立刻停止并判对！
          if (_isMatch(recognizedText, targetWord)) {
            _fallbackTimer?.cancel();
            speech.stop();
            if (isListening) {
              setState(() => isListening = false);
              _handleAnswer(true); // 立刻触发正确逻辑
            }
          }
        }
      },
      onSoundLevelChange: (level) {
        if (mounted && level > maxSoundLevel) setState(() => maxSoundLevel = level);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _stopListening() async {
    _fallbackTimer?.cancel();
    await speech.stop();
  }

  // ✨ 新增：如果录音自动结束（没有提前匹配成功），则统一在此处验证
  void _evaluate() {
    if (answered) return; 
    final targetWord = questions[currentQuestion]['word'] as String;
    _handleAnswer(_isMatch(recognizedText, targetWord));
  }

  // ✨ 新增：处理验证结果并进入下一题的逻辑
  void _handleAnswer(bool isCorrectAnswer) {
    setState(() {
      isListening = false;
      answered = true;
      isCorrect = isCorrectAnswer;
      if (isCorrect == true) score++;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (currentQuestion < questions.length - 1) {
        setState(() {
          currentQuestion++;
          answered = false;
          isCorrect = null;
          recognizedText = '';
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          _speakWord();
        });
      } else {
        _showResult();
      }
    });
  }

  void _showResult() {
    ProgressService.saveProgress(
      subject: 'english',
      module: 'speaking',
      ageGroup: widget.ageGroup,
      score: score,
      totalQuestions: questions.length, 
      kidId: widget.kidId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quiz Complete!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score / ${questions.length}', 
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF8FAB),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final starsEarned = score == questions.length
                    ? 3
                    : score >= (questions.length * 0.6).ceil()
                        ? 2
                        : 1;
                return Icon(
                  Icons.star_rounded,
                  size: 40,
                  color: i < starsEarned
                      ? const Color(0xFFFFC107)
                      : const Color(0xFFE0E0E0),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              score == questions.length
                  ? 'Perfect pronunciation!'
                  : score >= (questions.length * 0.6).ceil()
                      ? 'Great speaking!'
                      : 'Keep practicing!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8FAB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Menu',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8FAB)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB7C5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFFF8FAB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFF80DEEA),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF4DD9C0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(questions.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentQuestion
                                ? const Color(0xFFFF8FAB)
                                : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Question ${currentQuestion + 1} of ${questions.length}', 
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Listen and Repeat',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: WordImage(
                          imageAsset: questions[currentQuestion]['image'],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Center(
                    child: GestureDetector(
                      onTap: _speakWord,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              questions[currentQuestion]['word'], 
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF8FAB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.volume_up_rounded,
                                color: Color(0xFFFF8FAB)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // ✨ 替换了原本的死板事件，绑定到了 _startListening 和 _stopListening
                  Center(
                    child: GestureDetector(
                      onTap: isListening ? _stopListening : _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isListening ? 130 : 110,
                        height: isListening ? 130 : 110,
                        decoration: BoxDecoration(
                          color: isListening
                              ? Colors.redAccent
                              : const Color(0xFFFF8FAB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isListening
                                      ? Colors.redAccent
                                      : const Color(0xFFFF8FAB))
                                  .withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          isListening ? Icons.mic : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // ✨ 统一使用 recognizedText 来显示识别状态
                  Center(
                    child: Text(
                      'DEBUG: "$recognizedText"',
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isListening)
                    const Center(
                      child: Text('Listening...',
                          style: TextStyle(color: Color(0xFF888888))),
                    ),
                  if (answered)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'You said: "$recognizedText"',
                            style: const TextStyle(color: Color(0xFF888888)),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            isCorrect == true
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: isCorrect == true
                                ? const Color(0xFF4DD9C0)
                                : Colors.redAccent,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}