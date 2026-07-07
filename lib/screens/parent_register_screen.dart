import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parent/parent_home.dart';

class ParentRegisterScreen extends StatefulWidget {
  const ParentRegisterScreen({super.key});

  @override
  State<ParentRegisterScreen> createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final childNameController = TextEditingController();
  String selectedAgeGroup = '4-5';
  String errorMessage = '';
  bool isLoading = false;

  Future<void> register() async {
  if (nameController.text.trim().isEmpty ||
      emailController.text.trim().isEmpty ||
      passwordController.text.trim().isEmpty) {
    setState(() => errorMessage = 'Please fill in all required fields');
    return;
  }

  setState(() => isLoading = true);
  try {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    final parentUid = credential.user!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .set({
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'role': 'parent',
      'createdAt': DateTime.now(),
    });

    // Only add child if name is filled
    if (childNameController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .add({
        'name': childNameController.text.trim(),
        'ageGroup': selectedAgeGroup,
        'createdAt': DateTime.now(),
      });
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ParentHome()),
      (route) => false,
    );
  } on FirebaseAuthException catch (e) {
    setState(() {
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered. Please login instead.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password should be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else {
        errorMessage = 'Registration failed. Please try again.';
      }
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      errorMessage = 'Something went wrong. Please try again.';
      isLoading = false;
    });
  }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_ios_rounded,
                          color: Color(0xFF333333)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.family_restroom_rounded,
                    size: 70,
                    color: Color(0xFFFF8FAB),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Parent Info',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF8FAB))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Your Name',
                            prefixIcon: const Icon(Icons.person_rounded,
                                color: Color(0xFFFF8FAB)),
                            filled: true,
                            fillColor: const Color(0xFFFFF3F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            prefixIcon: const Icon(Icons.email_rounded,
                                color: Color(0xFFFF8FAB)),
                            filled: true,
                            fillColor: const Color(0xFFFFF3F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded,
                                color: Color(0xFFFF8FAB)),
                            filled: true,
                            fillColor: const Color(0xFFFFF3F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('First Child Info (Optional)',
    style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFFFF8FAB))),
const SizedBox(height: 4),
const Text('You can add this later from the dashboard',
    style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: childNameController,
                          decoration: InputDecoration(
                            hintText: 'Child\'s Name',
                            prefixIcon: const Icon(Icons.face_rounded,
                                color: Color(0xFFFF8FAB)),
                            filled: true,
                            fillColor: const Color(0xFFFFF3F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedAgeGroup,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Color(0xFFFF8FAB)),
                              items: const [
                                DropdownMenuItem(
                                    value: '4-5',
                                    child: Text('Age 4 - 5')),
                                DropdownMenuItem(
                                    value: '5-6',
                                    child: Text('Age 5 - 6')),
                                DropdownMenuItem(
                                    value: '6-7',
                                    child: Text('Age 6 - 7')),
                              ],
                              onChanged: (val) {
                                setState(() => selectedAgeGroup = val!);
                              },
                            ),
                          ),
                        ),
                        if (errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(errorMessage,
                              style:
                                  const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8FAB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}