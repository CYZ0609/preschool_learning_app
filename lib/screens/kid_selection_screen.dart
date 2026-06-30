import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student/student_home.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KidSelectionScreen extends StatefulWidget {
  const KidSelectionScreen({super.key});

  @override
  State<KidSelectionScreen> createState() => _KidSelectionScreenState();
}

class _KidSelectionScreenState extends State<KidSelectionScreen> {
  List<Map<String, dynamic>> allKids = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllKids();
  }

  Future<void> _loadAllKids() async {
  // Anonymous login for kids
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  
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
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB7C5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFFF8FAB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFF80DEEA),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF4DD9C0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Who is playing?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your name',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 32),
                  isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFFAB40)),
                        )
                      : allKids.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.face_rounded,
                                      size: 80, color: Color(0xFFEEEEEE)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No kids found',
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF888888)),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Ask your parent to register first',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF888888)),
                                  ),
                                ],
                              ),
                            )
                          : Expanded(
                              child: GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                children: allKids.map((kid) {
                                  final colors = [
                                    const Color(0xFFFFAB40),
                                    const Color(0xFFFF8FAB),
                                    const Color(0xFF4DD9C0),
                                    const Color(0xFF64B5F6),
                                  ];
                                  final color = colors[
                                      allKids.indexOf(kid) % colors.length];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudentHome(
                                            kidName: kid['name'],
                                            ageGroup: kid['ageGroup'],
                                            kidId: kid['id'],
                                            parentId: kid['parentId'],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                                Icons.face_rounded,
                                                color: Colors.white,
                                                size: 36),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            kid['name'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                          Text(
                                            'Age ${kid['ageGroup']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF888888),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}