import 'package:flutter/material.dart';
import '../../services/lesson_service.dart';
import 'create_lesson_screen.dart';

class MyLessonsScreen extends StatelessWidget {
  const MyLessonsScreen({super.key});

  static const subjectColors = {
    'reading': Color(0xFF4DD9C0),
    'listening': Color(0xFFFFAB40),
    'speaking': Color(0xFFFF8FAB),
    'writing': Color(0xFFFFAB40),
    'arithmetic': Color(0xFFFF8FAB),
  };

  static const subjectIcons = {
    'reading': Icons.menu_book_rounded,
    'listening': Icons.hearing_rounded,
    'speaking': Icons.mic_rounded,
    'writing': Icons.edit_rounded,
    'arithmetic': Icons.calculate_rounded,
  };

  Future<void> _confirmDelete(BuildContext context, Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Lesson?'),
        content: Text('This will remove "${lesson.title}" permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LessonService.deleteLesson(lesson.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: const Text('My Lessons',
            style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF4DD9C0)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateLessonScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Lesson>>(
        stream: LessonService.myLessons(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4DD9C0)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final lessons = snapshot.data ?? [];
          if (lessons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 64, color: Color(0xFFCCCCCC)),
                    const SizedBox(height: 16),
                    const Text(
                      'No lessons yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a lesson to start teaching your students new words.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateLessonScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD9C0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text('Create Your First Lesson',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: lessons.length,
            itemBuilder: (context, i) {
              final lesson = lessons[i];
              final color = subjectColors[lesson.subject] ?? const Color(0xFF4DD9C0);
              final icon = subjectIcons[lesson.subject] ?? Icons.menu_book_rounded;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lesson.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333))),
                          const SizedBox(height: 4),
                          Text(
                            '${lesson.subject[0].toUpperCase()}${lesson.subject.substring(1)} · Age ${lesson.ageGroup} · ${lesson.words.length} words',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF888888)),
                      onPressed: () => _confirmDelete(context, lesson),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
