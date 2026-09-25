import '../models/taxi_offer.dart';
import '../services/driver_exclusion_service.dart';
import '../services/driver_trip_service.dart';
import '../services/location_service.dart';
import '../services/place_registry_service.dart';
import '../utils/distance_util.dart';

List<TaxiOffer> allCatalogTaxis() {
  return DriverTripService.instance.publishedCatalogOffers();
}

List<TaxiOffer> mockTaxisFor({
  required String from,
  required String to,
  required int passengers,
  int dateMode = 0,
  TimeOfDayFilter timeFilter = TimeOfDayFilter.all,
}) {
  return allCatalogTaxis().where((taxi) {
    if (DriverExclusionService.instance.isExcluded(taxi.id)) return false;
    if (taxi.seats < passengers) return false;
    if (timeFilter != TimeOfDayFilter.all && taxi.period != timeFilter) {
      return false;
    }
    if (!taxi.isOpenTrip && !taxi.matchesRoute(fromQuery: from, toQuery: to)) return false;
    return true;
  }).map((taxi) {
    final f = from.trim().isEmpty ? taxi.from : from.trim();
    final t = to.trim().isEmpty ? taxi.to : to.trim();
    final routeKm = PlaceRegistryService.instance.routeDistanceLabel(fromName: f, toName: t);
    return taxi.copyWith(from: f, to: t, distance: routeKm);
  }).toList()
    ..sort((a, b) => _byNearest(a, b, nearName: from));
}

/// Katalog: onlaynlar oldinda, keyin oflayn. Qidiruv matni bo‘yicha filtr.
List<TaxiOffer> catalogTaxis({
  OnlineFilter filter = OnlineFilter.all,
  String query = '',
}) {
  final list = allCatalogTaxis()
      .where((t) => !DriverExclusionService.instance.isExcluded(t.id))
      .where((t) {
        return switch (filter) {
          OnlineFilter.all => true,
          OnlineFilter.online => t.isOnline,
          OnlineFilter.offline => !t.isOnline,
        };
      })
      .where((t) => t.matchesSearch(query))
      .toList()
    ..sort((a, b) => _byNearest(a, b, nearName: query));
  return list;
}

int _byNearest(TaxiOffer a, TaxiOffer b, {String nearName = ''}) {
  final da = _kmTo(a, nearName);
  final db = _kmTo(b, nearName);
  if ((da - db).abs() > 0.05) return da.compareTo(db);
  if (a.isOnline == b.isOnline) return a.driverName.compareTo(b.driverName);
  return a.isOnline ? -1 : 1;
}

double _kmTo(TaxiOffer taxi, String nearName) {
  final loc = LocationService.instance;
  final driver = loc.driverCoordFor(taxi.id, seed: taxi.id.hashCode);
  final named = nearName.trim().isEmpty ? null : PlaceRegistryService.instance.coordsFor(nearName.trim());
  if (named != null && named.lat != null && named.lng != null) {
    return DistanceUtil.haversineKm(named.lat!, named.lng!, driver.lat, driver.lng);
  }
  return loc.distanceKmToDriver(taxi.id, seed: taxi.id.hashCode) ?? 9999;
}

enum OnlineFilter { all, online, offline }
