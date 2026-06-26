import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChildProgressScreen extends StatelessWidget {
  const ChildProgressScreen({super.key});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('progress')
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
            return const Center(
              child: Text('No progress yet. Play a game to start!',
                  style: TextStyle(color: Color(0xFF888888))),
            );
          }

          final Map<String, List<double>> moduleAccuracy = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final module = data['module'] ?? 'unknown';
            final accuracy = (data['accuracy'] ?? 0).toDouble();
            moduleAccuracy.putIfAbsent(module, () => []).add(accuracy);
          }

          final Map<String, double> moduleAverage = {
            for (var entry in moduleAccuracy.entries)
              entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length
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
                const Text('Performance by Subject',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: moduleAverage.entries.map((entry) {
                      final color =
                          colors[entry.key] ?? const Color(0xFF888888);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key[0].toUpperCase() +
                                      entry.key.substring(1),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color),
                                ),
                                Text(
                                    '${(entry.value * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
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
                  final data = doc.data() as Map<String, dynamic>;
                  final module = data['module'] ?? 'unknown';
                  final color =
                      colors[module] ?? const Color(0xFF888888);
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
                            borderRadius: BorderRadius.circular(12),
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
                                            : Icons.calculate_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: Color(0xFF888888))),
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
    );
  }
}