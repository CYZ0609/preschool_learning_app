import 'package:flutter/material.dart';
import '../../services/progress_service.dart';

class ArithmeticGameScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  const ArithmeticGameScreen({super.key, required this.ageGroup, required this.kidId});

  @override
  State<ArithmeticGameScreen> createState() => _ArithmeticGameScreenState();
}

class _ArithmeticGameScreenState extends State<ArithmeticGameScreen> {
  int currentQuestion = 0;
  int score = 0;
  String? selectedAnswer;
  bool answered = false;
  int difficultyLevel = 1;
  bool isLoadingDifficulty = true;

  late List<Map<String, dynamic>> questions;

  List<Map<String, dynamic>> _generateQuestions(String age, [int level = 1]) {
    switch (age) {
      case '4-5':
        if (level >= 2) {
          return [
            {'display': '3 + 4 = ?', 'options': ['5', '6', '7', '8'], 'answer': '7'},
            {'display': '6 + 2 = ?', 'options': ['6', '7', '8', '9'], 'answer': '8'},
            {'display': '7 - 3 = ?', 'options': ['3', '4', '5', '6'], 'answer': '4'},
            {'display': '5 + 4 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
            {'display': '8 - 3 = ?', 'options': ['3', '4', '5', '6'], 'answer': '5'},
            {'display': '4 + 5 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
            {'display': '9 - 4 = ?', 'options': ['3', '4', '5', '6'], 'answer': '5'},
            {'display': '6 + 3 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
            {'display': '7 - 2 = ?', 'options': ['3', '4', '5', '6'], 'answer': '5'},
            {'display': '5 + 5 = ?', 'options': ['8', '9', '10', '11'], 'answer': '10'},
          ];
        }
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
      case '5-6':
        if (level >= 2) {
          return [
            {'display': '11 + 4 = ?', 'options': ['13', '14', '15', '16'], 'answer': '15'},
            {'display': '18 - 5 = ?', 'options': ['11', '12', '13', '14'], 'answer': '13'},
            {'display': '13 + 6 = ?', 'options': ['17', '18', '19', '20'], 'answer': '19'},
            {'display': '20 - 7 = ?', 'options': ['11', '12', '13', '14'], 'answer': '13'},
            {'display': '14 + 5 = ?', 'options': ['17', '18', '19', '20'], 'answer': '19'},
            {'display': '17 - 8 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
            {'display': '12 + 7 = ?', 'options': ['17', '18', '19', '20'], 'answer': '19'},
            {'display': '19 - 6 = ?', 'options': ['11', '12', '13', '14'], 'answer': '13'},
            {'display': '15 + 4 = ?', 'options': ['17', '18', '19', '20'], 'answer': '19'},
            {'display': '20 - 9 = ?', 'options': ['9', '10', '11', '12'], 'answer': '11'},
          ];
        }
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
      case '6-7':
      default:
        if (level >= 2) {
          return [
            {'display': '25 + 5 = ?', 'options': ['28', '29', '30', '31'], 'answer': '30'},
            {'display': '30 - 12 = ?', 'options': ['16', '17', '18', '19'], 'answer': '18'},
            {'display': '22 + 8 = ?', 'options': ['28', '29', '30', '31'], 'answer': '30'},
            {'display': '35 - 15 = ?', 'options': ['18', '19', '20', '21'], 'answer': '20'},
            {'display': '18 + 12 = ?', 'options': ['28', '29', '30', '31'], 'answer': '30'},
            {'display': '40 - 18 = ?', 'options': ['20', '21', '22', '23'], 'answer': '22'},
            {'display': '24 + 6 = ?', 'options': ['28', '29', '30', '31'], 'answer': '30'},
            {'display': '33 - 13 = ?', 'options': ['18', '19', '20', '21'], 'answer': '20'},
            {'display': '27 + 3 = ?', 'options': ['28', '29', '30', '31'], 'answer': '30'},
            {'display': '45 - 25 = ?', 'options': ['18', '19', '20', '21'], 'answer': '20'},
          ];
        }
        return [
          {'display': '12 + 7 = ?', 'options': ['17', '18', '19', '20'], 'answer': '19'},
          {'display': '20 - 8 = ?', 'options': ['10', '11', '12', '13'], 'answer': '12'},
          {'display': '15 + 4 = ?', 'options': ['18', '19', '20', '21'], 'answer': '19'},
          {'display': '18 - 9 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
          {'display': '14 + 6 = ?', 'options': ['18', '19', '20', '21'], 'answer': '20'},
          {'display': '16 - 7 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
          {'display': '13 + 5 = ?', 'options': ['16', '17', '18', '19'], 'answer': '18'},
          {'display': '19 - 6 = ?', 'options': ['11', '12', '13', '14'], 'answer': '13'},
          {'display': '11 + 9 = ?', 'options': ['18', '19', '20', '21'], 'answer': '20'},
          {'display': '17 - 8 = ?', 'options': ['7', '8', '9', '10'], 'answer': '9'},
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDifficulty();
  }

  Future<void> _loadDifficulty() async {
    final level = await ProgressService.getDifficultyLevel(
        'arithmetic', widget.ageGroup);
    setState(() {
      difficultyLevel = level;
      isLoadingDifficulty = false;
      questions = _generateQuestions(widget.ageGroup, difficultyLevel);
      for (var q in questions) {
        q['options'] = List<String>.from(q['options'])..shuffle();
      }
    });
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
    final passed = score >= (questions.length * 0.7).ceil();
    final newLevel = passed
        ? (difficultyLevel < 2 ? difficultyLevel + 1 : 2)
        : difficultyLevel;

    ProgressService.saveProgress(
      subject: 'arithmetic',
      module: 'arithmetic',
      ageGroup: widget.ageGroup,
      score: score,
      totalQuestions: questions.length,
      kidId: widget.kidId,
    );

    ProgressService.updateDifficultyLevel(
        'arithmetic', widget.ageGroup, newLevel);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          passed && newLevel > difficultyLevel ? '🌟 Level Up!' : 'Quiz Complete!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
              passed && newLevel > difficultyLevel
                  ? 'Amazing! You unlocked Level $newLevel! 🎉'
                  : score == questions.length
                      ? 'Perfect math!'
                      : score >= (questions.length * 0.6).ceil()
                          ? 'Great counting!'
                          : 'Score 7/10 to level up!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Level $difficultyLevel ${newLevel > difficultyLevel ? "→ Level $newLevel 🔓" : "(Score 7/10 to level up!)"}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFFF8FAB),
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    if (isLoadingDifficulty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8FAB)),
        ),
      );
    }

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${currentQuestion + 1} of ${questions.length}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF888888)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Level $difficultyLevel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF8FAB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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