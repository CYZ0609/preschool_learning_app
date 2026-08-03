import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:ui' as ui;

class WritingTracingScreen extends StatefulWidget {
  final String word;
  final String ageGroup;
  final bool isLastWord;
  final VoidCallback? onNext;

  const WritingTracingScreen({
    super.key,
    required this.word,
    required this.ageGroup,
    this.isLastWord = true,
    this.onNext,
  });

  @override
  State<WritingTracingScreen> createState() => _WritingTracingScreenState();
}

class _WritingTracingScreenState extends State<WritingTracingScreen> {
  final FlutterTts tts = FlutterTts();
  int currentLetterIndex = 0;
  List<List<Offset>> strokes = [];
  List<Offset> currentStroke = [];
  bool letterCompleted = false; 
  bool isChecking = false;      
  String? traceError;           

  // ✨ 1. 新增安全尺寸捕获
  Size? _canvasSize;

  // ✨ 2. 检查字符是否需要描红（只允许英文字母和数字）
  bool _isTraceable(String char) {
    return RegExp(r'[A-Za-z0-9]').hasMatch(char);
  }

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    tts.setSpeechRate(0.4);
    
    // ✨ 3. 初始化时，如果开头遇到空格或特殊符号，自动跳过
    _skipUntraceable();
    
