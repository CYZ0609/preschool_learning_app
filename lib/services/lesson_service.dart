import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A single flashcard word inside a lesson.
class LessonWord {
  final String word;
  final String imageAsset; // e.g. assets/images/cow.png ('' if none — use emoji instead)
  final String? emoji;     // fallback art when no real image asset exists yet
  final int difficulty;    // 1 = easiest ... higher = harder; used to sort inventory
  final double? positionX; // 0.0-1.0 fractional X on the map; null = auto-layout
  final double? positionY; // 0.0-1.0 fractional Y on the map; null = auto-layout

  // --- Dynamic physics/behavior config ---
  // These replace any hardcoded "these 3 words are obstacles" list. Any
  // word — built-in or teacher-added from the backend — carries its own
  // behavior, so pathfinding never needs to know specific word names.
  final bool isMovable;  // true = wanders the grid on its own once placed
  final bool isPassable; // true = other movers can walk straight through it;
                          // false = solid obstacle that blocks movement
  
  // ✨ 新增：地图网格尺寸
  final int? width;
  final int? height;

  // ✨ 新增：适用年龄标签
  final String? targetAge;

  LessonWord({
    required this.word,
    required this.imageAsset,
    this.emoji,
    this.difficulty = 1,
    this.positionX,
    this.positionY,
    this.isMovable = false,
    this.isPassable = true,
    this.width,
    this.height,
    // ✨ 新增：加到构造函数中
    this.targetAge,
  });

  Map<String, dynamic> toMap() => {
        'word': word,
        'imageAsset': imageAsset,
        'emoji': emoji,
        'difficulty': difficulty,
        'positionX': positionX,
        'positionY': positionY,
        'isMovable': isMovable,
        'isPassable': isPassable,
        'width': width,
        'height': height,
        // ✨ 新增：保存到数据库时带上适用年龄
        'targetAge': targetAge,
      };

  factory LessonWord.fromMap(Map<String, dynamic> map) => LessonWord(
        word: map['word'] ?? '',
        imageAsset: map['imageAsset'] ?? '',
        emoji: map['emoji'] as String?,
        difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
        positionX: (map['positionX'] as num?)?.toDouble(),
        positionY: (map['positionY'] as num?)?.toDouble(),
        isMovable: map['isMovable'] as bool? ?? false,
        isPassable: map['isPassable'] as bool? ?? true,
        width: map['width'] != null ? int.tryParse(map['width'].toString()) : null,
        height: map['height'] != null ? int.tryParse(map['height'].toString()) : null,
        // ✨ 新增：从数据库读取时解析适用年龄
        targetAge: map['targetAge'] as String?,
      );
}

// ... 剩下的 Lesson 类和 LessonService 类保持不变[cite: 2] ...