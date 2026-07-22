import 'package:flutter/material.dart';

/// A cartoon-style "jelly" button: big rounded corners, bright fill, thick
/// white border, and a solid bottom shadow that gives it a pressable,
/// 3D "gummy" look — used in place of plain ElevatedButton/Container
/// throughout the sandbox UI.
class JellyButton extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const JellyButton({
    super.key,
    required this.child,
    required this.color,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.borderRadius = 24,
  });

  @override
  State<JellyButton> createState() => _JellyButtonState();
}

class _JellyButtonState extends State<JellyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shadowColor = HSLColor.fromColor(widget.color).withLightness(
      (HSLColor.fromColor(widget.color).lightness - 0.18).clamp(0.0, 1.0),
    ).toColor();

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.onTap == null ? Colors.grey.shade300 : widget.color,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: widget.onTap == null
              ? []
              : [
                  BoxShadow(
                    color: shadowColor,
                    offset: Offset(0, _pressed ? 1 : 5),
                    blurRadius: 0, // solid, cartoon-style shadow, not a soft blur
                  ),
                ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          child: widget.child,
        ),
      ),
    );
  }
}
