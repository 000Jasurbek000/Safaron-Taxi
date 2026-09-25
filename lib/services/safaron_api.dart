import 'api_client.dart';

class TripRequestDto {
  TripRequestDto(this.raw);
  final Map<String, dynamic> raw;

  int get id => raw['id'] as int;
  String get status => raw['status'] as String? ?? '';
  String get fromText => raw['from_text'] as String? ?? '';
  String get toText => raw['to_text'] as String? ?? '';
  String get exactPlace => raw['exact_place'] as String? ?? '';
  int get offeredPrice => raw['offered_price'] as int? ?? 0;
  int? get agreedPrice => raw['agreed_price'] as int?;
  int get passengersCount => raw['passengers_count'] as int? ?? 1;
  bool get hasLuggage => raw['has_luggage'] as bool? ?? false;
  String? get note => raw['note'] as String?;
  int? get selectedDriverId => raw['selected_driver_id'] as int?;
  List<Map<String, dynamic>> get responses =>
      ((raw['responses'] as List?) ?? const []).cast<Map<String, dynamic>>();

  String get routeLabel => '$fromText → $toText';
}

class RequestApi {
  RequestApi._();
  static final RequestApi instance = RequestApi._();

  Future<TripRequestDto> create({
    required String fromText,
    required String toText,
    required DateTime scheduledAt,
    required int passengersCount,
    required int offeredPrice,
    String? exactPlace,
    bool hasLuggage = false,
    String? note,
    int? fromLocationId,
    int? toLocationId,
  }) async {
    final data = await ApiClient.instance.post('/api/requests', body: {
      'from_text': fromText,
      'to_text': toText,
      'scheduled_at': scheduledAt.toIso8601String(),
      'passengers_count': passengersCount,
      'offered_price': offeredPrice,
      'has_luggage': hasLuggage,
      if (exactPlace != null) 'exact_place': exactPlace,
      if (note != null) 'note': note,
      if (fromLocationId != null) 'from_location_id': fromLocationId,
      if (toLocationId != null) 'to_location_id': toLocationId,
    });
    return TripRequestDto(data as Map<String, dynamic>);
  }

  Future<TripRequestDto> get(int id) async {
    final data = await ApiClient.instance.get('/api/requests/$id');
    return TripRequestDto(data as Map<String, dynamic>);
  }

  Future<List<TripRequestDto>> mine() async {
    final data = await ApiClient.instance.get('/api/requests/mine');
    return (data as List).map((e) => TripRequestDto(e as Map<String, dynamic>)).toList();
  }

  Future<List<TripRequestDto>> inbox() async {
    final data = await ApiClient.instance.get('/api/requests/inbox');
    return (data as List).map((e) => TripRequestDto(e as Map<String, dynamic>)).toList();
  }

  Future<TripRequestDto> respond(int id, {required String action, int? offeredPrice}) async {
    final data = await ApiClient.instance.post('/api/requests/$id/respond', body: {
      'action': action,
      if (offeredPrice != null) 'offered_price': offeredPrice,
    });
    return TripRequestDto(data as Map<String, dynamic>);
  }

  Future<TripRequestDto> select(int id, int driverId) async {
    final data = await ApiClient.instance.post('/api/requests/$id/select', body: {'driver_id': driverId});
    return TripRequestDto(data as Map<String, dynamic>);
  }

  Future<void> cancel(int id, String reason) async {
    await ApiClient.instance.post('/api/requests/$id/cancel', body: {'reason': reason});
  }

  Future<TripRequestDto> setStatus(int id, String status) async {
    final data = await ApiClient.instance.post('/api/requests/$id/status', body: {'status': status});
    return TripRequestDto(data as Map<String, dynamic>);
  }
}

class TripApi {
  TripApi._();
  static final TripApi instance = TripApi._();

  Future<List<Map<String, dynamic>>> listReady({String? from, String? to}) async {
    final data = await ApiClient.instance.get('/api/trips', query: {
      if (from != null && from.isNotEmpty) 'from_q': from,
      if (to != null && to.isNotEmpty) 'to_q': to,
    });
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final data = await ApiClient.instance.post('/api/trips', body: body);
    return data as Map<String, dynamic>;
  }

  Future<void> book(int tripId, {int seats = 1}) async {
    await ApiClient.instance.post('/api/trips/$tripId/book', body: {'seats': seats});
  }

  Future<List<Map<String, dynamic>>> mine() async {
    final data = await ApiClient.instance.get('/api/trips/mine');
    return (data as List).cast<Map<String, dynamic>>();
  }
}

class DriverApi {
  DriverApi._();
  static final DriverApi instance = DriverApi._();

  Future<void> setOnline(bool online) async {
    await ApiClient.instance.post('/api/drivers/online', body: {'is_online': online});
  }

  Future<void> heartbeat() async {
    await ApiClient.instance.post('/api/drivers/heartbeat', body: {});
  }

  Future<Map<String, dynamic>> earnings() async {
    final data = await ApiClient.instance.get('/api/drivers/me/earnings');
    return data as Map<String, dynamic>;
  }
}

class NotificationApi {
  NotificationApi._();
  static final NotificationApi instance = NotificationApi._();

  Future<List<Map<String, dynamic>>> list() async {
    final data = await ApiClient.instance.get('/api/notifications');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<int> unreadCount() async {
    final data = await ApiClient.instance.get('/api/notifications/unread-count');
    return (data as Map)['count'] as int? ?? 0;
  }
}
