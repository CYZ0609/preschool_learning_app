import 'package:flutter/material.dart';
import '../../services/progress_service.dart';

class WritingGameScreen extends StatefulWidget {
  final String ageGroup;
  const WritingGameScreen({super.key, required this.ageGroup});

  @override
  State<WritingGameScreen> createState() => _WritingGameScreenState();
}

class _WritingGameScreenState extends State<WritingGameScreen> {
  int currentQuestion = 0;
  int score = 0;
  String? selectedAnswer;
  bool answered = false;

  late List<Map<String, dynamic>> questions;

  // 1. 扩充题库：增加 image 字段，实现看图拼写！
  List<Map<String, dynamic>> _generateQuestions(String age) {
    switch (age) {
      case '4-5':
        return [
          {'display': 'C _ T', 'image': 'assets/images/cat.png', 'answer': 'A', 'options': ['A', 'E', 'I', 'O']},
          {'display': 'D _ G', 'image': 'assets/images/dog.png', 'answer': 'O', 'options': ['A', 'O', 'U', 'I']},
          {'display': 'S _ N', 'image': 'assets/images/sun.png', 'answer': 'U', 'options': ['A', 'E', 'U', 'O']},
          {'display': 'H _ T', 'image': 'assets/images/hat.png', 'answer': 'A', 'options': ['E', 'A', 'I', 'O']},
          {'display': 'P _ G', 'image': 'assets/images/pig.png', 'answer': 'I', 'options': ['A', 'E', 'I', 'O']},
          {'display': 'C _ W', 'image': 'assets/images/cow.png', 'answer': 'O', 'options': ['A', 'O', 'U', 'I']},
          {'display': 'B _ D', 'image': 'assets/images/bird.png', 'answer': 'I', 'options': ['A', 'E', 'I', 'O']},
          {'display': 'F _ G', 'image': 'assets/images/frog.png', 'answer': 'O', 'options': ['A', 'O', 'U', 'I']},
          {'display': 'L _ N', 'image': 'assets/images/lion.png', 'answer': 'I', 'options': ['A', 'E', 'I', 'O']},
          {'display': 'C _ P', 'image': 'assets/images/cup.png', 'answer': 'U', 'options': ['A', 'E', 'U', 'O']},
        ];
      case '5-6':
        return [
          {'display': 'A P P _ E', 'image': 'assets/images/apple.png', 'answer': 'L', 'options': ['L', 'B', 'N', 'T']},
          {'display': 'R A B _ I T', 'image': 'assets/images/rabbit.png', 'answer': 'B', 'options': ['B', 'P', 'D', 'M']},
          {'display': 'T A _ L E', 'image': 'assets/images/table.png', 'answer': 'B', 'options': ['B', 'P', 'L', 'D']},
          {'display': 'W A _ E R', 'image': 'assets/images/water.png', 'answer': 'T', 'options': ['T', 'D', 'N', 'P']},
          {'display': 'B A N A _ A', 'image': 'assets/images/banana.png', 'answer': 'N', 'options': ['N', 'M', 'L', 'P']},
          {'display': 'M O N _ E Y', 'image': 'assets/images/monkey.png', 'answer': 'K', 'options': ['K', 'C', 'T', 'N']},
          {'display': 'P E N _ I L', 'image': 'assets/images/pencil.png', 'answer': 'C', 'options': ['C', 'K', 'S', 'T']},
          {'display': 'D O C _ O R', 'image': 'assets/images/doctor.png', 'answer': 'T', 'options': ['T', 'D', 'N', 'P']},
          {'display': 'F L O _ E R', 'image': 'assets/images/flower.png', 'answer': 'W', 'options': ['W', 'R', 'T', 'L']},
          {'display': 'P _ R P L E', 'image': 'assets/images/purple.png', 'answer': 'U', 'options': ['U', 'A', 'E', 'O']},
        ];
      case '6-7':
      default:
        return [
          {'display': 'E L E _ H A N T', 'image': 'assets/images/elephant.png', 'answer': 'P', 'options': ['P', 'B', 'F', 'V']},
          {'display': 'B U T T E R _ L Y', 'image': 'assets/images/butterfly.png', 'answer': 'F', 'options': ['F', 'P', 'B', 'V']},
          {'display': 'T R _ A N G L E', 'image': 'assets/images/triangle.png', 'answer': 'I', 'options': ['I', 'E', 'A', 'O']},
          {'display': 'L I B R A _ Y', 'image': 'assets/images/library.png', 'answer': 'R', 'options': ['R', 'L', 'N', 'M']},
          {'display': 'T I G _ R', 'image': 'assets/images/tiger.png', 'answer': 'E', 'options': ['E', 'A', 'I', 'O']},
          {'display': 'Z E B _ A', 'image': 'assets/images/zebra.png', 'answer': 'R', 'options': ['R', 'L', 'N', 'M']},
          {'display': 'P I _ O T', 'image': 'assets/images/pilot.png', 'answer': 'L', 'options': ['L', 'R', 'N', 'M']},
          {'display': 'N U _ S E', 'image': 'assets/images/nurse.png', 'answer': 'R', 'options': ['R', 'L', 'N', 'M']},
          {'display': 'O R A _ G E', 'image': 'assets/images/orange.png', 'answer': 'N', 'options': ['N', 'M', 'L', 'P']},
          {'display': 'R U B _ E R', 'image': 'assets/images/rubber.png', 'answer': 'B', 'options': ['B', 'P', 'D', 'M']},
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    questions = _generateQuestions(widget.ageGroup);
    for (var q in questions) {
      q['options'] = List<String>.from(q['options'])..shuffle();
    }
  }

  void selectAnswer(String answer) {
    if (answered) return;
    setState(() {
      selectedAnswer = answer;
      answered = true;
      if (answer == questions[currentQuestion]['answer']) {
        score++;
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (currentQuestion < questions.length - 1) {
        setState(() {
          currentQuestion++;
          selectedAnswer = null;
          answered = false;
          questions[currentQuestion]['options'] =
              List<String>.from(questions[currentQuestion]['options'])..shuffle();
        });
      } else {
        _showResult();
      }
    });
  }

  void _showResult() {
    ProgressService.saveProgress(
      subject: 'writing',
      module: 'writing',
      ageGroup: widget.ageGroup,
      score: score,
      totalQuestions: questions.length,
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
                color: Color(0xFFFFAB40),
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
                  ? 'Perfect spelling!'
                  : score >= 6
                      ? 'Great writing!'
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
                backgroundColor: const Color(0xFFFFAB40),
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

  Color _getOptionColor(String option) {
    if (!answered) return const Color(0xFFFFAB40);
    if (option == questions[currentQuestion]['answer']) {
      return const Color(0xFF4DD9C0);
    }
    if (option == selectedAnswer) return Colors.redAccent;
    return const Color(0xFFFFAB40);
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[currentQuestion];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFFFFB7C5), shape: BoxShape.circle))),
          Positioned(top: 20, right: 20, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFFFF8FAB), shape: BoxShape.circle))),
          Positioned(bottom: -40, left: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFF80DEEA), shape: BoxShape.circle))),
          Positioned(bottom: 20, left: 20, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFF4DD9C0), shape: BoxShape.circle))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Align(alignment: Alignment.topLeft, child: Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(questions.length, (i) {
                      return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), height: 8, decoration: BoxDecoration(color: i <= currentQuestion ? const Color(0xFFFFAB40) : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4))));
                    }),
                  ),
                  const SizedBox(height: 32),
                  // 🌟 加入图片框 🌟
                  Container(
                    width: 160,
                    height: 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(q['image'], fit: BoxFit.contain)),
                  ),
                  const SizedBox(height: 32),
                  Text(q['display'], style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF333333), letterSpacing: 8)),
                  const SizedBox(height: 40),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                    children: (q['options'] as List<String>).map((option) {
                      return GestureDetector(
                        onTap: () => selectAnswer(option),
                        child: Container(
                          decoration: BoxDecoration(color: _getOptionColor(option), borderRadius: BorderRadius.circular(16)),
                          child: Center(child: Text(option, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                        ),
                      );
                    }).toList(),
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