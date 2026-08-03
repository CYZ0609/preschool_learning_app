import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/progress_service.dart';
import '../../../services/sandbox_item_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/word_image.dart';

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

  List<Map<String, dynamic>> questions = [];
  bool isLoading = true; // 用于控制加载画面

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    _initGameData();
  }

  // 动态加载并拼装题目的核心逻辑
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
      var wrongChoices = activeWords.where((w) => w.word != target.word).toList();
      wrongChoices.shuffle();
      
      var optionsWords = [target, ...wrongChoices.take(3)]..shuffle();

      generatedQuestions.add({
        'word': target.word.toUpperCase(), 
        'answer': target.imageAsset,       
        'options': optionsWords.map((w) => {
          'text': w.word,
          'image': w.imageAsset
        }).toList(),
      });
    }

    if (!mounted) return;
    
    setState(() {
      questions = generatedQuestions;
      isLoading = false;
    });
  }

  // 1. 小朋友轻触选项：触发高亮，并大声读出该图片的英文单词来消除抽象歧义
  void tapOption(String optionImage, String optionText) async {
    if (answered) return; 
    
    // 直接读出动态词库里的真实单词
    await tts.speak(optionText);

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
              List<Map<String, dynamic>>.from(questions[currentQuestion]['options'])..shuffle();
        });
      } else {
        _showResult();
      }
    });
  }

  // 判定方块应该显示什么颜色
  Color _getOptionColor(String optionImage) {
    if (!answered) {
      return optionImage == selectedAnswer ? const Color(0xFFFF8FAB) : const Color(0xFFEEEEEE);
    }
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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4DD9C0)),
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
                  Expanded(
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.0,
                      children: (q['options'] as List<Map<String, dynamic>>).map((option) {
                        String optionImage = option['image'];
                        String optionText = option['text'];

                        return GestureDetector(
                          onTap: () => tapOption(optionImage, optionText),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getOptionColor(optionImage),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: WordImage(
                                  imageAsset: optionImage,
                                ),
                              ),
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