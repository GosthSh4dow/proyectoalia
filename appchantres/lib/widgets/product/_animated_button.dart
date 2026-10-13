// Animated Button Widget for ProductForm
import 'package:flutter/material.dart';

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  const _AnimatedButton({
    required this.onPressed,
    required this.child,
    this.color,
    this.borderColor,
    this.gradient,
  });

  @override
  __AnimatedButtonState createState() => __AnimatedButtonState();
}

class __AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.gradient ??
                const LinearGradient(
                  colors: [
                    Color(0xFFE879F9),
                    Color(0xFFFB7185)
                  ], // Fuchsia to Rose
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            color: widget.color,
            borderRadius: BorderRadius.circular(16), // More rounded
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!)
                : null,
            boxShadow: [
              if (widget.color ==
                  null) // Only show shadow if it's the primary button (gradient)
                BoxShadow(
                  color: const Color(0xFFE879F9).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                )
              else if (widget.color == Colors.white)
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
