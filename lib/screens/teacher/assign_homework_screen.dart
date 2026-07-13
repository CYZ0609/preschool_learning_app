import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/lesson_service.dart';

class AssignHomeworkScreen extends StatefulWidget {
  const AssignHomeworkScreen({super.key});

  @override
  State<AssignHomeworkScreen> createState() => _AssignHomeworkScreenState();
}

class _AssignHomeworkScreenState extends State<AssignHomeworkScreen> {
  List<Map<String, dynamic>> allKids = [];
  String? selectedKidId;
  String? selectedKidName;
  String selectedSubject = 'listening';
  DateTime? selectedDueDate;
  bool isLoading = true;
  bool isSubmitting = false;

  List<Lesson> matchingLessons = [];
  String? selectedLessonId; // null = no lesson attached, just a plain quiz

  final subjects = [
    {'value': 'listening', 'label': 'Listening Game', 'icon': Icons.hearing_rounded},
    {'value': 'speaking', 'label': 'Speaking Game', 'icon': Icons.mic_rounded},
    {'value': 'reading', 'label': 'Reading Game', 'icon': Icons.menu_book_rounded},
    {'value': 'writing', 'label': 'Writing Game', 'icon': Icons.edit_rounded},
    {'value': 'arithmetic', 'label': 'Arithmetic Game', 'icon': Icons.calculate_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllKids();
  }

  Future<void> _loadAllKids() async {
    try {
      final List<Map<String, dynamic>> kids = [];
      final parents = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();

      for (var parent in parents.docs) {
        final children = await FirebaseFirestore.instance
            .collection('users')
            .doc(parent.id)
            .collection('children')
            .get();

        for (var child in children.docs) {
          kids.add({
            'id': child.id,
            'parentId': parent.id,
            'name': child.data()['name'] ?? 'Unknown',
            'ageGroup': child.data()['ageGroup'] ?? '4-5',
          });
        }
      }

      setState(() {
        allKids = kids;
        if (kids.isNotEmpty) {
          selectedKidId = kids[0]['id'];
          selectedKidName = kids[0]['name'];
        }
        isLoading = false;
      });
      _refreshLessons();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String get _selectedKidAgeGroup {
    final kid = allKids.firstWhere(
      (k) => k['id'] == selectedKidId,
      orElse: () => {'ageGroup': '4-5'},
    );
    return kid['ageGroup'] as String;
  }

  Future<void> _refreshLessons() async {
    if (selectedKidId == null) return;
    final lessons = await LessonService.lessonsFor(
      subject: selectedSubject,
      ageGroup: _selectedKidAgeGroup,
    );
    setState(() {
      matchingLessons = lessons;
      // Keep the previous selection only if it's still a valid match
      if (selectedLessonId != null &&
          !lessons.any((l) => l.id == selectedLessonId)) {
        selectedLessonId = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF4DD9C0)),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => selectedDueDate = date);
  }

  Future<void> _assignHomework() async {
    if (selectedKidId == null || selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a student and due date'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('assignments').add({
        'teacherUid': user?.uid,
        'kidId': selectedKidId,
        'kidName': selectedKidName,
        'subject': selectedSubject,
        'lessonId': selectedLessonId, // null = no teaching step, quiz only
        'dueDate': selectedDueDate!.toIso8601String().split('T')[0],
        'status': 'pending',
        'createdAt': DateTime.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Homework assigned successfully! ✅'),
            backgroundColor: Color(0xFF4DD9C0)),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }

    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: const Text('Assign Homework',
            style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4DD9C0)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select Student
                  const Text('Select Student',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 8),
                  allKids.isEmpty
                      ? const Text('No students found',
                          style: TextStyle(color: Color(0xFF888888)))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0FDF4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedKidId,
                              isExpanded: true,
                              items: allKids.map((kid) {
                                return DropdownMenuItem<String>(
                                  value: kid['id'],
                                  child: Text('${kid['name']} (Age ${kid['ageGroup']})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedKidId = val;
                                  selectedKidName = allKids
                                      .firstWhere((k) => k['id'] == val)['name'];
                                });
                                _refreshLessons();
                              },
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Select Subject
                  const Text('Select Subject',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 12),
                  ...subjects.map((subject) {
                    final isSelected = selectedSubject == subject['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedSubject = subject['value'] as String);
                        _refreshLessons();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4DD9C0).withOpacity(0.15)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4DD9C0)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(subject['icon'] as IconData,
                                color: isSelected
                                    ? const Color(0xFF4DD9C0)
                                    : const Color(0xFF888888)),
                            const SizedBox(width: 12),
                            Text(subject['label'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFF4DD9C0)
                                      : const Color(0xFF333333),
                                )),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF4DD9C0)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Attach a Lesson (optional) — kid learns these words before the quiz
                  const Text('Teach First? (optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 4),
                  const Text(
                    'Attach one of your lessons so the student learns the words before the quiz.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 12),
                  if (matchingLessons.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'No lessons yet for this subject & age group. You can still assign a plain quiz below, or create a lesson first from "My Lessons".',
                        style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                      ),
                    )
                  else
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => selectedLessonId = null),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedLessonId == null
                                  ? const Color(0xFF888888).withOpacity(0.12)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedLessonId == null ? const Color(0xFF888888) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.quiz_rounded, color: Color(0xFF888888)),
                                const SizedBox(width: 12),
                                const Text('No lesson — quiz only',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                                const Spacer(),
                                if (selectedLessonId == null)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF888888)),
                              ],
                            ),
                          ),
                        ),
                        ...matchingLessons.map((lesson) {
                          final isSelected = selectedLessonId == lesson.id;
                          return GestureDetector(
                            onTap: () => setState(() => selectedLessonId = lesson.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF80DEEA).withOpacity(0.15)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF80DEEA) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.school_rounded, color: Color(0xFF4DD9C0)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(lesson.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                                        Text('${lesson.words.length} words',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF4DD9C0)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Select Due Date
                  const Text('Due Date',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0FDF4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: Color(0xFF4DD9C0)),
                          const SizedBox(width: 12),
                          Text(
                            selectedDueDate == null
                                ? 'Select due date'
                                : '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}',
                            style: TextStyle(
                              color: selectedDueDate == null
                                  ? const Color(0xFF888888)
                                  : const Color(0xFF333333),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Assign Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : _assignHomework,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD9C0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Assign Homework 📋',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}