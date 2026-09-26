import 'package:flutter/material.dart';

/// SAFARON TAXI rasmiy logotipi (PNG).
class SafaronLogo extends StatelessWidget {
  const SafaronLogo({
    super.key,
    this.size = 72,
    this.borderRadius = 16,
  });

  final double size;
  final double borderRadius;

  static const assetPath = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.local_taxi_rounded, size: size * 0.6),
      ),
    );
  }
}
