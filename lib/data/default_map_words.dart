import '../services/lesson_service.dart';
import 'asset_images.dart';

/// A tiny internal record describing one built-in word's dynamic behavior,
/// before it becomes a full [LessonWord]. Kept separate from LessonWord
/// itself so this file reads as a plain, easy-to-edit data table.
class _WordSpec {
  final String word;
  final bool isMovable;
  final bool isPassable;
  const _WordSpec(this.word, {this.isMovable = false, this.isPassable = true});
}

/// Word banks for free-play map exploration and the sandbox Learning
/// Panel (Listen -> Read -> Write -> Speak). Calibrated so word length
/// increases gradually with age tier — the panel requires spelling,
/// tracing, AND speaking each word, so a word that's fine for a quiz
/// multiple-choice can still be too hard here.
///
/// Each entry also carries its own isMovable/isPassable flags (see
/// LessonWord) — landscaping items like fences and rocks are marked as
/// solid obstacles (isPassable: false); plants are passable. Everything
/// else defaults to the harmless "static decoration" behavior
/// (isMovable: false, isPassable: true).
const Map<String, List<_WordSpec>> _tierSpecs = {
  '4-5': [
    // Animals wander the grid on their own once placed (isMovable: true).
    _WordSpec('cat', isMovable: true), _WordSpec('dog', isMovable: true),
    _WordSpec('cow', isMovable: true), _WordSpec('pig', isMovable: true),
    _WordSpec('fish', isMovable: true), _WordSpec('bird', isMovable: true),
    _WordSpec('sun'), _WordSpec('hat'),
    _WordSpec('ant', isMovable: true),
    // Basic landscaping/decorative words, tier 1 (short + simple):
    _WordSpec('tree', isPassable: true),
    _WordSpec('grass', isPassable: true),
    _WordSpec('rock', isPassable: false),
  ],
  '5-6': [
    _WordSpec('tiger', isMovable: true), _WordSpec('rabbit', isMovable: true),
    _WordSpec('monkey', isMovable: true), _WordSpec('frog', isMovable: true),
    _WordSpec('zebra', isMovable: true), _WordSpec('fox', isMovable: true),
    _WordSpec('lion', isMovable: true), _WordSpec('apple'),
    _WordSpec('chair'), _WordSpec('table'), _WordSpec('water'), _WordSpec('mango'),
    // Basic landscaping/decorative words, tier 2:
    _WordSpec('fence', isPassable: false),
    _WordSpec('flower', isPassable: true),
  ],
  '6-7': [
    _WordSpec('elephant', isMovable: true), _WordSpec('giraffe', isMovable: true),
    _WordSpec('kangaroo', isMovable: true), _WordSpec('parrot', isMovable: true),
    _WordSpec('donkey', isMovable: true), _WordSpec('lizard', isMovable: true),
    _WordSpec('dinosaur', isMovable: true),
    _WordSpec('umbrella'), _WordSpec('teacher'), _WordSpec('pencil'),
  ],
};

const List<String> _tierOrder = ['4-5', '5-6', '6-7'];

int _difficultyFor(String ageGroup) => _tierOrder.indexOf(ageGroup) + 1;

List<LessonWord> defaultMapWordsFor(String ageGroup) {
  final specs = _tierSpecs[ageGroup] ?? _tierSpecs['4-5']!;
  final difficulty = _difficultyFor(_tierSpecs.containsKey(ageGroup) ? ageGroup : '4-5');
  // Only keep ones that actually have a bundled asset image.
  final valid = specs.where((s) => kAvailableAssetImages.contains(s.word)).toList();
  return valid
      .map((s) => LessonWord(
            word: s.word.toUpperCase(),
            imageAsset: assetPathFor(s.word),
            difficulty: difficulty,
            isMovable: s.isMovable,
            isPassable: s.isPassable,
          ))
      .toList();
}

/// Every word from every tier EASIER than [ageGroup] — used to
/// auto-unlock younger tiers for older kids without needing to practice
/// them again. Does NOT include [ageGroup]'s own words; those still
/// unlock normally through the Learning Panel.
///
/// e.g. a 6-7 year old auto-unlocks everything from '4-5' and '5-6'.
/// A 5-6 year old auto-unlocks only '4-5'. A 4-5 year old auto-unlocks
/// nothing (there's no easier tier).
Set<String> autoUnlockedWordsFor(String ageGroup) {
  final myIndex = _tierOrder.indexOf(ageGroup);
  if (myIndex <= 0) return {}; // '4-5', or an unrecognized ageGroup — nothing to auto-unlock
  final result = <String>{};
  for (int i = 0; i < myIndex; i++) {
    result.addAll(defaultMapWordsFor(_tierOrder[i]).map((w) => w.word));
  }
  return result;
}

/// Merges the built-in tier vocabulary with teacher-added custom words
/// (from `Lesson.words`, which may come from a backend/Firestore and can
/// include any dynamic isMovable/isPassable config), de-duplicating by
/// word. Custom words win on conflict — a teacher can override a
/// built-in word's art/behavior by reusing the same word text.
///
/// This is the ONE place that should ever combine "built-in" + "custom"
/// vocabulary, so any future backend-driven source of words only needs
/// to plug in here.
List<LessonWord> mergeCustomVocabulary({
  required List<LessonWord> builtIn,
  required List<LessonWord> custom,
}) {
  final byWord = <String, LessonWord>{};
  for (final w in builtIn) {
    byWord[w.word] = w;
  }
  for (final w in custom) {
    byWord[w.word] = w; // custom overrides built-in on same word
  }
  return byWord.values.toList();
}