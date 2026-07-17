import 'package:flutter/material.dart';
import '../../writing_tracing_screen.dart';

/// Step 3 (5-6, 6-7 only): reuses the letter-tracing engine already built
/// and validated for the Writing subject (real shape-checking, not a fake
/// pass-any-touch). Pushes the tracing flow for this one word, then
/// reports completion back to the panel.
///
/// KNOWN SIMPLIFICATION: the spec calls for animated dotted directional
/// arrows on the guided (5-6) tier and a bare outline for unguided (6-7).
/// The existing tracing screen doesn't yet draw directional arrows — it
/// shows the same ghost-letter outline for both tiers. Reusing the tested
/// engine now; true arrow-guide overlays would be a follow-up visual pass.
class WritingStep extends StatefulWidget {
  final String word;
  final String ageGroup;
  final VoidCallback onComplete;

  const WritingStep({super.key, required this.word, required this.ageGroup, required this.onComplete});

  @override
  State<WritingStep> createState() => _WritingStepState();
}

class _WritingStepState extends State<WritingStep> {
  bool _launched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_launched) {
      _launched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
    }
  }

  Future<void> _launch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WritingTracingScreen(
          word: widget.word,
          ageGroup: widget.ageGroup,
          isLastWord: true, // single word here; "Done!" shown instead of "Next Word"
        ),
      ),
    );
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    // Brief placeholder shown for the instant before the tracing screen
    // is pushed on top.
    return const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB40)));
  }
}
