import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image from the device and uploads it to Firebase Storage for
/// a teacher-created custom vocabulary word, returning the public
/// download URL to save alongside the word (in `LessonWord.imageAsset`).
class ImageUploadService {
  static final _picker = ImagePicker();

  /// Opens the device's native gallery/file picker. Returns null if the
  /// teacher cancels — callers should just no-op in that case, not treat
  /// it as an error.
  static Future<File?> pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // keep uploads reasonably small for mobile data
      maxWidth: 1024,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Uploads [file] to `customWordImages/{teacherUid}/{timestamp}_{filename}`
  /// in Firebase Storage and returns the download URL.
  static Future<String> uploadWordImage({
    required File file,
    required String teacherUid,
  }) async {
    final safeName = file.uri.pathSegments.last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref('customWordImages/$teacherUid/$fileName');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }
}
