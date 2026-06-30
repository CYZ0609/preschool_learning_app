import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChildProgressScreen extends StatefulWidget {
  final String parentUid;
  const ChildProgressScreen({super.key, required this.parentUid});

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen> {
  List<Map<String, dynamic>> children = [];
  String? selectedChildId;
  String? selectedChildName;
  bool isLoadingChildren = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.parentUid)
        .collection('children')
        .get();

    setState(() {
      children = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unknown',
                'ageGroup': doc.data()['ageGroup'] ?? '4-5',
              })
          .toList();
      if (children.isNotEmpty) {
        selectedChildId = children[0]['id'];
        selectedChildName = children[0]['name'];
      }
      isLoadingChildren = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: const Text("My Child's Progress",
            style: TextStyle(
                color: Color(0xFF333333), fontWeight: FontWeight.bold)),
      ),
      body: isLoadingChildren
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8FAB)))
          : children.isEmpty
              ? const Center(
                  child: Text('No children found.',
                      style: TextStyle(color: Color(0xFF888888))))
              : Column(
                  children: [
                    // Child selector
                    if (children.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedChildId,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Color(0xFFFF8FAB)),
                              items: children.map((child) {
                                return DropdownMenuItem<String>(
                                  value: child['id'],
                                  child: Text(child['name']),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedChildId = val;
                                  selectedChildName = children.firstWhere(
                                      (c) => c['id'] == val)['name'];
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    // Progress data
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('progress')
                            .where('studentUid', isEqualTo: selectedChildId)
                            .orderBy('sessionDate', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFF8FAB)));
                          }

                          final docs = snapshot.data!.docs;

                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.sports_esports_rounded,
                                      size: 80, color: Color(0xFFEEEEEE)),
                                  const SizedBox(height: 16),
                                  Text(
                                    '${selectedChildName ?? "Child"} hasn\'t played yet!',
                                    style: const TextStyle(
                                        color: Color(0xFF888888)),
                                  ),
                                ],
                              ),
                            );
                          }

                          final Map<String, List<double>> moduleAccuracy = {};
                          for (var doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final module = data['module'] ?? 'unknown';
                            final accuracy =
                                (data['accuracy'] ?? 0).toDouble();
                            moduleAccuracy
                                .putIfAbsent(module, () => [])
                                .add(accuracy);
                          }

                          final Map<String, double> moduleAverage = {
                            for (var entry in moduleAccuracy.entries)
                              entry.key: entry.value.reduce((a, b) => a + b) /
                                  entry.value.length
                          };

                          final colors = {
                            'listening': const Color(0xFFFFAB40),
                            'speaking': const Color(0xFFFF8FAB),
                            'reading': const Color(0xFF4DD9C0),
                            'writing': const Color(0xFFFFAB40),
                            'arithmetic': const Color(0xFFFF8FAB),
                          };

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${selectedChildName ?? "Child"}\'s Performance',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333)),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    children: moduleAverage.entries.map((entry) {
                                      final color = colors[entry.key] ??
                                          const Color(0xFF888888);
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  entry.key[0].toUpperCase() +
                                                      entry.key.substring(1),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: color),
                                                ),
                                                Text(
                                                    '${(entry.value * 100).toStringAsFixed(0)}%',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: color)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: entry.value,
                                                backgroundColor: Colors.white,
                                                color: color,
                                                minHeight: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Text('Recent Sessions',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333))),
                                const SizedBox(height: 16),
                                ...docs.take(10).map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final module = data['module'] ?? 'unknown';
                                  final color = colors[module] ??
                                      const Color(0xFF888888);
                                  final score = data['score'] ?? 0;
                                  final total = data['totalQuestions'] ?? 0;
                                  final stars = data['starsEarned'] ?? 0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            module == 'listening'
                                                ? Icons.hearing_rounded
                                                : module == 'speaking'
                                                    ? Icons.mic_rounded
                                                    : module == 'reading'
                                                        ? Icons.menu_book_rounded
                                                        : module == 'writing'
                                                            ? Icons.edit_rounded
                                                            : Icons
                                                                .calculate_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                module[0].toUpperCase() +
                                                    module.substring(1),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: color),
                                              ),
                                              Text('Score: $score / $total',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Color(0xFF888888))),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(
                                            3,
                                            (i) => Icon(
                                              Icons.star_rounded,
                                              size: 18,
                                              color: i < stars
                                                  ? const Color(0xFFFFC107)
                                                  : const Color(0xFFE0E0E0),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}