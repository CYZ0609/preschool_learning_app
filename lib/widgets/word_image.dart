import 'package:flutter/material.dart';

/// Renders a vocabulary word's picture from EITHER a bundled asset
/// (`assets/images/cow.png`) OR a teacher-uploaded Firebase Storage URL
/// (`https://firebasestorage.googleapis.com/...`) — whichever
/// [imageAsset] actually contains. This is the one place that decides
/// which track to use, so every screen showing a word's picture
/// (Inventory, placed items on the map, the lesson-builder chips) stays
/// in sync automatically and never needs its own if/else for this.
class WordImage extends StatelessWidget {
  final String imageAsset;
  final BoxFit fit;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final double scale;

  const WordImage({
    super.key,
    required this.imageAsset,
    this.fit = BoxFit.contain,
    this.errorWidget,
    this.width,
    this.height,
    this.scale = 1.0,
  });

  bool get _isNetwork => imageAsset.startsWith('http://') || imageAsset.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ?? const Icon(Icons.emoji_nature_rounded, color: Colors.white70);

    Widget imageWidget;

    if (_isNetwork) {
      imageWidget = Image.network(
        imageAsset,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child; // fully loaded
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      imageWidget = Image.asset(
        imageAsset,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // 这里将最终的图片组件用 Transform.scale 包裹起来，实现等比例缩放
    return Transform.scale(
      scale: scale,
      child: imageWidget,
    );
  }
}