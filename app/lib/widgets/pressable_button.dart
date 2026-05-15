import 'package:flutter/material.dart';

class PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableButton({Key? key, required this.child, this.onTap}) : super(key: key);

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.90),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: Duration(milliseconds: 60),
        child: widget.child,
      ),
    );
  }
}