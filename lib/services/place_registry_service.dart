import 'dart:convert';
import '../l10n/phrase.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/place_aliases.dart' as aliases;
import '../models/place_record.dart';
import '../utils/distance_util.dart';
import 'location_api.dart';

/// Admin joylari — qidiruv, koordinata va yo‘l masofasi.
class PlaceRegistryService extends ChangeNotifier {
  PlaceRegistryService._();
  static final PlaceRegistryService instance = PlaceRegistryService._();

  static const _cacheKey = 'safaron_places_cache_v1';

  /// Offline / dastlabki joylar (admin API bo‘lmasa ham ishlaydi).
  static const List<PlaceRecord> _defaults = [
    PlaceRecord(
      id: 1,
      name: 'Beruniy',
      type: 'city',
      latitude: 41.6911,
      longitude: 60.7525,
      aliases: ['Beruniy shahar', 'Beruniy markazi', 'Беруний', 'Beruniy tumani', 'Hokimiyat', 'Beruniy balnitsa'],
    ),
    PlaceRecord(
      id: 2,
      name: 'Boston',
      type: 'village',
      latitude: 41.652,
      longitude: 60.81,
      aliases: ['boston', 'Бoston', 'Boston mahalla'],
    ),
    PlaceRecord(
      id: 3,
      name: 'Algabas',
      type: 'mahalla',
      latitude: 41.778,
      longitude: 60.648,
      aliases: ['Alg‘abas', 'Алғабас', 'Algabas OFY'],
    ),
    PlaceRecord(
      id: 4,
      name: 'Qizil qala',
      type: 'village',
      latitude: 41.848,
      longitude: 60.618,
      aliases: ['Qizilqala', 'Qizil qala OFY', 'Қизил қалъа', 'Sadvin', 'Algabas yo‘li'],
    ),
  ];

  List<PlaceRecord> _places = List.of(_defaults);
  bool _loaded = false;

  List<PlaceRecord> get places => List.unmodifiable(_places);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _places = list.map((e) => PlaceRecord.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _places = List.of(_defaults);
      }
    }
    _loaded = true;
    notifyListeners();
    // ignore: unawaited_futures
    _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    try {
      final remote = await LocationApi.instance.search(null);
      if (remote.isEmpty) return;
      final merged = <int, PlaceRecord>{};
      for (final p in _defaults) {
        merged[p.id] = p;
      }
      for (final item in remote) {
        merged[item.id] = PlaceRecord(
          id: item.id,
          name: item.name,
          type: item.type,
          latitude: item.latitude ?? merged[item.id]?.latitude,
          longitude: item.longitude ?? merged[item.id]?.longitude,
          aliases: item.aliases,
        );
      }
      _places = merged.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_places.map((e) => e.toJson()).toList()));
      notifyListeners();
    } catch (_) {
      // Offline — defaults/cache yetarli
    }
  }

  /// Til va yozuvdan qat’i nazar qidirish (aliaslar bilan).
  List<PlaceRecord> search(String query, {int limit = 8}) {
    final q = aliases.normalizePlace(query);
    if (q.isEmpty) return _places.take(limit).toList();

    final scored = <({PlaceRecord place, int score})>[];
    for (final p in _places) {
      var best = _matchScore(aliases.normalizePlace(p.name), q);
      for (final a in p.aliases) {
        best = mathMax(best, _matchScore(aliases.normalizePlace(a), q));
      }
      if (best > 0) scored.add((place: p, score: best));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.place).toList();
  }

  int _matchScore(String candidate, String query) {
    if (candidate.isEmpty || query.isEmpty) return 0;
    if (candidate == query) return 100;
    if (candidate.startsWith(query)) return 80;
    if (candidate.contains(query)) return 60;
    if (query.contains(candidate) && candidate.length >= 3) return 50;
    return 0;
  }

  int mathMax(int a, int b) => a > b ? a : b;

  PlaceRecord? resolve(String text) {
    final q = aliases.normalizePlace(text);
    if (q.isEmpty) return null;
    PlaceRecord? best;
    var bestScore = 0;
    for (final p in _places) {
      for (final term in p.allNames) {
        final score = _matchScore(aliases.normalizePlace(term), q);
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
    }
    return bestScore >= 50 ? best : null;
  }

  String canonicalName(String text) => resolve(text)?.name ?? text.trim();

  bool matches(String place, String query) {
    final q = aliases.normalizePlace(query);
    if (q.isEmpty) return true;
    final resolved = resolve(place);
    if (resolved != null) {
      for (final term in resolved.allNames) {
        if (_matchScore(aliases.normalizePlace(term), q) > 0) return true;
      }
    }
    return _matchScore(aliases.normalizePlace(place), q) > 0;
  }

  bool placesRelated(String a, String b) {
    final pa = resolve(a);
    final pb = resolve(b);
    if (pa != null && pb != null) return pa.id == pb.id;
    final na = aliases.normalizePlace(a);
    final nb = aliases.normalizePlace(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    return aliases.placesRelated(a, b);
  }

  PlaceRecord? nearest(double lat, double lng, {double maxKm = 4}) {
    PlaceRecord? best;
    var bestKm = maxKm;
    for (final p in _places) {
      if (!p.hasCoords) continue;
      final km = DistanceUtil.haversineKm(lat, lng, p.latitude!, p.longitude!);
      if (km <= bestKm) {
        bestKm = km;
        best = p;
      }
    }
    return best;
  }

  MapPickResult resolveMapPick(double lat, double lng) {
    final near = nearest(lat, lng);
    if (near != null) {
      return MapPickResult(
        label: near.name,
        latitude: lat,
        longitude: lng,
        locationId: near.id,
      );
    }
    return MapPickResult(
      label: PlaceSelection.otherLabel,
      latitude: lat,
      longitude: lng,
      isCustom: true,
    );
  }

  ({double? lat, double? lng}) coordsFor(String name) {
    final p = resolve(name);
    if (p?.hasCoords == true) return (lat: p!.latitude, lng: p.longitude);
    return (lat: null, lng: null);
  }

  double? routeKm({
    String? fromName,
    String? toName,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
  }) {
    final fLat = fromLat ?? coordsFor(fromName ?? '').lat;
    final fLng = fromLng ?? coordsFor(fromName ?? '').lng;
    final tLat = toLat ?? coordsFor(toName ?? '').lat;
    final tLng = toLng ?? coordsFor(toName ?? '').lng;
    if (fLat == null || fLng == null || tLat == null || tLng == null) return null;
    return DistanceUtil.haversineKm(fLat, fLng, tLat, tLng);
  }

  String routeDistanceLabel({
    String? fromName,
    String? toName,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
  }) {
    final km = routeKm(
      fromName: fromName,
      toName: toName,
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
    if (km == null) return '';
    return DistanceUtil.formatKm(km);
  }

  PlaceSelection selectionFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const PlaceSelection(displayName: '');
    if (trimmed == PlaceSelection.otherLabel) {
      return const PlaceSelection(displayName: PlaceSelection.otherLabel, isCustom: true);
    }
    final p = resolve(trimmed);
    if (p != null) {
      return PlaceSelection(
        displayName: p.name,
        locationId: p.id,
        latitude: p.latitude,
        longitude: p.longitude,
      );
    }
    return PlaceSelection(displayName: trimmed, isCustom: true);
  }
}
