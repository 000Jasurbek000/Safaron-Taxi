import 'package:flutter/foundation.dart';

/// Pastki menyu indeksini boshqa sahifalardan o‘zgartirish uchun.
class AppNavigation {
  AppNavigation._();
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);
  /// Haydovchi buyurtmalar tab: 0=hozirgi, 1=qabul, 2=oldindan
  static final ValueNotifier<int> driverOrdersTab = ValueNotifier<int>(0);

  static void goHome() => tabIndex.value = 0;
  static void goTrips({int driverTab = 0}) {
    driverOrdersTab.value = driverTab;
    tabIndex.value = 1;
  }
  static void goTaxis() => tabIndex.value = 2;
  static void goMessages() => tabIndex.value = 3;
  static void goProfile() => tabIndex.value = 4;
}
