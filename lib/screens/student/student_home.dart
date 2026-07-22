import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../home_screen.dart';
import 'listening_game_screen.dart';
import 'speaking_game_screen.dart';
import 'reading_game_screen.dart';
import 'arithmetic_game_screen.dart';
import 'writing_tracing_screen.dart';
import 'teach_screen.dart';
import 'sandbox/world_map_screen.dart';
import 'sandbox/flame_world_map_screen.dart';
import 'sandbox/biome_sandbox_screen.dart';
import 'sandbox/learning_panel/universal_learning_panel.dart';
import 'sandbox/unlock_finale_screen.dart';
import '../../services/screen_time_service.dart';
import '../../services/lesson_service.dart';
import '../../services/progress_service.dart';
import '../../data/default_map_words.dart';

class StudentHome extends StatefulWidget {
  final String kidName;
  final String ageGroup;
  final String kidId;
  final String parentId;

  const StudentHome({
    super.key,
    required this.kidName,
    required this.ageGroup,
    required this.kidId,
    required this.parentId,
  });

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> with WidgetsBindingObserver {
  DateTime? _startTime;
  Timer? _checkTimer;
  List<Map<String, dynamic>> allKids = [];
  bool isLoading = true;
  List<Map<String, dynamic>> pendingAssignments = [];
  String? assignmentDebugInfo; // TEMPORARY: shown on-screen to debug why assignments aren't appearing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkScreenTimeLimit();
    });
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assignments')
          .where('kidId', isEqualTo: widget.kidId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (!mounted) return;
      setState(() {
        pendingAssignments = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        assignmentDebugInfo =
            'Query OK. kidId="${widget.kidId}" → found ${snap.docs.length} pending assignment(s).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assignmentDebugInfo = 'Query FAILED: $e';
      });
    }
  }

  @override
  void dispose() {
    _saveScreenTime();
    _checkTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadAllKids() async {
    try {
      final List<Map<String, dynamic>> kids = [];
      final parents = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get()
          .timeout(const Duration(seconds: 10));

      for (var parent in parents.docs) {
        final children = await FirebaseFirestore.instance
            .collection('users')
            .doc(parent.id)
            .collection('children')
            .get()
            .timeout(const Duration(seconds: 10));

        for (var child in children.docs) {
          kids.add({
            'id': child.id,
            'parentId': parent.id,
            'name': child.data()['name'] ?? 'Unknown',
            'ageGroup': child.data()['ageGroup'] ?? '4-5',
          });
        }
      }

      if (mounted) {
        setState(() {
          allKids = kids;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveScreenTime() async {
    if (_startTime == null) return;
    final minutes = DateTime.now().difference(_startTime!).inMinutes;
    if (minutes > 0) {
      await ScreenTimeService.updateScreenTime(minutes, widget.kidId);
    }
    _startTime = null;
  }

  Future<void> _checkScreenTimeLimit() async {
    // Logic for checking screen time limit
    final data = await ScreenTimeService.getTodayScreenTime(widget.kidId);
    final total = (data['totalMinutes'] ?? 0) as int;
    final limit = (data['limitMinutes'] ?? 30) as int;
    
    final currentSessionMinutes = _startTime == null
        ? 0
        : DateTime.now().difference(_startTime!).inMinutes;

    if (total + currentSessionMinutes >= limit) {
      // Show Dialog logic here if needed
    }
  }

  Future<void> _markAssignmentDone(String assignmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('assignments')
          .doc(assignmentId)
          .update({'status': 'completed'});
    } catch (_) {}
    if (mounted) {
      setState(() {
        pendingAssignments.removeWhere((a) => a['id'] == assignmentId);
      });
    }
  }

  Future<void> _startAssignment(Map<String, dynamic> assignment) async {
    final subject = assignment['subject'] as String? ?? 'reading';
    final lessonId = assignment['lessonId'] as String?;

    if (lessonId == null) {
      await _markAssignmentDone(assignment['id']);
      if (mounted) _navigateToGame(context, subject);
      return;
    }

    final lesson = await LessonService.getLesson(lessonId);
    if (!mounted) return;
    if (lesson == null || lesson.words.isEmpty) {
      // Lesson was deleted or is empty — just fall back to the quiz.
      await _markAssignmentDone(assignment['id']);
      if (mounted) _navigateToGame(context, subject);
      return;
    }

    if (lesson.subject == 'reading' || lesson.subject == 'listening') {
      _launchSandbox(lesson, onAllDone: () {
        _markAssignmentDone(assignment['id']);
        _navigateToGame(context, subject);
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeachScreen(
          lesson: lesson,
          onFinished: () {
            Navigator.pop(context); // close TeachScreen
            _markAssignmentDone(assignment['id']);
            _navigateToGame(context, subject);
          },
        ),
      ),
    );
  }

  // Unified entry point into the sandbox engine (World Map -> Biome
  // Sandbox -> Learning Panel -> Unlock Finale) for a given lesson. Used
  // both by teacher-assigned lessons and free-play. [onAllDone] fires once
  // the child returns to Student Home (not after every single word).
  void _launchSandbox(Lesson lesson, {VoidCallback? onAllDone}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlameWorldMapScreen(
          onEnterBiome: (biome) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BiomeSandboxScreen(
                  biome: biome,
                  lesson: lesson,
                  kidId: widget.kidId,
                  onOpenWord: (word) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UniversalLearningPanel(
                          word: word,
                          ageGroup: widget.ageGroup,
                          onFinished: () {
                            Navigator.pop(context); // close panel
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UnlockFinaleScreen(
                                  word: word,
                                  kidId: widget.kidId,
                                  onDone: () => Navigator.pop(context), // close finale, back to sandbox
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ).then((_) => onAllDone?.call());
  }

  // Lets a student open the sandbox on their own with a default word bank,
  // without needing a teacher-assigned lesson first.
  void _openFreePlaySandbox(BuildContext context) {
    final words = defaultMapWordsFor(widget.ageGroup);
    if (words.isEmpty) return; // safety net, shouldn't happen with the built-in banks
    final freePlayLesson = Lesson(
      id: 'freeplay',
      teacherUid: '',
      title: 'Explore & Learn',
      subject: 'reading',
      ageGroup: widget.ageGroup,
      words: words,
    );
    _launchSandbox(freePlayLesson);
  }

  void _navigateToGame(BuildContext context, String subject) {
    if (subject == 'writing') {
      _startWritingPractice(widget.ageGroup, widget.kidId);
      return;
    }
    Widget screen;
    switch (subject) {
      case 'listening':
        screen = ListeningGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'speaking':
        screen = SpeakingGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'reading':
        screen = ReadingGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      case 'arithmetic':
        screen = ArithmeticGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
        break;
      default:
        screen = ListeningGameScreen(ageGroup: widget.ageGroup, kidId: widget.kidId);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // Word bank for writing practice, reusing the same age-appropriate
  // vocabulary as the reading quiz so tracing feels consistent app-wide.
  List<String> _writingWordsFor(String age) {
    switch (age) {
      case '4-5':
        return ['CAT', 'DOG', 'SUN', 'HAT', 'FISH', 'PIG', 'COW', 'BIRD'];
      case '5-6':
        return ['APPLE', 'RABBIT', 'YELLOW', 'TABLE', 'WATER', 'BANANA'];
      case '6-7':
      default:
        return ['TIGER', 'GIRAFFE', 'ZEBRA', 'TEACHER', 'PILOT', 'WINDOW'];
    }
  }

  // Runs the child through the Test-Tracing screen for each word in turn,
  // then saves progress and returns to this screen. Replaces the old
  // (buggy) coverage-detection Writing Game.
  void _startWritingPractice(String ageGroup, String kidId) {
    final words = _writingWordsFor(ageGroup);
    int index = 0;

    void goNext() {
      index++;
      if (index >= words.length) {
        Navigator.pop(context); // back to Student Home
        ProgressService.saveProgress(
          subject: 'writing',
          module: 'writing',
          ageGroup: ageGroup,
          score: words.length,
          totalQuestions: words.length,
          kidId: kidId,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Writing practice complete! 🎉'),
            backgroundColor: Color(0xFF4DD9C0),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WritingTracingScreen(
              word: words[index],
              ageGroup: ageGroup,
              isLastWord: index == words.length - 1,
              onNext: goNext,
            ),
          ),
        );
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WritingTracingScreen(
          word: words[0],
          ageGroup: ageGroup,
          isLastWord: words.length == 1,
          onNext: goNext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFFFFB7C5), shape: BoxShape.circle))),
          Positioned(top: 20, right: 20, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFFFF8FAB), shape: BoxShape.circle))),
          Positioned(bottom: -40, left: -40, child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: Color(0xFF80DEEA), shape: BoxShape.circle))),
          Positioned(bottom: 20, left: 20, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFF4DD9C0), shape: BoxShape.circle))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                    ),
                    const SizedBox(height: 24),
                    Text('Hello, ${widget.kidName}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    if (assignmentDebugInfo != null)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '[DEBUG] $assignmentDebugInfo',
                          style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 11),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (pendingAssignments.isNotEmpty) ...[
                      const Text('From Your Teacher', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                      const SizedBox(height: 12),
                      ...pendingAssignments.map((a) {
                        final subject = (a['subject'] as String? ?? 'reading');
                        final hasLesson = a['lessonId'] != null;
                        return GestureDetector(
                          onTap: () => _startAssignment(a),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF80DEEA).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF80DEEA), width: 2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: const Color(0xFF80DEEA), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(hasLesson ? Icons.school_rounded : Icons.assignment_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${subject[0].toUpperCase()}${subject.substring(1)} Assignment',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                      ),
                                      Text(
                                        hasLesson ? 'Learn new words, then quiz!' : 'Quiz time!',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF80DEEA), size: 16),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    const Text('Topics', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                    const SizedBox(height: 20),
                    _subjectCard(context, icon: Icons.hearing_rounded, label: 'Listening Game', color: const Color(0xFFFFAB40), subject: 'listening'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.mic_rounded, label: 'Speaking Game', color: const Color(0xFFFF8FAB), subject: 'speaking'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.menu_book_rounded, label: 'Reading Game', color: const Color(0xFF4DD9C0), subject: 'reading'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.edit_rounded, label: 'Writing Game', color: const Color(0xFFFFAB40), subject: 'writing'),
                    const SizedBox(height: 12),
                    _subjectCard(context, icon: Icons.calculate_rounded, label: 'Arithmetic Game', color: const Color(0xFFFF8FAB), subject: 'arithmetic'),
                    const SizedBox(height: 20),
                    const Text('Explore', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _openFreePlaySandbox(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(color: const Color(0xFF9575CD).withOpacity(0.20), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF9575CD), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.public_rounded, color: Colors.white, size: 24)),
                            const SizedBox(width: 16),
                            const Text('Explore the World 🌍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5E4A94))),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9575CD), size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _saveScreenTime();
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF8FAB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Exit', style: TextStyle(color: Color(0xFFFF8FAB), fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(BuildContext context, {required IconData icon, required String label, required Color color, required String subject}) {
    return GestureDetector(
      onTap: () => _navigateToGame(context, subject),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}