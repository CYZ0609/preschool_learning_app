import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import 'add_item_screen.dart';
import 'view_items_screen.dart'; // 👈 1. 导入我们刚才写的新页面

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 背景装饰圆圈
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
                  const Text('Teacher Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 8),
                  const Text('Manage Sandbox Items', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                  const SizedBox(height: 28),
                  
                  // 管理卡片 1：添加沙盒物品
                  _menuCard(
                    icon: Icons.add_photo_alternate_rounded,
                    label: 'Add New Item',
                    subtitle: 'Upload images, set sizes & collisions',
                    color: const Color(0xFF4DD9C0),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddItemScreen()),
                    ),
                  ),
                  
                  const SizedBox(height: 16), // 👈 卡片之间的间距
                  
                  // 👇 2. 新增的管理卡片 2：查看沙盒物品库
                  _menuCard(
                    icon: Icons.photo_library_rounded,
                    label: 'View Items Library',
                    subtitle: 'Manage and delete uploaded sandbox items',
                    color: const Color(0xFFFF8FAB), // 用了背景圆圈的粉色，保持统一风格
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ViewItemsScreen()),
                    ),
                  ),
                  // 👆 新增结束 👆
                  
                  const Spacer(),
                  
                  // 登出按钮
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
                        side: const BorderSide(color: Color(0xFFFFAB40)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Logout', style: TextStyle(color: Color(0xFFFFAB40), fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _menuCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded( // 加了 Expanded 防止文字太长超出屏幕
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}