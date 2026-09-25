import 'package:flutter/material.dart';

import '../services/theme_service.dart';

/// Dinamik ranglar — tungi rejim: navy kartalar + neon yashil.
abstract final class AppColors {
  static bool get _d => ThemeService.instance.isDark;

  static const Color primary = Color(0xFF00C853);
  static const Color primaryLight = Color(0xFF69F0AE);
  static Color get primaryDark => _d ? const Color(0xFF00E676) : const Color(0xFF007A55);
  /// Logodagi sariq taksi — qo‘shimcha accent.
  static const Color accent = Color(0xFFFFC107);
  static const Color accentLight = Color(0xFFFFE082);
  static Color get accentDark => _d ? const Color(0xFFFFD54F) : const Color(0xFFFFA000);
  static Color get accentSoft => _d ? const Color(0xFF422006) : const Color(0xFFFFF8E1);
  static Color get navy => _d ? const Color(0xFFF1F5F9) : const Color(0xFF1A232E);
  /// Scaffold / page background (light: white, dark: #0F172A).
  static Color get white => _d ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  static Color get sky => _d ? const Color(0xFF0B1220) : const Color(0xFFF5FAFF);
  static Color get mint => _d ? const Color(0xFF111827) : const Color(0xFFF3FBF7);
  static Color get mintSoft => _d ? const Color(0xFF1E293B) : const Color(0xFFE8F7EF);
  static Color get textMuted => _d ? const Color(0xFF94A3B8) : const Color(0xFF8A939E);
  static Color get cardBorder => _d ? const Color(0xFF334155) : const Color(0xFFE6EEF0);
  static Color get selectedFill => _d ? const Color(0xFF14532D) : const Color(0xFFE6F8EF);
  static const Color destination = Color(0xFFE53935);
  static Color get surface => _d ? const Color(0xFF111827) : const Color(0xFFF7F8FA);
  static Color get card => _d ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
}
