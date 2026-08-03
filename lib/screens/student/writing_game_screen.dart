import 'package:flutter/material.dart';
import '../../services/progress_service.dart';
import '../../../services/sandbox_item_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/word_image.dart';

class WritingGameScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  const WritingGameScreen({super.key, required this.ageGroup, required this.kidId});

  @override
  State<WritingGameScreen> createState() => _WritingGameScreenState();
}

class _WritingGameScreenState extends State<WritingGameScreen> {
  int currentItem = 0;
  int score = 0;
  List<Offset?> userPoints = [];
  bool checked = false;
  double coverage = 0.0;
  bool isLoading = true;

  late bool isLetterMode;
  List<Map<String, dynamic>> items = []; 
  
  // ✨ 新增：用于绝对安全地记录画板的实际大小，防止由于取不到尺寸导致卡死
  Size? _canvasSize;

  @override
  void initState() {
    super.initState();
    isLetterMode = widget.ageGroup == '4-5';
    _initGameData();
  }

  Future<void> _initGameData() async {
    if (isLetterMode) {
      final letters = List.generate(26, (i) {
        final letter = String.fromCharCode(65 + i); 
        return {'word': letter, 'image': ''};
      });
      if (mounted) {
        setState(() {
          items = letters;
          isLoading = false;
        });
      }
    } else {
      final customItems = await SandboxItemService.loadGlobalItems();
      final builtInWords = defaultMapWordsFor(widget.ageGroup);
      final activeWords = mergeCustomVocabulary(builtIn: builtInWords, custom: customItems);

      activeWords.shuffle();
      final targetWords = activeWords.take(10).toList();

      final generatedWords = targetWords.map((w) => {
        'word': w.word.toUpperCase(), 
        'image': w.imageAsset,
      }).toList();

      if (mounted) {
        setState(() {
          items = generatedWords;
          isLoading = false;
        });
      }
    }
  }

