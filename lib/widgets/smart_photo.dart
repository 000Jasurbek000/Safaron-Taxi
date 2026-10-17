import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Asset, lokal fayl yoki server rasmini bir xil ko‘rsatadi.
class SmartPhoto extends StatelessWidget {
  const SmartPhoto({
    super.key,
    required this.src,
    this.fallback = 'assets/images/driver_avatar.png',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? src;
  final String fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = _build();
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _build() {
    final raw = (src ?? '').trim();
    if (raw.isEmpty) return _asset(fallback);

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return _network(raw);
    }
    if (raw.startsWith('/uploads/') || raw.startsWith('uploads/') || raw.startsWith('drivers/') || raw.startsWith('vehicles/') || raw.startsWith('avatars/')) {
      return _network(ApiClient.instance.mediaUrl(raw));
    }
    if (!raw.startsWith('assets/') && File(raw).existsSync()) {
      return Image.file(File(raw), width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => _asset(fallback));
    }
    if (raw.startsWith('assets/')) return _asset(raw);
    return _network(ApiClient.instance.mediaUrl(raw));
  }

  Widget _asset(String path) {
    return Image.asset(path, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) {
      return SizedBox(width: width, height: height, child: const ColoredBox(color: Color(0xFFE8EEF5)));
    });
  }

  Widget _network(String url) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _asset(fallback),
    );
  }
}
