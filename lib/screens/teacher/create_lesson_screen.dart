import 'package:flutter/material.dart';
import '../../data/asset_images.dart';
import '../../services/lesson_service.dart';

class CreateLessonScreen extends StatefulWidget {
  const CreateLessonScreen({super.key});

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final _titleController = TextEditingController();
  final _wordController = TextEditingController();

  String selectedSubject = 'reading';
  String selectedAgeGroup = '4-5';
  String? selectedImage; // asset name, e.g. "cat"
  bool isSaving = false;

  final List<LessonWord> lessonWords = [];

  final subjects = const [
    {'value': 'reading', 'label': 'Reading', 'icon': Icons.menu_book_rounded},
    {'value': 'listening', 'label': 'Listening', 'icon': Icons.hearing_rounded},
    {'value': 'speaking', 'label': 'Speaking', 'icon': Icons.mic_rounded},
    {'value': 'writing', 'label': 'Writing', 'icon': Icons.edit_rounded},
    {'value': 'arithmetic', 'label': 'Arithmetic', 'icon': Icons.calculate_rounded},
  ];

  final ageGroups = const ['4-5', '5-6', '6-7'];

  @override
  void dispose() {
    _titleController.dispose();
    _wordController.dispose();
    super.dispose();
  }

  void _addWord() {
    final word = _wordController.text.trim();
    if (word.isEmpty || selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type a word and pick a picture for it'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      lessonWords.add(LessonWord(
        word: word.toUpperCase(),
        imageAsset: assetPathFor(selectedImage!),
      ));
      _wordController.clear();
      selectedImage = null;
    });
  }

  void _removeWord(int index) {
    setState(() => lessonWords.removeAt(index));
  }

  Future<void> _saveLesson() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please give the lesson a title'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (lessonWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one word to teach'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await LessonService.createLesson(
        title: title,
        subject: selectedSubject,
        ageGroup: selectedAgeGroup,
        words: lessonWords,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson created! 🎉'),
          backgroundColor: Color(0xFF4DD9C0),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _openImagePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose a picture',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: kAvailableAssetImages.length,
                      itemBuilder: (context, index) {
                        final name = kAvailableAssetImages[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedImage = name);
                            Navigator.pop(context);
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(assetPathFor(name), fit: BoxFit.contain),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: const Text('Create Lesson',
            style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lesson Title',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. Farm Animals',
                filled: true,
                fillColor: const Color(0xFFE0FDF4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Subject',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: subjects.map((s) {
                final isSelected = selectedSubject == s['value'];
                return GestureDetector(
                  onTap: () => setState(() => selectedSubject = s['value'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4DD9C0).withOpacity(0.15) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF4DD9C0) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s['icon'] as IconData, size: 18,
                            color: isSelected ? const Color(0xFF4DD9C0) : const Color(0xFF888888)),
                        const SizedBox(width: 6),
                        Text(s['label'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF4DD9C0) : const Color(0xFF333333),
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Age Group',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            Row(
              children: ageGroups.map((age) {
                final isSelected = selectedAgeGroup == age;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedAgeGroup = age),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF8FAB).withOpacity(0.15) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF8FAB) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(age,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFFFF8FAB) : const Color(0xFF333333),
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Add Words to Teach',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: _openImagePicker,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: selectedImage == null
                        ? const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF888888))
                        : Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(assetPathFor(selectedImage!), fit: BoxFit.contain),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _wordController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Word (e.g. COW)',
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addWord,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Color(0xFF4DD9C0), shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (lessonWords.isNotEmpty) ...[
              const Text('Words in this lesson',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(lessonWords.length, (i) {
                  final w = lessonWords[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Image.asset(w.imageAsset, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 6),
                        Text(w.word, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A8C7A))),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeWord(i),
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
            ],

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveLesson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DD9C0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Lesson 📚',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
