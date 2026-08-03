import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/progress_service.dart';
import '../../../services/sandbox_item_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/word_image.dart';

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

 // 用来存储我们动态生成的题目
// 用来存储我们动态生成的题目
  List<Map<String, dynamic>> questions = [];

  // 第二步：改写 initState 并加入 _loadDifficulty
  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    _loadDifficulty();
  }

Future<void> _loadDifficulty() async {
    // 1. 获取难度等级
    final level = await ProgressService.getDifficultyLevel('listening', widget.ageGroup);
    
    // 2. 拉取系统默认词库 + 老师后台添加的自定义词库
    final allCustomItems = await SandboxItemService.loadGlobalItems();

// 过滤出：只属于当前小朋友年龄段的词，或者老师设定为全年龄通用的词
final customItems = allCustomItems.where((item) {
  // 假设你的 Item 模型里加了一个 targetAge 属性
  return item.targetAge == widget.ageGroup || item.targetAge == 'all'; 
}).toList();
    final builtInWords = defaultMapWordsFor(widget.ageGroup);
    
    // 3. 将它们合并成一个当前的“活跃词库”
    final activeWords = mergeCustomVocabulary(builtIn: builtInWords, custom: customItems);
    
    // 4. 打乱词库，并抽出 10 个词作为本局游戏的“正确答案”
    activeWords.shuffle();
    final targetWords = activeWords.take(10).toList();

    // 5. 自动出题机：为这 10 个正确答案生成完整的题目结构
    List<Map<String, dynamic>> generatedQuestions = [];
    
    for (var target in targetWords) {
      // 从词库里筛掉正确答案，剩下的打乱，抽出 3 个作为“错误干扰项”
      var wrongChoices = activeWords.where((w) => w.word != target.word).toList();
      wrongChoices.shuffle();
      
      // 把 1 个正确答案和 3 个错误选项混在一起，再次打乱顺序
      var optionsWords = [target, ...wrongChoices.take(3)]..shuffle();

      // 按照你原本的 UI 数据格式组装这道题
      generatedQuestions.add({
        'question': 'What do you hear?',
        'audio': target.word.toLowerCase(), // 发音引擎会读这个词
        'answer': target.word,
        'options': optionsWords.map((w) => {
          'text': w.word,
          'image': w.imageAsset // 如果是老师新加的词，这里会自动变成网络图片链接
        }).toList(),
      });
    }
    
    if (!mounted) return;
    
    // 6. 更新状态，告诉系统数据加载完毕，可以渲染页面了
    setState(() {
      difficultyLevel = level;
      questions = generatedQuestions; // 把做好的题塞进状态里
      isLoadingDifficulty = false;
    });

    // 7. 延迟半秒钟后，自动朗读第一题的单词
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
                                        // ✨ 使用支持网络和本地图片的 WordImage
                                        child: WordImage(
                                          imageAsset: optionImage,
                                          errorWidget: const Icon(
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