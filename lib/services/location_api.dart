import 'api_client.dart';

class LocationItem {
  LocationItem({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.latitude,
    this.longitude,
    this.aliases = const [],
  });

  final int id;
  final String name;
  final String type;
  final String? description;
  final double? latitude;
  final double? longitude;
  final List<String> aliases;

  factory LocationItem.fromJson(Map<String, dynamic> j) => LocationItem(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'other',
        description: j['description'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        aliases: (j['aliases'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class LocationApi {
  LocationApi._();
  static final LocationApi instance = LocationApi._();

  Future<List<LocationItem>> search(String? q) async {
    final data = await ApiClient.instance.get('/api/locations', query: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    });
    return (data as List).map((e) => LocationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LocationItem> suggest({
    required String name,
    String type = 'other',
    String? description,
    List<String> aliases = const [],
  }) async {
    final data = await ApiClient.instance.post('/api/locations', body: {
      'name': name,
      'type': type,
      if (description != null) 'description': description,
      'aliases': aliases,
    });
    return LocationItem.fromJson(data as Map<String, dynamic>);
  }
}
