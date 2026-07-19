import 'package:flutter/material.dart';

/// A tappable PNG button. Dims and ignores input when [onPressed] is null.
final class ImageButton extends StatefulWidget {
  const ImageButton({
    super.key,
    required this.asset,
    required this.onPressed,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final String asset;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  State<ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Image.asset(
              widget.asset,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
