import 'package:flutter/material.dart';

class SubjectMenuScreen extends StatelessWidget {
  final String ageGroup;
  
  // 确认构造函数是否包含 ageGroup
  const SubjectMenuScreen({super.key, required this.ageGroup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subjects")),
      body: Center(child: Text("Age Group: $ageGroup")),
    );
  }
}