import 'dart:math' as math;

class DistanceUtil {
  DistanceUtil._();

  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String formatKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static String routeLabel({double? fromLat, double? fromLng, double? toLat, double? toLng}) {
    if (fromLat == null || fromLng == null || toLat == null || toLng == null) return '';
    final km = haversineKm(fromLat, fromLng, toLat, toLng);
    return formatKm(km);
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
