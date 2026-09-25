import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { light, dark, auto }

/// Kunduzgi / tungi / avtomatik (19:00–07:00 tungi).
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _kPref = 'safaron_theme_pref';
  static const _kOnboarded = 'safaron_onboarded_v2';

  ThemePreference preference = ThemePreference.light;
  bool onboarded = false;
  bool _loaded = false;
  Timer? _autoTimer;
  bool _lastDark = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool(_kOnboarded) ?? false;
    final raw = prefs.getString(_kPref) ?? 'light';
    preference = switch (raw) {
      'dark' => ThemePreference.dark,
      'auto' => ThemePreference.auto,
      _ => ThemePreference.light,
    };
    _loaded = true;
    _lastDark = isDark;
    _armAutoTimer();
    notifyListeners();
  }

  void _armAutoTimer() {
    _autoTimer?.cancel();
    if (preference != ThemePreference.auto) return;
    _autoTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final nowDark = isDark;
      if (nowDark != _lastDark) {
        _lastDark = nowDark;
        notifyListeners();
      }
    });
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, true);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    onboarded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, false);
    notifyListeners();
  }

  Future<void> setPreference(ThemePreference value) async {
    preference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPref,
      switch (value) {
        ThemePreference.dark => 'dark',
        ThemePreference.auto => 'auto',
        ThemePreference.light => 'light',
      },
    );
    _lastDark = isDark;
    _armAutoTimer();
    notifyListeners();
  }

  /// Bosh sahifa: faqat kunduzgi ↔ tungi (auto emas).
  Future<void> toggleLightDark() async {
    final next = isDark ? ThemePreference.light : ThemePreference.dark;
    await setPreference(next);
  }

  bool get isDark {
    switch (preference) {
      case ThemePreference.dark:
        return true;
      case ThemePreference.light:
        return false;
      case ThemePreference.auto:
        final h = DateTime.now().hour;
        return h >= 19 || h < 7;
    }
  }
}
