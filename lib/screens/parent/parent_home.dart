import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import 'child_progress_screen.dart';
import 'screen_time_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_child_screen.dart';

class ParentHome extends StatelessWidget {
  const ParentHome({super.key});

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Parent Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 8),
                  const Text('Monitor your child\'s learning', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                  const SizedBox(height: 28),
                  _menuCard(
                    context,
                    icon: Icons.bar_chart_rounded,
                    label: 'My Child\'s Progress',
                    subtitle: 'View learning performance',
                    color: const Color(0xFFFFAB40),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChildProgressScreen(
                          parentUid: FirebaseAuth.instance.currentUser!.uid,
                        ),
                           ),
                             ), ),
                  const SizedBox(height: 12),
                  _menuCard(
                    context,
                    icon: Icons.timer_rounded,
                    label: 'Screen Time',
                    subtitle: 'Monitor and set daily limits',
                    color: const Color(0xFFFF8FAB),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenTimeScreen())),
                  ),
                  const SizedBox(height: 12),
                  _menuCard(
                    context,
                    icon: Icons.person_add_rounded,
                    label: 'Add New Child',
                    subtitle: 'Register another child',
                    color: const Color(0xFF4DD9C0),
                    onTap: () => _showAddChildDialog(context),
                  ),
                  const SizedBox(height: 12),
                  _menuCard(
                    context,
                    icon: Icons.manage_accounts_rounded,
                    label: 'Manage Child Account',
                    subtitle: 'Edit profile and settings',
                    color: const Color(0xFF64B5F6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageChildScreen()),
                      ),
                      ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF8FAB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Logout', style: TextStyle(color: Color(0xFFFF8FAB), fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showAddChildDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedAge = '4-5';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Child', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Child\'s Name',
                  filled: true,
                  fillColor: const Color(0xFFFFF3F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF3F6), borderRadius: BorderRadius.circular(14)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedAge,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: '4-5', child: Text('Age 4 - 5')),
                      DropdownMenuItem(value: '5-6', child: Text('Age 5 - 6')),
                      DropdownMenuItem(value: '6-7', child: Text('Age 6 - 7')),
                    ],
                    onChanged: (val) => setState(() => selectedAge = val!),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('children')
                    .add({
                  'name': nameController.text.trim(),
                  'ageGroup': selectedAge,
                  'createdAt': DateTime.now(),
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Child added successfully! ✅'), backgroundColor: Color(0xFF4DD9C0)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4DD9C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(BuildContext context, {required IconData icon, required String label, required String subtitle, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 26)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}