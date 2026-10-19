import 'package:flutter/foundation.dart';

import '../models/taxi_offer.dart';
import 'api_client.dart';
import 'safaron_api.dart';

/// Serverdagi tayyor safarlar katalogi.
class TripCatalogService extends ChangeNotifier {
  TripCatalogService._();
  static final TripCatalogService instance = TripCatalogService._();

  List<TaxiOffer> remote = [];
  bool loading = false;
  String? error;

  Future<void> refresh({String? from, String? to}) async {
    loading = true;
    notifyListeners();
    try {
      final rows = await TripApi.instance.listReady(from: from, to: to);
      remote = rows.map(fromApi).toList();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Safarlarni yuklab bo‘lmadi.';
    }
    loading = false;
    notifyListeners();
  }

  /// Server `trip` JSON'ini `TaxiOffer`ga aylantiradi — band qilish oqimida
  /// (`active_booking_service.dart`, `driver_trip_service.dart`) ham shu
  /// xaritalash qayta ishlatiladi, shuning uchun public/static.
  static TaxiOffer fromApi(Map<String, dynamic> j) {
    final photo = (j['car_photo'] as String?) ?? '';
    final driverPhoto = (j['driver_photo'] as String?) ?? '';
    final scheduled = DateTime.tryParse(j['scheduled_at']?.toString() ?? '');
    final time = scheduled == null
        ? ''
        : '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
    final rating = (j['driver_rating'] as num?)?.toDouble() ?? 5.0;
    return TaxiOffer(
      id: 'remote_${j['id']}',
      remoteTripId: j['id'] as int?,
      from: j['from_text'] as String? ?? '',
      to: j['to_text'] as String? ?? '',
      time: time,
      seats: j['seats_available'] as int? ?? 1,
      price: j['price'] as int? ?? 0,
      driverName: j['driver_name'] as String? ?? '',
      rating: rating <= 0 ? 5.0 : rating,
      reviews: j['driver_reviews'] as int? ?? 0,
      carModel: j['car_model'] as String? ?? '',
      plate: j['plate'] as String? ?? '',
      phone: j['driver_phone'] as String? ?? '',
      imageAsset: photo.isNotEmpty ? photo : 'assets/images/car_cobalt.png',
      driverPhoto: driverPhoto,
      driverUserId: j['driver_user_id'] as int?,
      period: TimeOfDayFilter.all,
      isOnline: j['driver_is_online'] as bool? ?? false,
      avgResponseSec: j['driver_avg_response_sec'] as int?,
    );
  }
}
