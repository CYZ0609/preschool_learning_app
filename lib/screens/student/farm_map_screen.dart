import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/lesson_service.dart';

class FarmMapScreen extends StatefulWidget {
  final Lesson lesson;

  const FarmMapScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen> {
  final FlutterTts tts = FlutterTts();
  String? activeWord;
  String? pressedWord;
  bool bgFailed = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  static const List<Offset> _scatterPositions = [
    Offset(0.18, 0.30),
    Offset(0.72, 0.22),
    Offset(0.45, 0.42),
    Offset(0.15, 0.68),
    Offset(0.78, 0.62),
    Offset(0.50, 0.78),
  ];

  Offset _positionFor(LessonWord word, int index) {
    if (word.positionX != null && word.positionY != null) {
      return Offset(word.positionX!, word.positionY!);
    }
    return _scatterPositions[index % _scatterPositions.length];
  }

  Future<void> _onTapWord(LessonWord word) async {
    setState(() => activeWord = word.word);
    await tts.speak(word.word);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => activeWord = null);
  }

  Widget _textRevealFor(LessonWord word) {
    final age = widget.lesson.ageGroup;
    if (age == '6-7') {
      final startsWithVowel = 'AEIOU'.contains(word.word.isNotEmpty ? word.word.toUpperCase()[0] : '');
      return Text('I see a${startsWithVowel ? 'n' : ''} ${word.word}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white));
    }
    if (age == '5-6') {
      return Text(
        word.word.split('').join('  '),
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
      );
    }
    return Text(word.word,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 最底层永远是天空到草地的渐变色（用来填补手机/平板多出来的上下或左右空白边缘）
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF87CEEB), Color(0xFFA8D8A0), Color(0xFF7CB86D)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 2. 顶部导航栏 (返回按钮)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${widget.lesson.title} 🚜',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. 互动地图区域 (居中 + 固定比例)
              Expanded(
                child: Center(
                  // 核心魔法：AspectRatio！
                  // 假设你的农场图是横向的长方形，这里设为 4:3 或者 16:9
                  // 如果你的背景图偏正方形，你可以改成 aspectRatio: 1.0
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // <--- 根据你的 farm_bg.png 的实际形状微调这里！
                    child: Stack(
                      children: [
                        // 背景图片图层
                        Positioned.fill(
                          child: bgFailed 
                              ? const SizedBox() // 如果图片加载失败，直接透明，露出底层的渐变色
                              : Image.asset(
                                  'assets/images/farm_bg.png',
                                  // 因为外面有 AspectRatio 保护，这里的 fill 绝对不会变形！
                                  fit: BoxFit.fill, 
                                  onError: (error, stackTrace) {
                                    if (mounted) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) setState(() => bgFailed = true);
                                      });
                                    }
                                  },
                                ),
                        ),
                        // 动物图层
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(constraints.maxWidth, constraints.maxHeight);
                            return Stack(
                              children: List.generate(widget.lesson.words.length, (i) {
                                final word = widget.lesson.words[i];
                                final pos = _positionFor(word, i);
                                final isActive = activeWord == word.word;

                                return Positioned(
                                  left: pos.dx * size.width - 58,
                                  top: pos.dy * size.height - 58,
                                  child: GestureDetector(
                                    onTap: () => _onTapWord(word),
                                    onTapDown: (_) => setState(() => pressedWord = word.word),
                                    onTapUp: (_) => setState(() => pressedWord = null),
                                    onTapCancel: () => setState(() => pressedWord = null),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (isActive)
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                            child: _textRevealFor(word),
                                          ),
                                        AnimatedScale(
                                          scale: isActive ? 1.25 : (pressedWord == word.word ? 0.88 : 1.0),
                                          duration: Duration(milliseconds: isActive ? 300 : 100),
                                          curve: isActive ? Curves.elasticOut : Curves.easeOut,
                                          child: SizedBox(
                                            width: 116,
                                            height: 116,
                                            child: Image.asset(
                                              word.imageAsset,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.pets_rounded, size: 70, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}