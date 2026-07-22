import '../services/lesson_service.dart';
import 'asset_images.dart';

/// Word banks for free-play map exploration and the sandbox Learning
/// Panel (Listen -> Read -> Write -> Speak). Calibrated so word length
/// increases gradually with age tier — the panel requires spelling,
/// tracing, AND speaking each word, so a word that's fine for a quiz
/// multiple-choice can still be too hard here.
List<LessonWord> defaultMapWordsFor(String ageGroup) {
  List<String> words;
  int difficulty;
  switch (ageGroup) {
    case '4-5':
      // 3-4 letters only — Listen + Read steps only at this tier.
      words = ['cat', 'dog', 'cow', 'pig', 'fish', 'bird'];
      difficulty = 1;
      break;
    case '5-6':
      // 4-6 letters — moderate tier, guided reading + tracing + tolerant speech.
      words = ['tiger', 'rabbit', 'monkey', 'frog', 'zebra', 'fox'];
      difficulty = 2;
      break;
    case '6-7':
    default:
      // 6-8 letters — hardest tier (unguided reading, strict speech match),
      // but nothing longer than 8 letters to keep it achievable, not frustrating.
      words = ['elephant', 'giraffe', 'kangaroo', 'parrot', 'donkey', 'lizard'];
      difficulty = 3;
  }
  // Only keep ones that actually have a bundled asset image.
  final valid = words.where((w) => kAvailableAssetImages.contains(w)).toList();
  return valid
      .map((w) => LessonWord(word: w.toUpperCase(), imageAsset: assetPathFor(w), difficulty: difficulty))
      .toList();
}
