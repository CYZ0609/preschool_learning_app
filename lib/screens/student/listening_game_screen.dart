import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/progress_service.dart';

class ListeningGameScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  const ListeningGameScreen({super.key, required this.ageGroup, required this.kidId});
  
  @override
  State<ListeningGameScreen> createState() => _ListeningGameScreenState();
}

class _ListeningGameScreenState extends State<ListeningGameScreen> {
  int currentQuestion = 0;
  int score = 0;
  int difficultyLevel = 1;
  String? selectedAnswer;
  bool answered = false;
  
  // 第一步：加入 loading 变量
  bool isLoadingDifficulty = true;

  final FlutterTts tts = FlutterTts();

  List<Map<String, dynamic>> get questions {
    switch (widget.ageGroup) {
      case '4-5':
        return [
          {
            'question': 'What do you hear?',
            'audio': 'cat',
            'options': [
              {'text': 'Cat', 'image': 'assets/images/cat.png'},
              {'text': 'Dog', 'image': 'assets/images/dog.png'},
              {'text': 'Sun', 'image': 'assets/images/sun.png'},
              {'text': 'Hat', 'image': 'assets/images/hat.png'},
            ],
            'answer': 'Cat'
          },
          {
            'question': 'What do you hear?',
            'audio': 'dog',
            'options': [
              {'text': 'Cat', 'image': 'assets/images/cat.png'},
              {'text': 'Dog', 'image': 'assets/images/dog.png'},
              {'text': 'Sun', 'image': 'assets/images/sun.png'},
              {'text': 'Hat', 'image': 'assets/images/hat.png'},
            ],
            'answer': 'Dog'
          },
          {
            'question': 'What do you hear?',
            'audio': 'sun',
            'options': [
              {'text': 'Sun', 'image': 'assets/images/sun.png'},
              {'text': 'Hat', 'image': 'assets/images/hat.png'},
              {'text': 'Fish', 'image': 'assets/images/fish.png'},
              {'text': 'Cat', 'image': 'assets/images/cat.png'},
            ],
            'answer': 'Sun'
          },
          {
            'question': 'What do you hear?',
            'audio': 'hat',
            'options': [
              {'text': 'Dog', 'image': 'assets/images/dog.png'},
              {'text': 'Hat', 'image': 'assets/images/hat.png'},
              {'text': 'Fish', 'image': 'assets/images/fish.png'},
              {'text': 'Sun', 'image': 'assets/images/sun.png'},
            ],
            'answer': 'Hat'
          },
          {
            'question': 'What do you hear?',
            'audio': 'fish',
            'options': [
              {'text': 'Fish', 'image': 'assets/images/fish.png'},
              {'text': 'Cat', 'image': 'assets/images/cat.png'},
              {'text': 'Dog', 'image': 'assets/images/dog.png'},
              {'text': 'Hat', 'image': 'assets/images/hat.png'},
            ],
            'answer': 'Fish'
          },
          {
            'question': 'What do you hear?',
            'audio': 'pig',
            'options': [
              {'text': 'Pig', 'image': 'assets/images/pig.png'},
              {'text': 'Cow', 'image': 'assets/images/cow.png'},
              {'text': 'Ant', 'image': 'assets/images/ant.png'},
              {'text': 'Fox', 'image': 'assets/images/fox.png'},
            ],
            'answer': 'Pig'
          },
          {
            'question': 'What do you hear?',
            'audio': 'cow',
            'options': [
              {'text': 'Pig', 'image': 'assets/images/pig.png'},
              {'text': 'Cow', 'image': 'assets/images/cow.png'},
              {'text': 'Ant', 'image': 'assets/images/ant.png'},
              {'text': 'Fox', 'image': 'assets/images/fox.png'},
            ],
            'answer': 'Cow'
          },
          {
            'question': 'What do you hear?',
            'audio': 'bird',
            'options': [
              {'text': 'Bird', 'image': 'assets/images/bird.png'},
              {'text': 'Frog', 'image': 'assets/images/frog.png'},
              {'text': 'Duck', 'image': 'assets/images/duck.png'},
              {'text': 'Lion', 'image': 'assets/images/lion.png'},
            ],
            'answer': 'Bird'
          },
          {
            'question': 'What do you hear?',
            'audio': 'frog',
            'options': [
              {'text': 'Bird', 'image': 'assets/images/bird.png'},
              {'text': 'Frog', 'image': 'assets/images/frog.png'},
              {'text': 'Duck', 'image': 'assets/images/duck.png'},
              {'text': 'Lion', 'image': 'assets/images/lion.png'},
            ],
            'answer': 'Frog'
          },
          {
            'question': 'What do you hear?',
            'audio': 'lion',
            'options': [
              {'text': 'Bird', 'image': 'assets/images/bird.png'},
              {'text': 'Frog', 'image': 'assets/images/frog.png'},
              {'text': 'Duck', 'image': 'assets/images/duck.png'},
              {'text': 'Lion', 'image': 'assets/images/lion.png'},
            ],
            'answer': 'Lion'
          },
        ];
      case '5-6':
        return [
          {
            'question': 'What do you hear?',
            'audio': 'apple',
            'options': [
              {'text': 'Apple', 'image': 'assets/images/apple.png'},
              {'text': 'Mango', 'image': 'assets/images/mango.png'},
              {'text': 'Grape', 'image': 'assets/images/grape.png'},
              {'text': 'Lemon', 'image': 'assets/images/lemon.png'},
            ],
            'answer': 'Apple'
          },
          {
            'question': 'What do you hear?',
            'audio': 'rabbit',
            'options': [
              {'text': 'Rabbit', 'image': 'assets/images/rabbit.png'},
              {'text': 'Monkey', 'image': 'assets/images/monkey.png'},
              {'text': 'Tiger', 'image': 'assets/images/tiger.png'},
              {'text': 'Parrot', 'image': 'assets/images/parrot.png'},
            ],
            'answer': 'Rabbit'
          },
          {
            'question': 'What do you hear?',
            'audio': 'yellow',
            'options': [
              {'text': 'Yellow', 'image': 'assets/images/yellow.png'},
              {'text': 'Purple', 'image': 'assets/images/purple.png'},
              {'text': 'Orange', 'image': 'assets/images/orange.png'},
              {'text': 'Green', 'image': 'assets/images/green.png'},
            ],
            'answer': 'Yellow'
          },
          {
            'question': 'What do you hear?',
            'audio': 'table',
            'options': [
              {'text': 'Table', 'image': 'assets/images/table.png'},
              {'text': 'Chair', 'image': 'assets/images/chair.png'},
              {'text': 'Window', 'image': 'assets/images/window.png'},
              {'text': 'Bottle', 'image': 'assets/images/bottle.png'},
            ],
            'answer': 'Table'
          },
          {
            'question': 'What do you hear?',
            'audio': 'water',
            'options': [
              {'text': 'Water', 'image': 'assets/images/water.png'},
              {'text': 'Paper', 'image': 'assets/images/paper.png'},
              {'text': 'Flower', 'image': 'assets/images/flower.png'},
              {'text': 'Rubber', 'image': 'assets/images/rubber.png'},
            ],
            'answer': 'Water'
          },
          {
            'question': 'What do you hear?',
            'audio': 'banana',
            'options': [
              {'text': 'Banana', 'image': 'assets/images/banana.png'},
              {'text': 'Orange', 'image': 'assets/images/orange.png'},
              {'text': 'Cherry', 'image': 'assets/images/cherry.png'},
              {'text': 'Grapes', 'image': 'assets/images/grapes.png'},
            ],
            'answer': 'Banana'
          },
          {
            'question': 'What do you hear?',
            'audio': 'monkey',
            'options': [
              {'text': 'Monkey', 'image': 'assets/images/monkey.png'},
              {'text': 'Donkey', 'image': 'assets/images/donkey.png'},
              {'text': 'Zebra', 'image': 'assets/images/zebra.png'},
              {'text': 'Giraffe', 'image': 'assets/images/giraffe.png'},
            ],
            'answer': 'Monkey'
          },
          {
            'question': 'What do you hear?',
            'audio': 'purple',
            'options': [
              {'text': 'Yellow', 'image': 'assets/images/yellow.png'},
              {'text': 'Purple', 'image': 'assets/images/purple.png'},
              {'text': 'Orange', 'image': 'assets/images/orange.png'},
              {'text': 'Green', 'image': 'assets/images/green.png'},
            ],
            'answer': 'Purple'
          },
          {
            'question': 'What do you hear?',
            'audio': 'pencil',
            'options': [
              {'text': 'Table', 'image': 'assets/images/table.png'},
              {'text': 'Chair', 'image': 'assets/images/chair.png'},
              {'text': 'Pencil', 'image': 'assets/images/pencil.png'},
              {'text': 'Ruler', 'image': 'assets/images/ruler.png'},
            ],
            'answer': 'Pencil'
          },
          {
            'question': 'What do you hear?',
            'audio': 'doctor',
            'options': [
              {'text': 'Nurse', 'image': 'assets/images/nurse.png'},
              {'text': 'Doctor', 'image': 'assets/images/doctor.png'},
              {'text': 'Teacher', 'image': 'assets/images/teacher.png'},
              {'text': 'Pilot', 'image': 'assets/images/pilot.png'},
            ],
            'answer': 'Doctor'
          },
        ];
      case '6-7':
      default:
        return [
          {
            'question': 'What do you hear?',
            'audio': 'elephant',
            'options': [
              {'text': 'Elephant', 'image': 'assets/images/elephant.png'},
              {'text': 'Umbrella', 'image': 'assets/images/umbrella.png'},
              {'text': 'Ambulance', 'image': 'assets/images/ambulance.png'},
              {'text': 'Alphabet', 'image': 'assets/images/alphabet.png'},
            ],
            'answer': 'Elephant'
          },
          {
            'question': 'What do you hear?',
            'audio': 'butterfly',
            'options': [
              {'text': 'Butterfly', 'image': 'assets/images/butterfly.png'},
              {'text': 'Dragonfly', 'image': 'assets/images/dragonfly.png'},
              {'text': 'Caterpillar', 'image': 'assets/images/caterpillar.png'},
              {'text': 'Grasshopper', 'image': 'assets/images/grasshopper.png'},
            ],
            'answer': 'Butterfly'
          },
          {
            'question': 'What do you hear?',
            'audio': 'triangle',
            'options': [
              {'text': 'Triangle', 'image': 'assets/images/triangle.png'},
              {'text': 'Rectangle', 'image': 'assets/images/rectangle.png'},
              {'text': 'Pentagon', 'image': 'assets/images/pentagon.png'},
              {'text': 'Cylinder', 'image': 'assets/images/cylinder.png'},
            ],
            'answer': 'Triangle'
          },
          {
            'question': 'What do you hear?',
            'audio': 'library',
            'options': [
              {'text': 'Library', 'image': 'assets/images/library.png'},
              {'text': 'Bakery', 'image': 'assets/images/bakery.png'},
              {'text': 'Factory', 'image': 'assets/images/factory.png'},
              {'text': 'Laundry', 'image': 'assets/images/laundry.png'},
            ],
            'answer': 'Library'
          },
          {
            'question': 'What do you hear?',
            'audio': 'comfortable',
            'options': [
              {'text': 'Comfortable', 'image': 'assets/images/comfortable.png'},
              {'text': 'Complicated', 'image': 'assets/images/complicated.png'},
              {'text': 'Community', 'image': 'assets/images/community.png'},
              {'text': 'Competition', 'image': 'assets/images/competition.png'},
            ],
            'answer': 'Comfortable'
          },
          {
            'question': 'What do you hear?',
            'audio': 'astronaut',
            'options': [
              {'text': 'Astronaut', 'image': 'assets/images/astronaut.png'},
              {'text': 'Architect', 'image': 'assets/images/architect.png'},
              {'text': 'Archaeologist', 'image': 'assets/images/archaeologist.png'},
              {'text': 'Assistant', 'image': 'assets/images/assistant.png'},
            ],
            'answer': 'Astronaut'
          },
          {
            'question': 'What do you hear?',
            'audio': 'dinosaur',
            'options': [
              {'text': 'Crocodile', 'image': 'assets/images/crocodile.png'},
              {'text': 'Dinosaur', 'image': 'assets/images/dinosaur.png'},
              {'text': 'Lizard', 'image': 'assets/images/lizard.png'},
              {'text': 'Kangaroo', 'image': 'assets/images/kangaroo.png'},
            ],
            'answer': 'Dinosaur'
          },
          {
            'question': 'What do you hear?',
            'audio': 'rectangle',
            'options': [
              {'text': 'Triangle', 'image': 'assets/images/triangle.png'},
              {'text': 'Rectangle', 'image': 'assets/images/rectangle.png'},
              {'text': 'Pentagon', 'image': 'assets/images/pentagon.png'},
              {'text': 'Cylinder', 'image': 'assets/images/cylinder.png'},
            ],
            'answer': 'Rectangle'
          },
          {
            'question': 'What do you hear?',
            'audio': 'hospital',
            'options': [
              {'text': 'Library', 'image': 'assets/images/library.png'},
              {'text': 'Hospital', 'image': 'assets/images/hospital.png'},
              {'text': 'Factory', 'image': 'assets/images/factory.png'},
              {'text': 'University', 'image': 'assets/images/university.png'},
            ],
            'answer': 'Hospital'
          },
          {
            'question': 'What do you hear?',
            'audio': 'beautiful',
            'options': [
              {'text': 'Beautiful', 'image': 'assets/images/beautiful.png'},
              {'text': 'Wonderful', 'image': 'assets/images/wonderful.png'},
              {'text': 'Dangerous', 'image': 'assets/images/dangerous.png'},
              {'text': 'Powerful', 'image': 'assets/images/powerful.png'},
            ],
            'answer': 'Beautiful'
          },
        ];
    }
  }

