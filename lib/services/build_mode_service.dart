import 'package:cloud_firestore/cloud_firestore.dart';

class PlacedItem {
  final String itemId; // matches a word/unlocked item
  final double gridX, gridY;
  PlacedItem({required this.itemId, required this.gridX, required this.gridY});

  Map<String, dynamic> toMap() => {'itemId': itemId, 'gridX': gridX, 'gridY': gridY};
  factory PlacedItem.fromMap(Map<String, dynamic> map) => PlacedItem(
        itemId: map['itemId'] ?? '',
        gridX: (map['gridX'] as num?)?.toDouble() ?? 0,
        gridY: (map['gridY'] as num?)?.toDouble() ?? 0,
      );
}

/// Persists Build Mode item placements per kid+biome.
class BuildModeService {
  static DocumentReference<Map<String, dynamic>> _doc(String kidId, String biomeName) =>
      FirebaseFirestore.instance.collection('sandboxPlacements').doc('${kidId}_$biomeName');

  static Future<List<PlacedItem>> loadPlacements(String kidId, String biomeName) async {
    final doc = await _doc(kidId, biomeName).get();
    if (!doc.exists) return [];
    final items = (doc.data()?['items'] as List<dynamic>? ?? []);
    return items.map((i) => PlacedItem.fromMap(Map<String, dynamic>.from(i))).toList();
  }

  static Future<void> savePlacements(String kidId, String biomeName, List<PlacedItem> items) async {
    await _doc(kidId, biomeName).set({
      'items': items.map((i) => i.toMap()).toList(),
    });
  }
}
