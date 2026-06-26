import 'package:flutter/material.dart';
import '../../services/progress_service.dart';

class ArithmeticGameScreen extends StatefulWidget {
  final String ageGroup;
  const ArithmeticGameScreen({super.key, required this.ageGroup});

  @override
  State<ArithmeticGameScreen> createState() => _ArithmeticGameScreenState();
}

class _ArithmeticGameScreenState extends State<ArithmeticGameScreen> {
  int currentQuestion = 0;
  int score = 0;
  String? selectedAnswer;
  bool answered = false;

  late List<Map<String, dynamic>> questions;

  // 1. 根据年龄段动态生成 10 道不同难度的数学题
  List<Map<String, dynamic>> _generateQuestions(String age) {
    switch (age) {
      case '4-5': // 10 以内极其简单的加减法
        return [
          {'display': '1 + 1 = ?', 'options': ['1', '2', '3', '4'], 'answer': '2'},
          {'display': '2 + 1 = ?', 'options': ['2', '3', '4', '5'], 'answer': '3'},
          {'display': '3 - 1 = ?', 'options': ['1', '2', '3', '4'], 'answer': '2'},
          {'display': '2 + 2 = ?', 'options': ['2', '3', '4', '5'], 'answer': '4'},
          {'display': '4 - 2 = ?', 'options': ['1', '2', '3', '4'], 'answer': '2'},
          {'display': '3 + 2 = ?', 'options': ['3', '4', '5', '6'], 'answer': '5'},
          {'display': '5 - 1 = ?', 'options': ['2', '3', '4', '5'], 'answer': '4'},
          {'display': '4 + 1 = ?', 'options': ['3', '4', '5', '6'], 'answer': '5'},
          {'display': '5 - 3 = ?', 'options': ['1', '2', '3', '4'], 'answer': '2'},
          {'display': '0 + 3 = ?', 'options': ['1', '2', '3', '4'], 'answer': '3'},
        ];
      case '5-6': // 15 以内进阶加减法
        return [
          {'display': '5 + 4 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
          {'display': '10 - 2 = ?', 'options': ['6', '7', '8', '9'], 'answer': '8'},
          {'display': '6 + 5 = ?', 'options': ['9', '10', '11', '12'], 'answer': '11'},
          {'display': '8 - 4 = ?', 'options': ['3', '4', '5', '6'], 'answer': '4'},
          {'display': '7 + 3 = ?', 'options': ['8', '9', '10', '11'], 'answer': '10'},
          {'display': '12 - 5 = ?', 'options': ['5', '6', '7', '8'], 'answer': '7'},
          {'display': '9 + 4 = ?', 'options': ['11', '12', '13', '14'], 'answer': '13'},
          {'display': '15 - 3 = ?', 'options': ['10', '11', '12', '13'], 'answer': '12'},
          {'display': '8 + 6 = ?', 'options': ['12', '13', '14', '15'], 'answer': '14'},
          {'display': '11 - 6 = ?', 'options': ['4', '5', '6', '7'], 'answer': '5'},
        ];
      case '6-7': // 20 以内加减法与极其基础的乘法入门
      default:
        return [
          {'display': '12 + 7 = ?', 'options': ['17', '18', '19', '20'], 'answer': '19'},
          {'display': '20 - 8 = ?', 'options': ['10', '11', '12', '13'], 'answer': '12'},
          {'display': '2 x 3 = ?', 'options': ['4', '5', '6', '7'], 'answer': '6'},
          {'display': '15 + 4 = ?', 'options': ['18', '19', '20', '21'], 'answer': '19'},
          {'display': '18 - 9 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
          {'display': '3 x 4 = ?', 'options': ['10', '11', '12', '13'], 'answer': '12'},
          {'display': '14 + 6 = ?', 'options': ['18', '19', '20', '21'], 'answer': '20'},
          {'display': '2 x 5 = ?', 'options': ['8', '9', '10', '11'], 'answer': '10'},
          {'display': '16 - 7 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
          {'display': '4 x 2 = ?', 'options': ['6', '7', '8', '9'], 'answer': '8'},
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    // 2. 初始化时装载题库
    questions = _generateQuestions(widget.ageGroup);
    
    // 3. 批量随机打乱 10 道题的四个选项顺序
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
          // 保留你的原版逻辑：切题时确保下一题的选项也被安全打乱
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
      subject: 'arithmetic',
      module: 'arithmetic',
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
                  ? 'Perfect math!'
                  : score >= 6 // 从原本的 3 题改为 6 题及格 (60%)
                      ? 'Great counting!'
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

  Color _getOptionColor(String option) {
    if (!answered) return const Color(0xFFFF8FAB);
    if (option == questions[currentQuestion]['answer']) {
      return const Color(0xFF4DD9C0);
    }
    if (option == selectedAnswer) return Colors.redAccent;
    return const Color(0xFFFF8FAB);
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[currentQuestion];
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
                  const SizedBox(height: 32),
                  const Center(
                    child: Text(
                      'Solve the problem',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        q['display'],
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                    ),
                  ),
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
                          decoration: BoxDecoration(
                            color: _getOptionColor(option),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
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