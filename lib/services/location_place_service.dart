import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// GPS + reverse geocode → viloyat / tuman sarlavhasi.
class LocationPlaceService extends ChangeNotifier {
  LocationPlaceService._();
  static final LocationPlaceService instance = LocationPlaceService._();

  String regionLabel = 'Joylashuv aniqlanmoqda...';
  String districtLabel = '';
  bool loading = false;
  bool denied = false;

  Future<void> ensure() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        denied = true;
        regionLabel = 'Joylashuv ruxsati kerak';
        districtLabel = 'Sozlamalardan yoqing';
        return;
      }
      denied = false;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final place = await _reverse(pos.latitude, pos.longitude);
      regionLabel = place.$1;
      districtLabel = place.$2;
    } catch (_) {
      regionLabel = 'Joylashuv topilmadi';
      districtLabel = 'Qayta urinib ko‘ring';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<(String, String)> _reverse(double lat, double lon) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&accept-language=uz',
    );
    final res = await http.get(uri, headers: {'User-Agent': 'SAFARON/1.0'});
    if (res.statusCode != 200) {
      return ('Joylashuv', '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final addr = (json['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final region = (addr['state'] ??
            addr['region'] ??
            addr['province'] ??
            addr['county'] ??
            'O‘zbekiston')
        .toString();
    final district = (addr['county'] ??
            addr['city_district'] ??
            addr['municipality'] ??
            addr['town'] ??
            addr['city'] ??
            addr['village'] ??
            addr['suburb'] ??
            '')
        .toString();
    return (region, district);
  }
}
