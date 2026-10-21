import 'active_booking_service.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'driver_trip_service.dart';
import 'location_place_service.dart';
import 'notification_service.dart';
import 'place_registry_service.dart';
import 'platform_config_service.dart';
import 'profile_service.dart';
import 'trip_catalog_service.dart';
import 'trip_completion_service.dart';

/// Bosh sahifa va asosiy tablar uchun pastga tortib yangilash.
class AppRefresh {
  AppRefresh._();

  static Future<void> run() async {
    await Future.wait([
      _ok(LocationPlaceService.instance.ensure(force: true)),
      _ok(NotificationService.instance.refresh(full: true)),
      _ok(PlaceRegistryService.instance.refresh()),
      _ok(TripCatalogService.instance.refresh()),
      _ok(PlatformConfigService.instance.load()),
      _ok(ActiveBookingService.instance.load()),
      // `load()` o'zi birinchi chaqiruvdan keyin no-op bo'lib qoladi (xizmat
      // allaqachon yuklangan bo'lsa) — shuning uchun pastga tortib
      // yangilash yoki ilova fondan qaytganda faol bronning HAQIQIY
      // server holatini qayta tekshirish uchun alohida chaqiramiz.
      _ok(ActiveBookingService.instance.refreshNow()),
      _ok(ChatService.instance.load()),
      _ok(ChatService.instance.syncAllFromServer()),
      _ok(DriverTripService.instance.load()),
      _ok(DriverTripService.instance.syncFromServer()),
      _ok(DriverTripService.instance.pollInbox()),
      _ok(TripCompletionService.instance.syncFromServer()),
      _ok(_auth()),
    ]);
  }

  static Future<void> _auth() async {
    if (!AuthService.instance.registered) return;
    await AuthService.instance.refreshMe();
    await ProfileService.instance.syncFromAuth();
  }

  static Future<void> _ok(Future<void> task) async {
    try {
      await task;
    } catch (_) {}
  }
}
