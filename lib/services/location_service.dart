import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../l10n/phrase.dart';
import 'package:geolocator/geolocator.dart';

/// Yo‘lovchi va haydovchi koordinatalari — taxminiy masofa uchun.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _karakalpakCenter = (lat: 41.6911, lng: 60.7525);

  double? passengerLat;
  double? passengerLng;
  final Map<String, ({double lat, double lng})> _driverCoords = {};
  final Set<String> _trackedDriverIds = {};
  Timer? _timer;
  bool _running = false;

  void registerDrivers(Iterable<String> taxiIds) {
    _trackedDriverIds
      ..clear()
      ..addAll(taxiIds);
    _refreshTrackedDrivers();
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _tick() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        passengerLat ??= _karakalpakCenter.lat;
        passengerLng ??= _karakalpakCenter.lng;
        notifyListeners();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      passengerLat = pos.latitude;
      passengerLng = pos.longitude;
      _refreshTrackedDrivers();
      notifyListeners();
    } catch (_) {
      passengerLat ??= _karakalpakCenter.lat;
      passengerLng ??= _karakalpakCenter.lng;
      _refreshTrackedDrivers();
      notifyListeners();
    }
  }

  void _refreshTrackedDrivers() {
    if (_trackedDriverIds.isEmpty) return;
    final t = DateTime.now().millisecondsSinceEpoch / 10000.0;
    for (final id in _trackedDriverIds) {
      final base = driverCoordFor(id, seed: id.hashCode);
      _driverCoords[id] = (
        lat: base.lat + math.sin(t + id.hashCode) * 0.002,
        lng: base.lng + math.cos(t + id.hashCode) * 0.002,
      );
    }
  }

  void setDriverCoord(String taxiId, {required double lat, required double lng}) {
    _driverCoords[taxiId] = (lat: lat, lng: lng);
    notifyListeners();
  }

  ({double lat, double lng}) driverCoordFor(String taxiId, {int seed = 0}) {
    final cached = _driverCoords[taxiId];
    if (cached != null) return cached;
    // Mock: har haydovchi uchun biroz farqli nuqta
    final r = seed.abs() % 1000 / 10000.0;
    return (lat: _karakalpakCenter.lat + r, lng: _karakalpakCenter.lng + r * 1.2);
  }

  double? distanceKmToDriver(String taxiId, {int seed = 0}) {
    final pLat = passengerLat;
    final pLng = passengerLng;
    if (pLat == null || pLng == null) return null;
    final d = driverCoordFor(taxiId, seed: seed);
    return _haversineKm(pLat, pLng, d.lat, d.lng);
  }

  String distanceLabel(String taxiId, {int seed = 0}) {
    final km = distanceKmToDriver(taxiId, seed: seed);
    if (km == null) return '—';
    if (km < 1) return '${(km * 1000).round()} ${tr('m uzoqlikda')}';
    return '${km.toStringAsFixed(1)} ${tr('km uzoqlikda')}';
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
