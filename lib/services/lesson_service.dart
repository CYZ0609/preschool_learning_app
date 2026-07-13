import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A single flashcard word inside a lesson.
class LessonWord {
  final String word;
  final String imageAsset; // e.g. assets/images/cow.png

  LessonWord({required this.word, required this.imageAsset});

  Map<String, dynamic> toMap() => {'word': word, 'imageAsset': imageAsset};

  factory LessonWord.fromMap(Map<String, dynamic> map) => LessonWord(
        word: map['word'] ?? '',
        imageAsset: map['imageAsset'] ?? '',
      );
}

/// A teacher-created lesson: a small set of words the student should be
/// taught (flashcard-style) before attempting the matching quiz.
class Lesson {
  final String id;
  final String teacherUid;
  final String title;
  final String subject; // reading / listening / speaking / writing / arithmetic
  final String ageGroup; // 4-5, 5-6, 6-7
  final List<LessonWord> words;
  final DateTime? createdAt;

  Lesson({
    required this.id,
    required this.teacherUid,
    required this.title,
    required this.subject,
    required this.ageGroup,
    required this.words,
    this.createdAt,
  });

  factory Lesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lesson(
      id: doc.id,
      teacherUid: data['teacherUid'] ?? '',
      title: data['title'] ?? 'Untitled Lesson',
      subject: data['subject'] ?? 'reading',
      ageGroup: data['ageGroup'] ?? '4-5',
      words: (data['words'] as List<dynamic>? ?? [])
          .map((w) => LessonWord.fromMap(Map<String, dynamic>.from(w)))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class LessonService {
  static final _lessons = FirebaseFirestore.instance.collection('lessons');

  /// Create a new lesson for the currently signed-in teacher.
  static Future<void> createLesson({
    required String title,
    required String subject,
    required String ageGroup,
    required List<LessonWord> words,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (words.isEmpty) throw Exception('Add at least one word');

    await _lessons.add({
      'teacherUid': user.uid,
      'title': title,
      'subject': subject,
      'ageGroup': ageGroup,
      'words': words.map((w) => w.toMap()).toList(),
      'createdAt': Timestamp.now(),
    });
  }

  /// All lessons created by the currently signed-in teacher.
  static Stream<List<Lesson>> myLessons() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return _lessons
        .where('teacherUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Lesson.fromDoc(d)).toList());
  }

  /// Lessons matching a subject + age group (used when assigning to a kid).
  static Future<List<Lesson>> lessonsFor({
    required String subject,
    required String ageGroup,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await _lessons
        .where('teacherUid', isEqualTo: user.uid)
        .where('subject', isEqualTo: subject)
        .where('ageGroup', isEqualTo: ageGroup)
        .get();
    return snap.docs.map((d) => Lesson.fromDoc(d)).toList();
  }

  static Future<Lesson?> getLesson(String lessonId) async {
    final doc = await _lessons.doc(lessonId).get();
    if (!doc.exists) return null;
    return Lesson.fromDoc(doc);
  }

  static Future<void> deleteLesson(String lessonId) =>
      _lessons.doc(lessonId).delete();
}
