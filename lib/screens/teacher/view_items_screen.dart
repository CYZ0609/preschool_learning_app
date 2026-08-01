import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // 智能识别图片类型的函数：自动判断是网络图片还是本地图片
  Widget _buildImage(String imageUrl, String itemName) {
    if (imageUrl.startsWith('http')) {
      // 1. 如果是 Firebase 传回来的网络链接
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
      );
    } else if (imageUrl.isNotEmpty) {
      // 2. 如果是数据库里写好的本地路径 (例如: assets/images/pikachu.png)
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
      );
    } else {
      // 3. 如果没图片路径，尝试根据名字去本地找
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
        // 🚨 移除了 .orderBy()，这样就不会漏掉没有 createdAt 字段的预设词了
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

          // 手动在内存中排序，把有时间的排在前面（新上传的），没时间的（旧预设词）放在后面，保证全部显示
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
                            // 🚨 使用我们上面写的智能识别图片函数
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
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteItem(context, docId, name),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          padding: const EdgeInsets.all(4),
                        ),
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