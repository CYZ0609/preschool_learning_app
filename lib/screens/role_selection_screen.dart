import 'package:flutter/material.dart';
import 'parent/parent_home.dart';
import 'teacher/teacher_home.dart';
import 'student/age_selection_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top-right pink blob
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
          // Bottom-left teal blob
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
          // Main content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://cdn-icons-png.flaticon.com/512/3976/3976625.png',
                      height: 180,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.people_rounded,
                        size: 100,
                        color: Color(0xFFFF8FAB),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'What is your role?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _roleButton(
                      context,
                      label: 'Student',
                      color: const Color(0xFFFFAB40),
                      screen: const AgeSelectionScreen(),
                    ),
                    const SizedBox(height: 16),
                    _roleButton(
                      context,
                      label: 'Parent',
                      color: const Color(0xFFFF8FAB),
                      screen: const ParentHome(),
                    ),
                    const SizedBox(height: 16),
                    _roleButton(
                      context,
                      label: 'Teacher',
                      color: const Color(0xFF4DD9C0),
                      screen: const TeacherHome(),
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

  Widget _roleButton(
    BuildContext context, {
    required String label,
    required Color color,
    required Widget screen,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}