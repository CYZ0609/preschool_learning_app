import 'package:flutter/material.dart';
import '../../../../services/lesson_service.dart';
import 'listening_step.dart';
import 'reading_step.dart';
import 'writing_step.dart';
import 'speaking_step.dart';

enum LearningStep { listening, reading, writing, speaking }

List<LearningStep> _stepsFor(String ageGroup) {
  if (ageGroup == '4-5') {
    // "Only 2 steps. Speaking and Writing are skipped entirely to prevent
    // toddler frustration."
    return [LearningStep.listening, LearningStep.reading];
  }
  return [LearningStep.listening, LearningStep.reading, LearningStep.writing, LearningStep.speaking];
}

/// Section 5: the Universal Learning Panel. Shown full-screen when a
/// locked item is tapped in the Biome Sandbox trunk. Steps the child
/// through the age-adaptive module sequence. [onFinished] is the hook
/// into Phase 4 (the unlock finale — not yet built).
class UniversalLearningPanel extends StatefulWidget {
  final LessonWord word;
  final String ageGroup;
  final VoidCallback onFinished;

  const UniversalLearningPanel({
    super.key,
    required this.word,
    required this.ageGroup,
    required this.onFinished,
  });

  @override
  State<UniversalLearningPanel> createState() => _UniversalLearningPanelState();
}

class _UniversalLearningPanelState extends State<UniversalLearningPanel> {
  late final List<LearningStep> steps;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    steps = _stepsFor(widget.ageGroup);
  }

  void _advance() {
    if (currentIndex < steps.length - 1) {
      setState(() => currentIndex++);
    } else {
      widget.onFinished();
    }
  }

  Widget _buildCurrentStep() {
    switch (steps[currentIndex]) {
      case LearningStep.listening:
        return ListeningStep(key: ValueKey(currentIndex), word: widget.word.word, onComplete: _advance);
      case LearningStep.reading:
        return ReadingStep(key: ValueKey(currentIndex), word: widget.word.word, ageGroup: widget.ageGroup, onComplete: _advance);
      case LearningStep.writing:
        return WritingStep(key: ValueKey(currentIndex), word: widget.word.word, ageGroup: widget.ageGroup, onComplete: _advance);
      case LearningStep.speaking:
        return SpeakingStep(key: ValueKey(currentIndex), word: widget.word.word, ageGroup: widget.ageGroup, onComplete: _advance);
    }
  }

  String _stepLabel(LearningStep step) {
    switch (step) {
      case LearningStep.listening: return 'Listen';
      case LearningStep.reading: return 'Read';
      case LearningStep.writing: return 'Write';
      case LearningStep.speaking: return 'Speak';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF888888)),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 44, height: 44,
                    child: Image.asset(widget.word.imageAsset, fit: BoxFit.contain),
                  ),
                  const Spacer(),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(steps.length, (i) {
                  final isDone = i < currentIndex;
                  final isCurrent = i == currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone || isCurrent ? const Color(0xFF4DD9C0) : const Color(0xFFEEEEEE),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_stepLabel(steps[i]),
                            style: TextStyle(fontSize: 10, color: isCurrent ? const Color(0xFF4DD9C0) : const Color(0xFFAAAAAA))),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildCurrentStep()),
            ],
          ),
        ),
      ),
    );
  }
}
