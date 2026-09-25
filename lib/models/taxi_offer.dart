import '../data/place_aliases.dart';
import '../services/place_registry_service.dart';

enum TimeOfDayFilter { all, morning, day, evening }

class TaxiOffer {
  const TaxiOffer({
    required this.id,
    required this.from,
    required this.to,
    required this.time,
    required this.seats,
    required this.price,
    required this.driverName,
    required this.rating,
    required this.reviews,
    required this.carModel,
    required this.plate,
    required this.phone,
    required this.imageAsset,
    required this.period,
    this.badge,
    this.duration = '',
    this.distance = '',
    this.prebookOnly = false,
    this.etaMinutes = 12,
    this.isOnline = true,
    this.fromAliases = const [],
    this.toAliases = const [],
  });

  final String id;
  final String from;
  final String to;
  final String time;
  final int seats;
  final int price;
  final String driverName;
  final double rating;
  final int reviews;
  final String carModel;
  final String plate;
  final String phone;
  final String imageAsset;
  final TimeOfDayFilter period;
  final String? badge;
  final String duration;
  final String distance;
  final bool prebookOnly;
  final int etaMinutes;
  final bool isOnline;

  /// Asosiy [from] dan tashqari yaqin / qo‘shimcha chiqish nuqtalari.
  final List<String> fromAliases;

  /// Asosiy [to] dan tashqari boradigan manzillar (batafsilda ko‘rinadi).
  final List<String> toAliases;

  List<String> get allFromPlaces => [from, ...fromAliases];
  List<String> get allToPlaces => [to, ...toAliases];

  bool get isOpenTrip =>
      (from.isEmpty && to.isEmpty) ||
      from == 'Har qayerdan' ||
      to == 'Har qayerga';

  String get extraDestinationsLabel {
    if (toAliases.isEmpty) return '';
    return '+${toAliases.length} yo‘nalish';
  }

  String get etaLabel => 'Taxminan $etaMinutes daqiqada keladi';

  String get priceLabel {
    final raw = price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final fromEnd = raw.length - i;
      buf.write(raw[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return "${buf.toString()} so'm";
  }

  String get shortCar => carModel.split(' ').last;

  bool matchesSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    final reg = PlaceRegistryService.instance;
    if (allFromPlaces.any((p) => reg.matches(p, q))) return true;
    if (allToPlaces.any((p) => reg.matches(p, q))) return true;
    if (reg.matches(driverName, q)) return true;
    if (normalizePlace(plate).contains(normalizePlace(q))) return true;
    return false;
  }

  bool matchesRoute({required String fromQuery, required String toQuery}) {
    final reg = PlaceRegistryService.instance;
    final fOk = fromQuery.trim().isEmpty || allFromPlaces.any((p) => reg.matches(p, fromQuery));
    final tOk = toQuery.trim().isEmpty || allToPlaces.any((p) => reg.matches(p, toQuery));
    return fOk && tOk;
  }

  TaxiOffer copyWith({
    String? from,
    String? to,
    int? price,
    bool? isOnline,
    String? distance,
    List<String>? fromAliases,
    List<String>? toAliases,
  }) {
    return TaxiOffer(
      id: id,
      from: from ?? this.from,
      to: to ?? this.to,
      time: time,
      seats: seats,
      price: price ?? this.price,
      driverName: driverName,
      rating: rating,
      reviews: reviews,
      carModel: carModel,
      plate: plate,
      phone: phone,
      imageAsset: imageAsset,
      period: period,
      badge: badge,
      duration: duration,
      distance: distance ?? this.distance,
      prebookOnly: prebookOnly,
      etaMinutes: etaMinutes,
      isOnline: isOnline ?? this.isOnline,
      fromAliases: fromAliases ?? this.fromAliases,
      toAliases: toAliases ?? this.toAliases,
    );
  }
}
