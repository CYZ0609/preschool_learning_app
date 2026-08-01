import 'package:cloud_firestore/cloud_firestore.dart';
import 'lesson_service.dart';

/// Loads the teacher-uploaded global item catalog (created via
/// AddItemScreen, stored in the `sandbox_items` Firestore collection) and
/// converts each doc into a [LessonWord] so it can be merged into the same
/// catalog the sandbox actually renders from.
///
/// Previously `sandbox_items` was written to but never read anywhere,
/// so toggling "Is Movable" (or anything else) on AddItemScreen had zero
/// effect in gameplay — this is the missing other half of that wiring.
class SandboxItemService {
  static final _items = FirebaseFirestore.instance.collection('sandbox_items');

  /// One-shot fetch of every teacher-added global item, as LessonWords.
  /// Call this alongside the built-in + per-lesson vocabulary and merge
  /// with [mergeCustomVocabulary] (or similar) before showing the catalog.
  static Future<List<LessonWord>> loadGlobalItems() async {
    final snap = await _items.get();
    final result = <LessonWord>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final itemId = (data['itemId'] as String? ?? '').trim();
      final imageUrl = data['imageUrl'] as String?;
      if (itemId.isEmpty || imageUrl == null || imageUrl.isEmpty) continue;
      final isSolid = data['isSolid'] as bool? ?? true;
      result.add(LessonWord(
        word: itemId.toUpperCase(),
        // WordImage already renders http(s) URLs directly, so the
        // Storage download URL can go straight into imageAsset.
        imageAsset: imageUrl,
        isMovable: data['isMovable'] as bool? ?? false,
        isPassable: !isSolid,
      ));
    }
    return result;
  }
}