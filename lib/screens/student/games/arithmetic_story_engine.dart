import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads a teacher-authored `mathScript` (e.g. [10, -7, 2]) and renders it as
/// a live scene: positive steps spawn N identical assets one at a time
/// (tapping each plays its running count aloud); negative steps make N
/// existing assets slide/fade away. No numbers or operators are shown to
/// the child — only the objects appearing and disappearing.
class ArithmeticStoryEngine extends StatefulWidget {
  final List<int> mathScript;
  final String assetImageUrl;   // teacher-uploaded PNG (network) if provided
  final String assetImageAsset; // bundled fallback, e.g. "assets/images/cow.png"
  final String objectName;      // spoken name, e.g. "camel"
  final VoidCallback onComplete;

  const ArithmeticStoryEngine({
    super.key,
    required this.mathScript,
    required this.assetImageUrl,
    required this.assetImageAsset,
    required this.objectName,
    required this.onComplete,
  });

  @override
  State<ArithmeticStoryEngine> createState() => _ArithmeticStoryEngineState();
}

class _SceneItem {
  final Key key = UniqueKey();
  final Offset position;
  bool leaving = false;
  _SceneItem(this.position);
}

class _ArithmeticStoryEngineState extends State<ArithmeticStoryEngine> {
  final FlutterTts tts = FlutterTts();
  final List<_SceneItem> items = [];
  int scriptIndex = 0;
  bool isAnimating = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    WidgetsBinding.instance.addPostFrameCallback((_) => _runNextStep());
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Offset _randomPosition() {
    // Simple scattered layout within the visible scene area.
    final i = items.length;
    final col = i % 4;
    final row = i ~/ 4;
    return Offset(0.12 + col * 0.22, 0.15 + row * 0.22);
  }

  Future<void> _runNextStep() async {
    if (scriptIndex >= widget.mathScript.length) {
      await tts.speak('${items.length} ${widget.objectName}${items.length == 1 ? '' : 's'}');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) widget.onComplete();
      return;
    }

    final delta = widget.mathScript[scriptIndex];
    setState(() => isAnimating = true);

    if (delta > 0) {
      for (int i = 0; i < delta; i++) {
        if (!mounted) return;
        setState(() => items.add(_SceneItem(_randomPosition())));
        await tts.speak('${items.length}');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } else if (delta < 0) {
      final removeCount = delta.abs().clamp(0, items.length);
      for (int i = 0; i < removeCount; i++) {
        if (!mounted || items.isEmpty) break;
        setState(() => items.last.leaving = true);
        await Future.delayed(const Duration(milliseconds: 350));
        setState(() => items.removeLast());
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    scriptIndex++;
    if (mounted) setState(() => isAnimating = false);
    await Future.delayed(const Duration(milliseconds: 400));
    _runNextStep();
  }

  void _onTapItem(int displayIndex) {
    if (isAnimating) return;
    tts.speak('${displayIndex + 1}');
  }

  Widget _buildAssetImage() {
    if (widget.assetImageUrl.isNotEmpty) {
      return Image.network(
        widget.assetImageUrl,
        fit: BoxFit.contain,
        // Falls back to the bundled asset if the teacher's URL is broken/unreachable.
        errorBuilder: (_, __, ___) => Image.asset(widget.assetImageAsset, fit: BoxFit.contain),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
      );
    }
    return Image.asset(widget.assetImageAsset, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: const Color(0xFFE0FDF4),
            child: Stack(
              children: [
                for (int i = 0; i < items.length; i++)
                  AnimatedPositioned(
                    key: items[i].key,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: items[i].position.dx * size.width,
                    top: items[i].position.dy * size.height,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: items[i].leaving ? 0 : 1,
                      child: GestureDetector(
                        onTap: () => _onTapItem(i),
                        child: SizedBox(width: 70, height: 70, child: _buildAssetImage()),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Text('${items.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
