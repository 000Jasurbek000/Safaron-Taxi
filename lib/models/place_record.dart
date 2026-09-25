/// Admin yoki tizim tomonidan belgilangan manzil.
class PlaceRecord {
  const PlaceRecord({
    required this.id,
    required this.name,
    required this.type,
    this.latitude,
    this.longitude,
    this.aliases = const [],
  });

  final int id;
  final String name;
  final String type;
  final double? latitude;
  final double? longitude;
  final List<String> aliases;

  bool get hasCoords => latitude != null && longitude != null;

  List<String> get allNames => [name, ...aliases];

  PlaceRecord copyWith({
    int? id,
    String? name,
    String? type,
    double? latitude,
    double? longitude,
    List<String>? aliases,
  }) {
    return PlaceRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      aliases: aliases ?? this.aliases,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'aliases': aliases,
      };

  factory PlaceRecord.fromJson(Map<String, dynamic> j) => PlaceRecord(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'other',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        aliases: (j['aliases'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

}

/// Foydalanuvchi tanlagan manzil (ro‘yxat, xarita yoki qo‘lda).
class PlaceSelection {
  const PlaceSelection({
    required this.displayName,
    this.locationId,
    this.latitude,
    this.longitude,
    this.isCustom = false,
  });

  final String displayName;
  final int? locationId;
  final double? latitude;
  final double? longitude;
  final bool isCustom;

  bool get hasCoords => latitude != null && longitude != null;

  static const otherLabel = 'Boshqa manzil';

  PlaceSelection copyWith({
    String? displayName,
    int? locationId,
    double? latitude,
    double? longitude,
    bool? isCustom,
  }) {
    return PlaceSelection(
      displayName: displayName ?? this.displayName,
      locationId: locationId ?? this.locationId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class MapPickResult {
  const MapPickResult({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.locationId,
    this.isCustom = false,
  });

  final String label;
  final double latitude;
  final double longitude;
  final int? locationId;
  final bool isCustom;

  PlaceSelection toSelection() => PlaceSelection(
        displayName: label,
        locationId: locationId,
        latitude: latitude,
        longitude: longitude,
        isCustom: isCustom,
      );
}
