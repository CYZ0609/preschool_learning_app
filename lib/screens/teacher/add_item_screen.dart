import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _nameController = TextEditingController();
  final _widthController = TextEditingController(text: '1');
  final _heightController = TextEditingController(text: '1');
  
  File? _selectedImage;
  bool _isSolid = true;
  bool _isMovable = false;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadAndSave() async {
    final name = _nameController.text.trim().toUpperCase();
    final widthText = _widthController.text.trim();
    final heightText = _heightController.text.trim();

    if (name.isEmpty || _selectedImage == null || widthText.isEmpty || heightText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and pick an image')),
      );
      return;
    }

    int width = int.tryParse(widthText) ?? 1;
    int height = int.tryParse(heightText) ?? 1;

    setState(() => _isUploading = true);

    try {
      // 1. 上传图片到 Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('sandbox_items/${DateTime.now().millisecondsSinceEpoch}.png');
      await storageRef.putFile(_selectedImage!);
      final imageUrl = await storageRef.getDownloadURL();

      // 2. 将数据保存到 Firestore 的 'sandbox_items' 集合中
      await FirebaseFirestore.instance.collection('sandbox_items').add({
        'itemId': name, // 比如: TREE_LARGE
        'imageUrl': imageUrl,
        'width': width,
        'height': height,
        'isSolid': _isSolid,
        'isMovable': _isMovable,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully! ✅'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Sandbox Item', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 图片选择器
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_selectedImage!, fit: BoxFit.contain),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Tap to pick image', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),

                  // 👇👇👇 新加的透明背景提醒 👇👇👇
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Teacher Tip: For best results, please upload images with a transparent background (PNG format) to avoid white boxes ruining the sandbox immersion.',
                            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 👆👆👆 提醒结束 👆👆👆

                  const SizedBox(height: 24),

                  // 2. 名字输入
                  const Text('Item ID / Name (e.g. HOUSE, TREE)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'HOUSE_01',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. 尺寸设定
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Grid Width (x)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _widthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Grid Height (y)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. 属性开关
                  const Text('Item Properties', style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: const Text('Is Solid (Obstacle)'),
                    subtitle: const Text('Prevents other things from passing through'),
                    value: _isSolid,
                    activeColor: const Color(0xFF4DD9C0),
                    onChanged: (val) => setState(() => _isSolid = val),
                  ),
                  SwitchListTile(
                    title: const Text('Self-Moving (Animal)'),
                    subtitle: const Text('Wanders one grid square on its own every few seconds once a kid places it — for animals, not for furniture/decor'),
                    value: _isMovable,
                    activeColor: const Color(0xFF4DD9C0),
                    onChanged: (val) => setState(() => _isMovable = val),
                  ),
                  const SizedBox(height: 32),

                  // 5. 提交按钮
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _uploadAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD9C0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Upload & Save Item', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}