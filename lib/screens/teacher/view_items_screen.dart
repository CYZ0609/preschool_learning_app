import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === ⚠️ 临时代码：用完请删除 (引入包) ⚠️ ===
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import '../../data/asset_images.dart'; // 引入本地词汇列表
// === ⚠️ 临时代码结束 ⚠️ ===

class ViewItemsScreen extends StatelessWidget {
  const ViewItemsScreen({super.key});

  Future<void> _deleteItem(BuildContext context, String docId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('sandbox_items').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$itemName deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ✨ 新增：编辑物品的弹窗逻辑
  Future<void> _showEditDialog(BuildContext context, String docId, Map<String, dynamic> currentData) async {
    // 初始化控制器并填入现有数据
    final TextEditingController widthCtrl = TextEditingController(text: currentData['width']?.toString() ?? '1');
    final TextEditingController heightCtrl = TextEditingController(text: currentData['height']?.toString() ?? '1');
    final TextEditingController imageUrlCtrl = TextEditingController(text: currentData['imageUrl'] ?? '');
    
    bool isSolid = currentData['isSolid'] ?? false;
    bool isMovable = currentData['isMovable'] ?? false;
    final String itemName = currentData['itemId'] ?? 'UNKNOWN';

    await showDialog(
      context: context,
      builder: (context) {
        // 使用 StatefulBuilder 可以在弹窗内更新 Switch 的状态
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit "$itemName"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: imageUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Image Path / URL',
                        hintText: 'e.g., assets/images/cow.png',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Width (Size X)'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: heightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Height (Size Y)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Is Solid', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Blocks movement (e.g., trees)', style: TextStyle(fontSize: 12)),
                      value: isSolid,
                      activeColor: Colors.orange,
                      onChanged: (val) => setState(() => isSolid = val),
                    ),
                    SwitchListTile(
                      title: const Text('Is Movable', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Wanders around (e.g., animals)', style: TextStyle(fontSize: 12)),
                      value: isMovable,
                      activeColor: Colors.blue,
                      onChanged: (val) => setState(() => isMovable = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // 将修改保存回 Firebase
                      await FirebaseFirestore.instance.collection('sandbox_items').doc(docId).update({
                        'imageUrl': imageUrlCtrl.text.trim(),
                        'width': int.tryParse(widthCtrl.text) ?? 1,
                        'height': int.tryParse(heightCtrl.text) ?? 1,
                        'isSolid': isSolid,
                        'isMovable': isMovable,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$itemName updated successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4DD9C0)),
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 智能识别图片类型的函数
  Widget _buildImage(String imageUrl, String itemName) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
      );
    } else if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
      );
    } else {
      return Image.asset(
        'assets/images/${itemName.toLowerCase()}.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Items Library', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sandbox_items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4DD9C0)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No items found.\nGo add some sandbox items!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // 排序逻辑保持不变
          final items = snapshot.data!.docs.toList();
          items.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final timeA = dataA['createdAt'] as Timestamp?;
            final timeB = dataB['createdAt'] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final String docId = doc.id;
              final String name = data['itemId'] ?? 'UNKNOWN';
              final String imageUrl = data['imageUrl'] ?? '';
              final int width = data['width'] ?? 1;
              final int height = data['height'] ?? 1;
              final bool isSolid = data['isSolid'] ?? false;
              final bool isMovable = data['isMovable'] ?? false;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(8.0),
                            child: _buildImage(imageUrl, name),
                          ),
                        ),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Size: $width x $height',
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (isSolid) const Icon(Icons.block, size: 14, color: Colors.orange),
                                  if (isSolid) const SizedBox(width: 8),
                                  if (isMovable) const Icon(Icons.directions_run, size: 14, color: Colors.blue),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    // ✨ 这里的右上角增加了编辑和删除按钮
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => _showEditDialog(context, docId, data),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _deleteItem(context, docId, name),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}