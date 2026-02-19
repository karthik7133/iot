import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double borderOpacity;

  const GlassCard({
    Key? key,
    required this.child,
    this.blur = 12, // Updated
    this.opacity = 0.08, // Updated
    this.borderRadius = 24,
    this.padding,
    this.borderOpacity = 0.3, // Updated
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