  // 第二步：改写 initState 并加入 _loadDifficulty
  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    _loadDifficulty();
  }

  Future<void> _loadDifficulty() async {
    final level = await ProgressService.getDifficultyLevel(
        'listening', widget.ageGroup);
    
    if (!mounted) return;
    setState(() {
      difficultyLevel = level;
      isLoadingDifficulty = false;
      for (var q in questions) {
        q['options'] =
            List<Map<String, dynamic>>.from(q['options'])..shuffle();
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _speak();
    });
  }

  Future<void> _speak() async {
    await tts.speak(questions[currentQuestion]['audio']);
  }

  void tapOption(String optionText) async {
    if (answered) return;
    await tts.speak(optionText);
    setState(() {
      selectedAnswer = optionText;
    });
  }

  void confirmAnswer() {
    if (selectedAnswer == null || answered) return;

    setState(() {
      answered = true;
      if (selectedAnswer == questions[currentQuestion]['answer']) {
        score++;
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (currentQuestion < questions.length - 1) {
        setState(() {
          currentQuestion++;
          selectedAnswer = null;
          answered = false;
          questions[currentQuestion]['options'] =
              List<Map<String, dynamic>>.from(questions[currentQuestion]['options'])..shuffle();
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          _speak();
        });
      } else {
        _showResult();
      }
    });
  }

  // 第三步：完全替换你给的 _showResult
  void _showResult() {
    final passed = score >= (questions.length * 0.7).ceil();
    final newLevel = passed ? (difficultyLevel < 3 ? difficultyLevel + 1 : 3) : difficultyLevel;

ProgressService.saveProgress(
  subject: 'english',
  module: 'listening',
  ageGroup: widget.ageGroup,
  score: score,
  totalQuestions: questions.length,
  difficultyLevel: difficultyLevel,
  kidId: widget.kidId,
);

    ProgressService.updateDifficultyLevel('listening', widget.ageGroup, newLevel);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              passed && newLevel > difficultyLevel
                  ? 'Amazing! You unlocked Level $newLevel! 🎉'
                  : score == questions.length
                      ? 'Perfect! Amazing job!'
                      : score >= (questions.length * 0.6).ceil()
                          ? 'Great work! Keep it up!'
                          : 'Good try! Score 7/10 to level up!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Current Level: $difficultyLevel → Next: $newLevel',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFFFAB40),
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
    if (!answered) {
      return option == selectedAnswer ? const Color(0xFFFF8FAB) : const Color(0xFFFFAB40);
    }
    if (option == questions[currentQuestion]['answer']) {
      return const Color(0xFF4DD9C0);
    }
    if (option == selectedAnswer) {
      return Colors.redAccent;
    }
    return const Color(0xFFFFAB40);
  }

  @override
  Widget build(BuildContext context) {
    // 第四步：在 build 开始处加上 Loading 状态的 Check
    if (isLoadingDifficulty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFAB40)),
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
                                ? const Color(0xFFFFAB40)
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
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      q['question'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => _speak(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFAB40),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFAB40).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.volume_up_rounded,
                            color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      children: (q['options'] as List<Map<String, dynamic>>).map((option) {
                        String optionText = option['text']!;
                        String optionImage = option['image']!;

                        return GestureDetector(
                          onTap: () => tapOption(optionText),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getOptionColor(optionText),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          optionImage,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.grey,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  optionText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: selectedAnswer != null && !answered ? confirmAnswer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD9C0),
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'CONFIRM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}