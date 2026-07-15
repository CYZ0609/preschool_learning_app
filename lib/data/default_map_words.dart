import '../services/lesson_service.dart';
import 'asset_images.dart';

/// Word banks for free-play map exploration (Farm/Savanna), used when a
/// student opens these games directly instead of via a teacher-assigned
/// lesson. Only words with a matching bundled image are used.
List<LessonWord> defaultMapWordsFor(String ageGroup) {
  List<String> words;
  switch (ageGroup) {
    case '4-5':
      words = ['cat', 'dog', 'cow', 'pig', 'fish', 'bird'];
      break;
    case '5-6':
      words = ['lion', 'tiger', 'rabbit', 'monkey', 'frog', 'elephant'];
      break;
    case '6-7':
    default:
      words = ['giraffe', 'zebra', 'kangaroo', 'crocodile', 'dolphin', 'parrot'];
  }
  // Only keep ones that actually have a bundled asset image.
  final valid = words.where((w) => kAvailableAssetImages.contains(w)).toList();
  return valid
      .map((w) => LessonWord(word: w.toUpperCase(), imageAsset: assetPathFor(w)))
      .toList();
}
