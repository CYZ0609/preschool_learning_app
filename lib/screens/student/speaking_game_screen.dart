import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/progress_service.dart';

class SpeakingGameScreen extends StatefulWidget {
  final String ageGroup;
  const SpeakingGameScreen({super.key, required this.ageGroup});

  @override
  State<SpeakingGameScreen> createState() => _SpeakingGameScreenState();
}

class _SpeakingGameScreenState extends State<SpeakingGameScreen> {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  int currentQuestion = 0;
  int score = 0;
  bool isListening = false;
  String spokenText = '';
  bool answered = false;
  bool? isCorrect;

  // 1. 题库替换：加入你电脑里的真实图片素材，分年龄段，每段 10 题
  List<Map<String, dynamic>> get questions {
    switch (widget.ageGroup) {
      case '4-5':
        return [
          {'word': 'Cat', 'image': 'assets/images/cat.png'},
          {'word': 'Dog', 'image': 'assets/images/dog.png'},
          {'word': 'Sun', 'image': 'assets/images/sun.png'},
          {'word': 'Hat', 'image': 'assets/images/hat.png'},
          {'word': 'Fish', 'image': 'assets/images/fish.png'},
          {'word': 'Pig', 'image': 'assets/images/pig.png'},
          {'word': 'Cow', 'image': 'assets/images/cow.png'},
          {'word': 'Bird', 'image': 'assets/images/bird.png'},
          {'word': 'Frog', 'image': 'assets/images/frog.png'},
          {'word': 'Lion', 'image': 'assets/images/lion.png'},
        ];
      case '5-6':
        return [
          {'word': 'Apple', 'image': 'assets/images/apple.png'},
          {'word': 'Rabbit', 'image': 'assets/images/rabbit.png'},
          {'word': 'Yellow', 'image': 'assets/images/yellow.png'},
          {'word': 'Table', 'image': 'assets/images/table.png'},
          {'word': 'Water', 'image': 'assets/images/water.png'},
          {'word': 'Banana', 'image': 'assets/images/banana.png'},
          {'word': 'Monkey', 'image': 'assets/images/monkey.png'},
          {'word': 'Purple', 'image': 'assets/images/purple.png'},
          {'word': 'Pencil', 'image': 'assets/images/pencil.png'},
          {'word': 'Doctor', 'image': 'assets/images/doctor.png'},
        ];
      case '6-7':
      default:
        return [
          {'word': 'Tiger', 'image': 'assets/images/tiger.png'},
          {'word': 'Giraffe', 'image': 'assets/images/giraffe.png'},
          {'word': 'Zebra', 'image': 'assets/images/zebra.png'},
          {'word': 'Teacher', 'image': 'assets/images/teacher.png'},
          {'word': 'Pilot', 'image': 'assets/images/pilot.png'},
          {'word': 'Nurse', 'image': 'assets/images/nurse.png'},
          {'word': 'Window', 'image': 'assets/images/window.png'},
          {'word': 'Bottle', 'image': 'assets/images/bottle.png'},
          {'word': 'Orange', 'image': 'assets/images/orange.png'},
          {'word': 'Rubber', 'image': 'assets/images/rubber.png'},
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    Future.delayed(const Duration(milliseconds: 500), () {
      _speakWord();
    });
  }

  Future<void> _speakWord() async {
    // 2. 将 words 替换为 questions[...]['word']
    await tts.speak(questions[currentQuestion]['word']);
  }

  void _stopAndCheck() {
    speech.stop();
    setState(() {
      isListening = false;
      answered = true;
      // 2. 对比时提取 'word' 进行比对
      isCorrect = spokenText.toLowerCase().trim() ==
          (questions[currentQuestion]['word'] as String).toLowerCase();
      if (isCorrect == true) score++;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (currentQuestion < questions.length - 1) {
        setState(() {
          currentQuestion++;
          answered = false;
          isCorrect = null;
          spokenText = '';
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
      totalQuestions: questions.length, // 替换为 questions.length
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
              '$score / ${questions.length}', // 替换为 questions.length
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
                    'Question ${currentQuestion + 1} of ${questions.length}', // 替换为 questions.length
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
                  const SizedBox(height: 24), // 调整了间距为放入图片留出空间
                  
                  // 3. ✨ 唯一新增的 UI：展示当前单词对应的离线图片 ✨
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
                        child: Image.asset(
                          questions[currentQuestion]['image'],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 原版：Word + speaker
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
                              questions[currentQuestion]['word'], // 替换为 questions[...]['word']
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
                  // Mic button (完全保留你的逻辑)
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        bool available = await speech.initialize();
                        if (!available) {
                          setState(() => spokenText = 'NOT AVAILABLE');
                          return;
                        }

                        setState(() {
                          isListening = true;
                          spokenText = 'LISTENING...';
                        });

                        await speech.listen(
                          onResult: (result) {
                            setState(() {
                              spokenText = 'HEARD: ${result.recognizedWords}';
                            });
                          },
                        );

                        Future.delayed(const Duration(seconds: 5), () {
                          _stopAndCheck(); // 核心检查逻辑
                        });
                      },
                      child: Container(
                        width: 110,
                        height: 110,
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
                  Center(
                    child: Text(
                      'DEBUG: "$spokenText"',
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
                            'You said: "$spokenText"',
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