  // ✨ 修复：接收局部的 BuildContext，确保画的线完美跟随手指，没有偏差
  void _onPanUpdate(DragUpdateDetails details, BuildContext localContext) {
    final box = localContext.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      userPoints.add(local);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      userPoints.add(null); 
    });
  }

  void _clearDrawing() {
    setState(() {
      userPoints = [];
      checked = false;
      coverage = 0.0;
    });
  }

  void _checkTracing() {
    // ✨ 如果画板还没渲染好，强制允许通过，防止卡死
    if (_canvasSize == null) {
      setState(() { checked = true; coverage = 0.0; });
      return;
    }

    final text = items[currentItem]['word'] as String;
    // ✨ 传入准确的画板尺寸进行分析
    final guidePoints = _GuideTextPainter(text: text, isLetterMode: isLetterMode).samplePoints(_canvasSize!);

    if (userPoints.where((p) => p != null).isEmpty || guidePoints.isEmpty) {
      setState(() {
        checked = true;
        coverage = 0.0;
      });
      return;
    }

    int covered = 0;
    final tolerance = isLetterMode ? 30.0 : 22.0;
    for (final gp in guidePoints) {
      final hit = userPoints.any((up) => up != null && (up - gp).distance < tolerance);
      if (hit) covered++;
    }

    final pct = covered / guidePoints.length;
    setState(() {
      checked = true;
      coverage = pct;
      if (pct >= 0.55) score++;
    });
  }

  void _nextItem() {
    if (currentItem < items.length - 1) {
      setState(() {
        currentItem++;
        userPoints = [];
        checked = false;
        coverage = 0.0;
      });
    } else {
      _showResult();
    }
  }

  void _showResult() {
    ProgressService.saveProgress(
      subject: 'writing',
      module: 'writing',
      ageGroup: widget.ageGroup,
      score: score,
      totalQuestions: items.length,
      kidId: widget.kidId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tracing Complete!',
            textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score / ${items.length}',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFFFAB40)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final starsEarned = score == items.length
                    ? 3
                    : score >= (items.length * 0.6).ceil() ? 2 : 1;
                return Icon(
                  Icons.star_rounded,
                  size: 40,
                  color: i < starsEarned ? const Color(0xFFFFC107) : const Color(0xFFE0E0E0),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              score == items.length
                  ? (isLetterMode ? 'Perfect letters!' : 'Perfect spelling!')
                  : score >= (items.length * 0.6).ceil()
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Menu', style: TextStyle(color: Colors.white)),
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFAB40))),
      );
    }

    final item = items[currentItem];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFFFFB7C5), shape: BoxShape.circle))),
          Positioned(bottom: -40, left: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFF80DEEA), shape: BoxShape.circle))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                      ),
                      const Spacer(),
                      Text('${currentItem + 1} / ${items.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF888888))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(items.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentItem ? const Color(0xFFFFAB40) : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (!isLetterMode) ...[
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14), 
                        child: WordImage(imageAsset: item['image'] as String),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    isLetterMode ? 'Trace the letter!' : 'Trace the word!',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF888888), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  
                  // ✨ 核心修复区：利用 LayoutBuilder 动态获取尺寸，防止任何因为尺寸导致的卡死
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8EF),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFFFE0B2), width: 2),
                          ),
                          // ✨ 引入 Builder 确保坐标 100% 对应到画布上
                          child: Builder(
                            builder: (localContext) {
                              return GestureDetector(
                                onPanUpdate: (details) => _onPanUpdate(details, localContext),
                                onPanEnd: _onPanEnd,
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _TracingPainter(
                                    text: item['word'] as String,
                                    userPoints: userPoints,
                                    isLetterMode: isLetterMode,
                                  ),
                                ),
                              );
                            }
                          ),
                        );
                      }
                    ),
                  ),
                  if (checked) ...[
                    const SizedBox(height: 12),
                    Text(
                      coverage >= 0.55
                          ? 'Nice tracing! ${(coverage * 100).round()}% covered'
                          : 'Try to follow the guide more closely (${(coverage * 100).round()}%)',
                      style: TextStyle(
                        color: coverage >= 0.55 ? const Color(0xFF4DD9C0) : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearDrawing,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFFFAB40)),
                          ),
                          child: const Text('Clear', style: TextStyle(color: Color(0xFFFFAB40), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: checked ? _nextItem : _checkTracing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAB40),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(checked ? 'Next' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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

class _TracingPainter extends CustomPainter {
  final String text;
  final List<Offset?> userPoints;
  final bool isLetterMode;

  _TracingPainter({required this.text, required this.userPoints, required this.isLetterMode});

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = isLetterMode
        ? (size.height * 0.6).clamp(80.0, 220.0)
        : (size.width / (text.length + 1)).clamp(36.0, 90.0);

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: isLetterMode ? 0 : 8,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLetterMode ? 3 : 2
        ..color = const Color(0xFFFFC987),
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width - 20);
    
    final offset = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );
    tp.paint(canvas, offset);

    final dotPaint = Paint()..color = const Color(0xFFFFD699);
    for (double x = offset.dx; x < offset.dx + tp.width; x += 14) {
      canvas.drawCircle(Offset(x, offset.dy + tp.height * 0.82), 1.8, dotPaint);
    }

    final strokePaint = Paint()
      ..color = const Color(0xFF4DD9C0)
      ..strokeWidth = isLetterMode ? 10 : 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < userPoints.length - 1; i++) {
      final p1 = userPoints[i];
      final p2 = userPoints[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter old) => true;
}

class _GuideTextPainter {
  final String text;
  final bool isLetterMode;
  _GuideTextPainter({required this.text, required this.isLetterMode});

  List<Offset> samplePoints(Size size) {
    final fontSize = isLetterMode
        ? (size.height * 0.6).clamp(80.0, 220.0)
        : (size.width / (text.length + 1)).clamp(36.0, 90.0);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: isLetterMode ? 0 : 8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width - 20);
    
    final offset = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );

    final points = <Offset>[];
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      // ✨ 宇宙无敌终极防御：如果不是英文字母也不是数字（遇到空格或连字符-），一律跳过，绝不生成追踪点！
      if (!RegExp(r'[A-Za-z0-9]').hasMatch(char)) {
        continue;
      }
      
      final boxes = tp.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1));
      for (final box in boxes) {
        for (double x = box.left; x < box.right; x += 6) {
          for (double y = box.top + (box.bottom - box.top) * 0.2; y < box.bottom - (box.bottom - box.top) * 0.2; y += 10) {
            points.add(Offset(x + offset.dx, y + offset.dy));
          }
        }
      }
    }
    return points;
  }
}