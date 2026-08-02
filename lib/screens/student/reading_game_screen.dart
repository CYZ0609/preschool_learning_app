import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/progress_service.dart';

class ReadingGameScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  const ReadingGameScreen({super.key, required this.ageGroup, required this.kidId});

  @override
  State<ReadingGameScreen> createState() => _ReadingGameScreenState();
}

class _ReadingGameScreenState extends State<ReadingGameScreen> {
  final FlutterTts tts = FlutterTts();

  int currentQuestion = 0;
  int score = 0;
  String? selectedAnswer; // 记录当前点击高亮、但还没点确定的图片路径
  bool answered = false;  // 只有点了 CONFIRM 按钮后，才会锁定并判定对错

  late List<Map<String, dynamic>> questions;

  // 📖 完美匹配你本地 30 张真实图片的 10 题制“看词选图”题库
List<Map<String, dynamic>> _generateQuestions(String age) {
    switch (age) {
      case '4-5':
        return [
          {'word': 'CAT', 'answer': 'assets/images/cat.png', 'options': ['assets/images/cat.png', 'assets/images/dog.png', 'assets/images/sun.png', 'assets/images/tree.png']},
          {'word': 'DOG', 'answer': 'assets/images/dog.png', 'options': ['assets/images/dog.png', 'assets/images/cow.png', 'assets/images/hat.png', 'assets/images/grass.png']},
          {'word': 'COW', 'answer': 'assets/images/cow.png', 'options': ['assets/images/cow.png', 'assets/images/pig.png', 'assets/images/bird.png', 'assets/images/ant.png']},
          {'word': 'PIG', 'answer': 'assets/images/pig.png', 'options': ['assets/images/pig.png', 'assets/images/fish.png', 'assets/images/tree.png', 'assets/images/rock.png']},
          {'word': 'FISH', 'answer': 'assets/images/fish.png', 'options': ['assets/images/fish.png', 'assets/images/bird.png', 'assets/images/cat.png', 'assets/images/hat.png']},
          {'word': 'BIRD', 'answer': 'assets/images/bird.png', 'options': ['assets/images/bird.png', 'assets/images/sun.png', 'assets/images/ant.png', 'assets/images/dog.png']},
          {'word': 'SUN', 'answer': 'assets/images/sun.png', 'options': ['assets/images/sun.png', 'assets/images/hat.png', 'assets/images/grass.png', 'assets/images/cow.png']},
          {'word': 'HAT', 'answer': 'assets/images/hat.png', 'options': ['assets/images/hat.png', 'assets/images/tree.png', 'assets/images/rock.png', 'assets/images/pig.png']},
          {'word': 'ANT', 'answer': 'assets/images/ant.png', 'options': ['assets/images/ant.png', 'assets/images/rock.png', 'assets/images/cat.png', 'assets/images/fish.png']},
          {'word': 'TREE', 'answer': 'assets/images/tree.png', 'options': ['assets/images/tree.png', 'assets/images/grass.png', 'assets/images/dog.png', 'assets/images/bird.png']},
          {'word': 'GRASS', 'answer': 'assets/images/grass.png', 'options': ['assets/images/grass.png', 'assets/images/rock.png', 'assets/images/sun.png', 'assets/images/pig.png']},
          {'word': 'ROCK', 'answer': 'assets/images/rock.png', 'options': ['assets/images/rock.png', 'assets/images/cat.png', 'assets/images/hat.png', 'assets/images/cow.png']},
        ];
      case '5-6':
        return [
          {'word': 'TIGER', 'answer': 'assets/images/tiger.png', 'options': ['assets/images/tiger.png', 'assets/images/rabbit.png', 'assets/images/monkey.png', 'assets/images/apple.png']},
          {'word': 'RABBIT', 'answer': 'assets/images/rabbit.png', 'options': ['assets/images/rabbit.png', 'assets/images/frog.png', 'assets/images/chair.png', 'assets/images/flower.png']},
          {'word': 'MONKEY', 'answer': 'assets/images/monkey.png', 'options': ['assets/images/monkey.png', 'assets/images/zebra.png', 'assets/images/table.png', 'assets/images/water.png']},
          {'word': 'FROG', 'answer': 'assets/images/frog.png', 'options': ['assets/images/frog.png', 'assets/images/fox.png', 'assets/images/mango.png', 'assets/images/fence.png']},
          {'word': 'ZEBRA', 'answer': 'assets/images/zebra.png', 'options': ['assets/images/zebra.png', 'assets/images/lion.png', 'assets/images/tiger.png', 'assets/images/apple.png']},
          {'word': 'FOX', 'answer': 'assets/images/fox.png', 'options': ['assets/images/fox.png', 'assets/images/rabbit.png', 'assets/images/chair.png', 'assets/images/water.png']},
          {'word': 'LION', 'answer': 'assets/images/lion.png', 'options': ['assets/images/lion.png', 'assets/images/monkey.png', 'assets/images/mango.png', 'assets/images/flower.png']},
          {'word': 'APPLE', 'answer': 'assets/images/apple.png', 'options': ['assets/images/apple.png', 'assets/images/water.png', 'assets/images/mango.png', 'assets/images/frog.png']},
          {'word': 'CHAIR', 'answer': 'assets/images/chair.png', 'options': ['assets/images/chair.png', 'assets/images/table.png', 'assets/images/fence.png', 'assets/images/zebra.png']},
          {'word': 'TABLE', 'answer': 'assets/images/table.png', 'options': ['assets/images/table.png', 'assets/images/chair.png', 'assets/images/water.png', 'assets/images/fox.png']},
          {'word': 'WATER', 'answer': 'assets/images/water.png', 'options': ['assets/images/water.png', 'assets/images/apple.png', 'assets/images/flower.png', 'assets/images/lion.png']},
          {'word': 'MANGO', 'answer': 'assets/images/mango.png', 'options': ['assets/images/mango.png', 'assets/images/apple.png', 'assets/images/table.png', 'assets/images/tiger.png']},
          {'word': 'FENCE', 'answer': 'assets/images/fence.png', 'options': ['assets/images/fence.png', 'assets/images/chair.png', 'assets/images/flower.png', 'assets/images/rabbit.png']},
          {'word': 'FLOWER', 'answer': 'assets/images/flower.png', 'options': ['assets/images/flower.png', 'assets/images/water.png', 'assets/images/mango.png', 'assets/images/monkey.png']},
        ];
      case '6-7':
      default:
        return [
          {'word': 'ELEPHANT', 'answer': 'assets/images/elephant.png', 'options': ['assets/images/elephant.png', 'assets/images/giraffe.png', 'assets/images/kangaroo.png', 'assets/images/umbrella.png']},
          {'word': 'GIRAFFE', 'answer': 'assets/images/giraffe.png', 'options': ['assets/images/giraffe.png', 'assets/images/parrot.png', 'assets/images/teacher.png', 'assets/images/pencil.png']},
          {'word': 'KANGAROO', 'answer': 'assets/images/kangaroo.png', 'options': ['assets/images/kangaroo.png', 'assets/images/donkey.png', 'assets/images/elephant.png', 'assets/images/umbrella.png']},
          {'word': 'PARROT', 'answer': 'assets/images/parrot.png', 'options': ['assets/images/parrot.png', 'assets/images/lizard.png', 'assets/images/giraffe.png', 'assets/images/teacher.png']},
          {'word': 'DONKEY', 'answer': 'assets/images/donkey.png', 'options': ['assets/images/donkey.png', 'assets/images/dinosaur.png', 'assets/images/kangaroo.png', 'assets/images/pencil.png']},
          {'word': 'LIZARD', 'answer': 'assets/images/lizard.png', 'options': ['assets/images/lizard.png', 'assets/images/parrot.png', 'assets/images/dinosaur.png', 'assets/images/umbrella.png']},
          {'word': 'DINOSAUR', 'answer': 'assets/images/dinosaur.png', 'options': ['assets/images/dinosaur.png', 'assets/images/elephant.png', 'assets/images/donkey.png', 'assets/images/teacher.png']},
          {'word': 'UMBRELLA', 'answer': 'assets/images/umbrella.png', 'options': ['assets/images/umbrella.png', 'assets/images/pencil.png', 'assets/images/giraffe.png', 'assets/images/lizard.png']},
          {'word': 'TEACHER', 'answer': 'assets/images/teacher.png', 'options': ['assets/images/teacher.png', 'assets/images/umbrella.png', 'assets/images/kangaroo.png', 'assets/images/dinosaur.png']},
          {'word': 'PENCIL', 'answer': 'assets/images/pencil.png', 'options': ['assets/images/pencil.png', 'assets/images/teacher.png', 'assets/images/elephant.png', 'assets/images/parrot.png']},
        ];
    }
  }
  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);

    questions = _generateQuestions(widget.ageGroup);
    // 批量随机打乱所有题目的选项
    for (var q in questions) {
      q['options'] = List<String>.from(q['options'])..shuffle();
    }
  }

  // 1. 小朋友轻触选项：触发高亮，并大声读出该图片的英文单词来消除抽象歧义
  void tapOption(String optionImage) async {
    if (answered) return; // 已经锁定答案后不能重复点击
    
    // 从本地路径提取单词（例如：assets/images/doctor.png -> doctor）
    String spokenWord = optionImage.split('/').last.split('.').first;
    await tts.speak(spokenWord);

    setState(() {
      selectedAnswer = optionImage;
    });
  }

  // 2. 小朋友确认无误，点击底部的 CONFIRM 按钮提交判定对错
  void confirmAnswer() {
    if (selectedAnswer == null || answered) return;

    setState(() {
      answered = true;
      if (selectedAnswer == questions[currentQuestion]['answer']) {
        score++;
      }
    });

    // 停留 1.5 秒给幼儿看清对错反馈，然后自动切题
    Future.delayed(const Duration(milliseconds: 1500), () {
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

  // 判定方块应该显示什么颜色
  Color _getOptionColor(String optionImage) {
    if (!answered) {
      // 还没点确定：如果是当前被选中的方块，给它高亮的粉色外边框
      return optionImage == selectedAnswer ? const Color(0xFFFF8FAB) : const Color(0xFFEEEEEE);
    }
    // 点了确定后：正确答案亮起健康的青绿色，选错的亮起红色，其余变灰
    if (optionImage == questions[currentQuestion]['answer']) {
      return const Color(0xFF4DD9C0);
    }
    if (optionImage == selectedAnswer) {
      return Colors.redAccent;
    }
    return const Color(0xFFEEEEEE);
  }

  void _showResult() {
    ProgressService.saveProgress(
      subject: 'reading',
      module: 'reading',
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
                color: Color(0xFF4DD9C0),
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
                  ? 'Perfect reading!'
                  : score >= 6
                      ? 'Great job!'
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
                backgroundColor: const Color(0xFF4DD9C0),
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
    final q = questions[currentQuestion];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 原版背景粉色与青色球体 (100% 完美复刻)
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
                  // 原版高级平滑进度条
                  Row(
                    children: List.generate(questions.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentQuestion
                                ? const Color(0xFF4DD9C0)
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
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Read and choose the correct image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 🌟 中央大字卡：显示当前正在阅读考核的单词文本 🌟
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FBF7),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4DD9C0).withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Text(
                        q['word'],
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A8C7A),
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 🌟 2x2 精美少儿图片选项网格布局 🌟
                  Expanded(
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.0,
                      children: (q['options'] as List<String>).map((optionImage) {
                        return GestureDetector(
                          onTap: () => tapOption(optionImage),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getOptionColor(optionImage),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(6), // 亮色对错外壳包裹
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white, // 纯白底座，保护非透明图片视觉统一
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  optionImage,
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
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 🌟 全新二级机制核心：CONFIRM 确定按钮 🌟
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: selectedAnswer != null && !answered ? confirmAnswer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD9C0),
                        disabledBackgroundColor: Colors.grey[300], // 未选择图片时呈现灰色禁用状态
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