    if (currentLetterIndex < widget.word.length) {
      _speakWord();
    }
  }

  // 自动循环跳过不需要描红的字符
  void _skipUntraceable() {
    while (currentLetterIndex < widget.word.length && !_isTraceable(widget.word[currentLetterIndex])) {
      currentLetterIndex++;
    }
    // 如果整个词都是空格/特殊符号（极端边缘情况），直接通关
    if (currentLetterIndex >= widget.word.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCompleteDialog());
    }
  }

  Future<void> _speakWord() async {
    await tts.speak(widget.word);
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _speakLetter(String letter) async {
    await tts.speak(letter);
  }

  Future<Map<String, dynamic>> _isTraceAccurate(String letter) async {
    // ✨ 4. 采用更安全的 Size 获取方式，防止卡死
    final size = _canvasSize ?? const Size(300, 300);
    if (size.width < 10 || size.height < 10) {
      return {'pass': true, 'reason': 'layout not ready'};
    }

    const gridSize = 40;
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(fontSize: 200, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    final image = await recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return {'pass': true, 'reason': 'no image data'};
    final pixels = byteData.buffer.asUint8List();
    final imgW = image.width;

    final allPoints = [...strokes.expand((s) => s), ...currentStroke];

    bool isLetterPixel(int px, int py) {
      if (px < 0 || py < 0 || px >= image.width || py >= image.height) return false;
      final idx = (py * imgW + px) * 4;
      return pixels[idx + 3] > 100; 
    }

    final targetGrid = List.generate(gridSize, (_) => List.filled(gridSize, false));
    int inkMinGX = gridSize, inkMaxGX = -1, inkMinGY = gridSize, inkMaxGY = -1;
    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final px = ((gx + 0.5) * cellW).round();
        final py = ((gy + 0.5) * cellH).round();
        final isInk = isLetterPixel(px, py);
        targetGrid[gy][gx] = isInk;
        if (isInk) {
          if (gx < inkMinGX) inkMinGX = gx;
          if (gx > inkMaxGX) inkMaxGX = gx;
          if (gy < inkMinGY) inkMinGY = gy;
          if (gy > inkMaxGY) inkMaxGY = gy;
        }
      }
    }

    final inkWidth = inkMaxGX >= inkMinGX ? (inkMaxGX - inkMinGX + 1) * cellW : size.width;
    final inkHeight = inkMaxGY >= inkMinGY ? (inkMaxGY - inkMinGY + 1) * cellH : size.height;

    final dilatedTarget = List.generate(gridSize, (_) => List.filled(gridSize, false));
    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        if (!targetGrid[gy][gx]) continue;
        for (int dx = -2; dx <= 2; dx++) {
          for (int dy = -2; dy <= 2; dy++) {
            final nx = gx + dx, ny = gy + dy;
            if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
              dilatedTarget[ny][nx] = true;
            }
          }
        }
      }
    }

    final drawnGrid = List.generate(gridSize, (_) => List.filled(gridSize, false));

    if (allPoints.length < 25) {
      return {'pass': false, 'reason': 'too few points', 'points': allPoints.length};
    }

    double minX = size.width, maxX = 0, minY = size.height, maxY = 0;
    for (final p in allPoints) {
      final gx = (p.dx / cellW).floor().clamp(0, gridSize - 1);
      final gy = (p.dy / cellH).floor().clamp(0, gridSize - 1);
      drawnGrid[gy][gx] = true;
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final dilatedDrawn = List.generate(gridSize, (_) => List.filled(gridSize, false));
    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        if (!drawnGrid[gy][gx]) continue;
        for (int dx = -3; dx <= 3; dx++) {
          for (int dy = -3; dy <= 3; dy++) {
            final nx = gx + dx, ny = gy + dy;
            if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
              dilatedDrawn[ny][nx] = true;
            }
          }
        }
      }
    }

    final drawnW = maxX - minX;
    final drawnH = maxY - minY;
    
    final wRatio = inkWidth > 0 ? (drawnW / inkWidth).clamp(0.0, 3.0) : 1.0;
    final hRatio = inkHeight > 0 ? (drawnH / inkHeight).clamp(0.0, 3.0) : 1.0;
    
    final isNarrowLetter = ['I', 'L', 'J', 'T', 'i', 'l', 'j', 't'].contains(letter);
    final double minWRatio = isNarrowLetter ? 0.10 : 0.35;

    if (wRatio < minWRatio || hRatio < 0.35) {
      return {
        'pass': false,
        'reason': 'too small/cramped',
        'wRatio': wRatio.toStringAsFixed(2),
        'hRatio': hRatio.toStringAsFixed(2),
      };
    }

    int targetCount = 0, drawnCount = 0;
    int coverageHits = 0; 
    int precisionHits = 0; 
    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        if (targetGrid[gy][gx]) {
          targetCount++;
          if (dilatedDrawn[gy][gx]) coverageHits++;
        }
        if (drawnGrid[gy][gx]) {
          drawnCount++;
          if (dilatedTarget[gy][gx]) precisionHits++;
        }
      }
    }

    if (targetCount == 0) return {'pass': true, 'reason': 'empty target'};
    final coverage = coverageHits / targetCount;
    final precision = drawnCount == 0 ? 0.0 : precisionHits / drawnCount;

    final pass = coverage >= 0.5 && precision >= 0.4;
    return {
      'pass': pass,
      'reason': pass ? 'ok' : 'low coverage/precision',
      'coverage': (coverage * 100).toStringAsFixed(0),
      'precision': (precision * 100).toStringAsFixed(0),
      'points': allPoints.length,
    };
  }

  Future<void> _attemptNext() async {
    if (!letterCompleted || isChecking) return;
    setState(() {
      isChecking = true;
      traceError = null;
    });
    final result = await _isTraceAccurate(widget.word[currentLetterIndex]);
    if (!mounted) return;
    final pass = result['pass'] == true;
    if (pass) {
      setState(() => isChecking = false);
      _nextLetter();
    } else {
      final details = result.entries
          .where((e) => e.key != 'pass')
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      setState(() {
        isChecking = false;
        traceError = 'Try again ✏️  ($details)';
      });
    }
  }

  void _nextLetter() {
    // ✨ 5. 核心修复：查找下一个“有效”的字母
    int nextIndex = currentLetterIndex + 1;
    while (nextIndex < widget.word.length && !_isTraceable(widget.word[nextIndex])) {
      nextIndex++;
    }

    if (nextIndex < widget.word.length) {
      setState(() {
        currentLetterIndex = nextIndex;
        strokes = [];
        currentStroke = [];
        letterCompleted = false;
        traceError = null;
      });
      _speakLetter(widget.word[currentLetterIndex]);
    } else {
      setState(() {
        currentLetterIndex = widget.word.length; // 标记全部完成
      });
      _showCompleteDialog();
    }
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Great job! ✅',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'You wrote "${widget.word}" correctly!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                if (widget.onNext != null) {
                  widget.onNext!();
                } else {
                  Navigator.pop(context); 
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFAB40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.onNext == null
                    ? 'Done!'
                    : (widget.isLastWord ? 'Finish! 🎉' : 'Next Word →'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 如果意外超出边界，安全防御
    if (currentLetterIndex >= widget.word.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentLetter = widget.word[currentLetterIndex];

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(widget.word.length, (i) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= currentLetterIndex
                                ? const Color(0xFFFFAB40)
                                : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  
                  // ✨ 6. 单词排版视觉修复：遇到空格生成透明间距，遇到特殊字符只显示文字无背景
                  Center(
                    child: GestureDetector(
                      onTap: _speakWord,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8.0, 
                        children: [
                          ...List.generate(widget.word.length, (i) {
                            final char = widget.word[i];
                            final isTraceable = _isTraceable(char);

                            if (!isTraceable) {
                              return char == ' ' 
                                ? const SizedBox(width: 16) 
                                : Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Text(
                                      char,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                  );
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: i == currentLetterIndex
                                    ? const Color(0xFFFFAB40)
                                    : i < currentLetterIndex
                                        ? const Color(0xFF4DD9C0)
                                        : const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: i <= currentLetterIndex
                                      ? Colors.white
                                      : const Color(0xFF888888),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          const Icon(Icons.volume_up_rounded, color: Color(0xFFFFAB40)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Trace the letter "$currentLetter"',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // ✨ 7. 应用 LayoutBuilder 防止底层 RenderBox 获取失败卡死
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9F0),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFFFAB40).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    currentLetter,
                                    style: TextStyle(
                                      fontSize: 200,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFFAB40).withOpacity(0.15),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onPanStart: (details) {
                                    setState(() {
                                      currentStroke = [details.localPosition];
                                      traceError = null;
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    setState(() {
                                      currentStroke.add(details.localPosition);
                                    });
                                  },
                                  onPanEnd: (details) {
                                    setState(() {
                                      strokes.add(List.from(currentStroke));
                                      currentStroke = [];
                                      letterCompleted = true;
                                    });
                                  },
                                  child: CustomPaint(
                                    painter: _TracingPainter(
                                      strokes: strokes,
                                      currentStroke: currentStroke,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (traceError != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orangeAccent, width: 1.5),
                      ),
                      child: Text(
                        traceError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE07800),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isChecking
                              ? null
                              : () {
                                  setState(() {
                                    strokes = [];
                                    currentStroke = [];
                                    letterCompleted = false;
                                    traceError = null;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFAB40)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Clear',
                              style: TextStyle(
                                  color: Color(0xFFFFAB40),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (letterCompleted && !isChecking) ? _attemptNext : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAB40),
                            disabledBackgroundColor: const Color(0xFFEEEEEE),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isChecking
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  currentLetterIndex < widget.word.length - 1
                                      ? 'Next Letter →'
                                      : 'Done! ✅',
                                  style: TextStyle(
                                    color: letterCompleted
                                        ? Colors.white
                                        : const Color(0xFF888888),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _TracingPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF8FAB)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}