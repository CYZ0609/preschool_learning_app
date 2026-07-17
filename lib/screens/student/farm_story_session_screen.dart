import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/lesson_service.dart';

/// A dedicated full-screen "Learn" session for exactly one word, pushed
/// when the child taps an animal on the map. Speaks the word, shows the
/// age-appropriate text reveal, and only returns to the map (with a
/// result of true) when the child explicitly taps "Complete!" — tapping
/// an animal never silently exits the map on its own.
class FarmStorySessionScreen extends StatefulWidget {
  final LessonWord word;
  final String ageGroup;

  const FarmStorySessionScreen({super.key, required this.word, required this.ageGroup});

  @override
  State<FarmStorySessionScreen> createState() => _FarmStorySessionScreenState();
}

class _FarmStorySessionScreenState extends State<FarmStorySessionScreen> {
  final FlutterTts tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    WidgetsBinding.instance.addPostFrameCallback((_) => tts.speak(widget.word.word));
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Widget _textRevealFor(LessonWord word) {
    final age = widget.ageGroup;
    if (age == '6-7') {
      final startsWithVowel = 'AEIOU'.contains(word.word.isNotEmpty ? word.word[0] : '');
      return Text('I see a${startsWithVowel ? 'n' : ''} ${word.word}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF333333)));
    }
    if (age == '5-6') {
      return Text(
        word.word.split('').join('  '),
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1A8C7A), letterSpacing: 2),
      );
    }
    return Text(word.word,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF1A8C7A)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0FDF4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false), // exit without completing
                  child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => tts.speak(widget.word.word),
                        child: Container(
                          width: 220,
                          height: 220,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Image.asset(widget.word.imageAsset, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () => tts.speak(widget.word.word),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _textRevealFor(widget.word),
                            const SizedBox(width: 10),
                            const Icon(Icons.volume_up_rounded, color: Color(0xFF4DD9C0), size: 28),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Tap to hear it again', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true), // completed — award star, return to map
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4DD9C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Complete! ✅',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
