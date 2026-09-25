import 'dart:async';
import '../l10n/phrase.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import 'place_registry_service.dart';
import '../models/taxi_offer.dart';
import '../screens/booking/prebook_screen.dart';
import '../services/driver_trip_service.dart';
import '../services/profile_service.dart';
import '../services/trip_completion_service.dart';
import '../utils/eta_util.dart';

enum BookingKind { instant, prebook }

enum BookingStatus {
  waiting,
  driverFound,
  counterOffer,
  confirmed,
  onWay,
  pickedUp,
  completed,
  expired,
  cancelled,
}

class ActiveBooking {
  const ActiveBooking({
    required this.id,
    required this.kind,
    required this.status,
    required this.taxi,
    required this.seats,
    required this.from,
    required this.to,
    required this.createdAt,
    this.pickupLabel,
    this.prebook,
    this.etaArriveAt,
    this.driverEtaMinutes,
    this.offeredPrice,
    this.counterPrice,
    this.statusMessage,
  });

  final String id;
  final BookingKind kind;
  final BookingStatus status;
  final TaxiOffer taxi;
  final int seats;
  final String from;
  final String to;
  final DateTime createdAt;
  final String? pickupLabel;
  final PrebookRequest? prebook;
  final DateTime? etaArriveAt;
  final int? driverEtaMinutes;
  final int? offeredPrice;
  final int? counterPrice;
  final String? statusMessage;

  String get routeLabel => '$from → $to';

  String get statusTitle => switch (status) {
        BookingStatus.waiting => tr('Haydovchi kutilmoqda'),
        BookingStatus.driverFound => tr('Haydovchi topildi'),
        BookingStatus.counterOffer => tr('Qarshi narx taklifi'),
        BookingStatus.confirmed => tr('Safar tasdiqlandi'),
        BookingStatus.onWay => tr("Haydovchi yo'lda"),
        BookingStatus.pickedUp => tr('Yo‘lovchi olindi'),
        BookingStatus.completed => tr('Yakunlangan'),
        BookingStatus.expired => tr('So‘rov yopildi'),
        BookingStatus.cancelled => tr('Safar bekor qilindi'),
      };

  String get statusSubtitle {
    if (status == BookingStatus.onWay && etaArriveAt != null) {
      return EtaUtil.countdownLabel(etaArriveAt!);
    }
    return switch (status) {
      BookingStatus.waiting => tr("So'rov haydovchiga yuborildi — 1 soat kutish"),
      BookingStatus.driverFound => '${taxi.driverName} · ${taxi.plate}',
      BookingStatus.counterOffer =>
        counterPrice != null ? 'Haydovchi ${counterPrice!} so‘m taklif qildi' : tr('Narxni tasdiqlang'),
      BookingStatus.confirmed => '${taxi.driverName} · ${taxi.plate}',
      BookingStatus.onWay => taxi.etaLabel,
      BookingStatus.pickedUp => tr('Safarni yakunlash mumkin'),
      BookingStatus.completed => tr('Safar tugadi'),
      BookingStatus.expired => statusMessage ?? tr('Haydovchi javob bermadi'),
      BookingStatus.cancelled => statusMessage ?? tr('Safar bekor qilindi'),
    };
  }

  bool get isActive =>
      status != BookingStatus.completed &&
      status != BookingStatus.expired &&
      status != BookingStatus.cancelled;

  ActiveBooking copyWith({
    BookingStatus? status,
    TaxiOffer? taxi,
    int? seats,
    String? pickupLabel,
    PrebookRequest? prebook,
    DateTime? etaArriveAt,
    int? driverEtaMinutes,
    int? offeredPrice,
    int? counterPrice,
    String? statusMessage,
    bool clearEta = false,
    bool clearCounter = false,
  }) {
    return ActiveBooking(
      id: id,
      kind: kind,
      status: status ?? this.status,
      taxi: taxi ?? this.taxi,
      seats: seats ?? this.seats,
      from: from,
      to: to,
      createdAt: createdAt,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      prebook: prebook ?? this.prebook,
      etaArriveAt: clearEta ? null : (etaArriveAt ?? this.etaArriveAt),
      driverEtaMinutes: driverEtaMinutes ?? this.driverEtaMinutes,
      offeredPrice: clearCounter ? null : (offeredPrice ?? this.offeredPrice),
      counterPrice: clearCounter ? null : (counterPrice ?? this.counterPrice),
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'status': status.name,
        'seats': seats,
        'from': from,
        'to': to,
        'createdAt': createdAt.toIso8601String(),
        'pickupLabel': pickupLabel,
        'taxi': _taxiToJson(taxi),
        if (prebook != null) 'prebook': _prebookToJson(prebook!),
        if (etaArriveAt != null) 'etaArriveAt': etaArriveAt!.toIso8601String(),
        if (driverEtaMinutes != null) 'driverEtaMinutes': driverEtaMinutes,
        if (offeredPrice != null) 'offeredPrice': offeredPrice,
        if (counterPrice != null) 'counterPrice': counterPrice,
        if (statusMessage != null) 'statusMessage': statusMessage,
      };

  static ActiveBooking fromJson(Map<String, dynamic> json) {
    return ActiveBooking(
      id: json['id'] as String? ?? 'b_${json['createdAt']}',
      kind: BookingKind.values.byName(json['kind'] as String),
      status: BookingStatus.values.byName(json['status'] as String),
      seats: json['seats'] as int,
      from: json['from'] as String,
      to: json['to'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pickupLabel: json['pickupLabel'] as String?,
      taxi: _taxiFromJson(json['taxi'] as Map<String, dynamic>),
      prebook: json['prebook'] == null
          ? null
          : _prebookFromJson(json['prebook'] as Map<String, dynamic>),
      etaArriveAt: json['etaArriveAt'] == null
          ? null
          : DateTime.tryParse(json['etaArriveAt'] as String),
      driverEtaMinutes: json['driverEtaMinutes'] as int?,
      offeredPrice: json['offeredPrice'] as int?,
      counterPrice: json['counterPrice'] as int?,
      statusMessage: json['statusMessage'] as String?,
    );
  }

  static Map<String, dynamic> _taxiToJson(TaxiOffer t) => {
        'id': t.id,
        'from': t.from,
        'to': t.to,
        'time': t.time,
        'seats': t.seats,
        'price': t.price,
        'driverName': t.driverName,
        'rating': t.rating,
        'reviews': t.reviews,
        'carModel': t.carModel,
        'plate': t.plate,
        'phone': t.phone,
        'imageAsset': t.imageAsset,
        'period': t.period.name,
        'badge': t.badge,
        'etaMinutes': t.etaMinutes,
        'isOnline': t.isOnline,
        'fromAliases': t.fromAliases,
        'toAliases': t.toAliases,
      };

  static TaxiOffer _taxiFromJson(Map<String, dynamic> j) => TaxiOffer(
        id: j['id'] as String,
        from: j['from'] as String,
        to: j['to'] as String,
        time: j['time'] as String,
        seats: j['seats'] as int,
        price: j['price'] as int,
        driverName: j['driverName'] as String,
        rating: (j['rating'] as num).toDouble(),
        reviews: j['reviews'] as int,
        carModel: j['carModel'] as String,
        plate: j['plate'] as String,
        phone: j['phone'] as String,
        imageAsset: j['imageAsset'] as String,
        period: TimeOfDayFilter.values.byName(j['period'] as String),
        badge: j['badge'] as String?,
        etaMinutes: j['etaMinutes'] as int? ?? 12,
        isOnline: j['isOnline'] as bool? ?? true,
        fromAliases: (j['fromAliases'] as List?)?.cast<String>() ?? const [],
        toAliases: (j['toAliases'] as List?)?.cast<String>() ?? const [],
      );

  static Map<String, dynamic> _prebookToJson(PrebookRequest r) => {
        'from': r.from,
        'to': r.to,
        'exactPlace': r.exactPlace,
        'date': r.date.toIso8601String(),
        'hour': r.time.hour,
        'minute': r.time.minute,
        'passengers': r.passengers,
        'hasLuggage': r.hasLuggage,
        'note': r.note,
        'offeredPrice': r.offeredPrice,
      };

  static PrebookRequest _prebookFromJson(Map<String, dynamic> j) => PrebookRequest(
        from: j['from'] as String,
        to: j['to'] as String,
        exactPlace: j['exactPlace'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        time: TimeOfDay(hour: j['hour'] as int, minute: j['minute'] as int),
        passengers: j['passengers'] as int,
        hasLuggage: j['hasLuggage'] as bool? ?? false,
        note: j['note'] as String? ?? '',
        offeredPrice: j['offeredPrice'] as int? ?? 0,
      );
}

class ActiveBookingService extends ChangeNotifier {
  ActiveBookingService._();
  static final ActiveBookingService instance = ActiveBookingService._();

  static const _kKey = 'safaron_active_bookings_v3';
  static const _kLegacyV2 = 'safaron_active_bookings_v2';
  static const _kLegacy = 'safaron_active_booking';
  static const inactiveTimeout = Duration(hours: 5);

  List<ActiveBooking> bookings = [];
  Timer? _tickTimer;
  bool _loaded = false;

  List<ActiveBooking> get activeBookings =>
      bookings.where((b) => b.isActive).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ActiveBooking? get booking => activeBookings.isEmpty ? null : activeBookings.first;

  ActiveBooking? get instantBooking {
    final list = activeBookings.where((b) => b.kind == BookingKind.instant);
    return list.isEmpty ? null : list.first;
  }

  ActiveBooking? get prebookBooking {
    final list = activeBookings.where((b) => b.kind == BookingKind.prebook);
    return list.isEmpty ? null : list.first;
  }

  bool get hasActive => activeBookings.isNotEmpty;

  ActiveBooking? bookingOf(BookingKind kind) {
    final list = activeBookings.where((b) => b.kind == kind);
    return list.isEmpty ? null : list.first;
  }

  ActiveBooking? byId(String id) {
    try {
      return bookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  bool hasSameRoute(String from, String to) {
    final reg = PlaceRegistryService.instance;
    return activeBookings.any(
      (b) => reg.placesRelated(b.from, from) && reg.placesRelated(b.to, to),
    );
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        bookings = list.map((e) => ActiveBooking.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        bookings = [];
      }
    } else {
      await _migrateV2(prefs);
    }
    _armTick();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _migrateV2(SharedPreferences prefs) async {
    final raw = prefs.getString(_kLegacyV2);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map['instant'] != null) {
          final b = ActiveBooking.fromJson(map['instant'] as Map<String, dynamic>);
          bookings.add(b.copyWith());
        }
        if (map['prebook'] != null) {
          bookings.add(ActiveBooking.fromJson(map['prebook'] as Map<String, dynamic>));
        }
        // Fix missing ids from old format
        bookings = [
          for (final b in bookings)
            ActiveBooking(
              id: b.id.startsWith('b_') || b.id.isNotEmpty ? (b.id.contains('_') ? b.id : 'b_${b.createdAt.millisecondsSinceEpoch}') : 'b_${b.createdAt.millisecondsSinceEpoch}',
              kind: b.kind,
              status: b.status,
              taxi: b.taxi,
              seats: b.seats,
              from: b.from,
              to: b.to,
              createdAt: b.createdAt,
              pickupLabel: b.pickupLabel,
              prebook: b.prebook,
            ),
        ];
        await _persist();
        await prefs.remove(_kLegacyV2);
        return;
      } catch (_) {}
    }
    final legacy = prefs.getString(_kLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        bookings = [ActiveBooking.fromJson(jsonDecode(legacy) as Map<String, dynamic>)];
        await prefs.remove(_kLegacy);
        await _persist();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(bookings.map((e) => e.toJson()).toList()));
  }

  void _armTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // ignore: unawaited_futures
      _expireInactiveInstant();
      if (bookings.any((b) => b.status == BookingStatus.onWay && b.etaArriveAt != null)) {
        notifyListeners();
      }
    });
  }

  Future<void> _expireInactiveInstant() async {
    final now = DateTime.now();
    var changed = false;
    bookings = [
      for (final b in bookings)
        if (b.kind == BookingKind.instant &&
            b.isActive &&
            b.status != BookingStatus.waiting &&
            b.createdAt.add(inactiveTimeout).isBefore(now))
          () {
            changed = true;
            // ignore: unawaited_futures
            DriverTripService.instance.expireOrderInactive(b.id);
            return b.copyWith(
              status: BookingStatus.expired,
              statusMessage: 'Safar 5 soat davomida faol bo‘lmagani uchun avtomatik yopildi.',
            );
          }()
        else
          b,
    ];
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  /// Bir yo‘nalishda parallel bron yo‘q. Turli yo‘nalishlarda bir nechta mumkin.
  Future<String?> startInstant({
    required TaxiOffer taxi,
    required int seats,
    String? pickupLabel,
    bool force = false,
  }) async {
    if (!force && hasSameRoute(taxi.from, taxi.to)) {
      return 'Bu yo‘nalishda allaqachon faol bron bor';
    }
    final id = 'inst_${DateTime.now().millisecondsSinceEpoch}';
    bookings = [
      ActiveBooking(
        id: id,
        kind: BookingKind.instant,
        status: BookingStatus.waiting,
        taxi: taxi,
        seats: seats,
        from: taxi.from,
        to: taxi.to,
        createdAt: DateTime.now(),
        pickupLabel: pickupLabel ?? taxi.from,
        offeredPrice: taxi.price,
      ),
      ...bookings,
    ];
    await _persist();
    // ignore: unawaited_futures
    DriverTripService.instance.pushFromPassengerBooking(
      from: taxi.from,
      to: taxi.to,
      passengers: seats,
      exactPickup: pickupLabel ?? '',
      offeredPrice: taxi.price,
      targetTaxiId: taxi.id,
      bookingId: id,
    );
    notifyListeners();
    return null;
  }

  Future<String?> startPrebook({
    required PrebookRequest request,
    TaxiOffer? taxi,
    int? remoteRequestId,
  }) async {
    if (hasSameRoute(request.from, request.to)) {
      return 'Bu yo‘nalishda allaqachon faol bron bor';
    }
    final id = remoteRequestId != null
        ? 'req_$remoteRequestId'
        : 'pre_${DateTime.now().millisecondsSinceEpoch}';
    bookings = [
      ActiveBooking(
        id: id,
        kind: BookingKind.prebook,
        status: BookingStatus.waiting,
        taxi: taxi ??
            TaxiOffer(
              id: id,
              from: request.from,
              to: request.to,
              time: request.timeLabel,
              seats: request.passengers,
              price: request.offeredPrice,
              driverName: '—',
              rating: 0,
              reviews: 0,
              carModel: '—',
              plate: '—',
              phone: '',
              imageAsset: 'assets/images/car_cobalt.png',
              period: TimeOfDayFilter.all,
            ),
        seats: request.passengers,
        from: request.from,
        to: request.to,
        createdAt: DateTime.now(),
        pickupLabel: request.exactPlace.isEmpty
            ? request.from
            : '${request.from} · ${request.exactPlace}',
        prebook: request,
      ),
      ...bookings,
    ];
    await _persist();
    // ignore: unawaited_futures
    DriverTripService.instance.pushFromPassengerBooking(
      from: request.from,
      to: request.to,
      passengers: request.passengers,
      exactPickup: request.exactPlace,
      prebook: true,
      dateLabel: request.dateLabel,
      timeLabel: request.timeLabel,
      offeredPrice: request.offeredPrice,
      targetTaxiId: taxi?.id ?? id,
      bookingId: id,
    );
    notifyListeners();
    return null;
  }

  Future<void> setCounterOffer({
    required String bookingId,
    required TaxiOffer taxi,
    required int counterPrice,
    required int offeredPrice,
  }) async {
    bookings = [
      for (final b in bookings)
        if (b.id == bookingId)
          b.copyWith(
            status: BookingStatus.counterOffer,
            taxi: taxi,
            counterPrice: counterPrice,
            offeredPrice: offeredPrice,
          )
        else
          b,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> setDriverAccepted({
    required String bookingId,
    required TaxiOffer taxi,
    int? etaMinutes,
  }) async {
    final arrive = etaMinutes == null ? null : DateTime.now().add(Duration(minutes: etaMinutes));
    bookings = [
      for (final b in bookings)
        if (b.id == bookingId)
          b.copyWith(
            status: etaMinutes == null ? BookingStatus.confirmed : BookingStatus.onWay,
            taxi: taxi,
            etaArriveAt: arrive,
            driverEtaMinutes: etaMinutes,
            clearCounter: true,
          )
        else
          b,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> markCancelled({
    required String bookingId,
    required String reason,
    required String cancelledBy,
    BookingKind? kind,
  }) async {
    final message = reason.isEmpty ? tr('Safar bekor qilindi') : reason;
    bool hit(ActiveBooking b) {
      if (b.id == bookingId) return true;
      if (kind != null && b.kind == kind && b.isActive && bookingId.isEmpty) return true;
      return false;
    }
    var matched = bookings.any(hit);
    bookings = [
      for (final b in bookings)
        if (hit(b)) b.copyWith(status: BookingStatus.cancelled, statusMessage: message) else b,
    ];
    if (!matched && kind != null) {
      bookings = [
        for (final b in bookings)
          if (b.kind == kind && b.isActive)
            b.copyWith(status: BookingStatus.cancelled, statusMessage: message)
          else
            b,
      ];
    }
    await _persist();
    notifyListeners();
  }

  Future<void> markExpired(String bookingId, {required String message}) async {
    bookings = [
      for (final b in bookings)
        if (b.id == bookingId)
          b.copyWith(status: BookingStatus.expired, statusMessage: message)
        else
          b,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> setStatus(
    BookingStatus status, {
    TaxiOffer? taxi,
    BookingKind? kind,
    String? bookingId,
    DateTime? etaArriveAt,
    int? driverEtaMinutes,
  }) async {
    final id = bookingId ??
        (kind == null ? booking?.id : bookingOf(kind)?.id);
    if (id == null) return;
    bookings = [
      for (final b in bookings)
        if (b.id == id)
          b.copyWith(
            status: status,
            taxi: taxi,
            etaArriveAt: etaArriveAt,
            driverEtaMinutes: driverEtaMinutes,
          )
        else
          b,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> setDriverEta(String bookingId, int minutes) async {
    final arrive = DateTime.now().add(Duration(minutes: minutes));
    await setStatus(
      BookingStatus.onWay,
      bookingId: bookingId,
      etaArriveAt: arrive,
      driverEtaMinutes: minutes,
    );
  }

  Future<void> markPickedUp(String bookingId) async {
    bookings = [
      for (final b in bookings)
        if (b.id == bookingId) b.copyWith(status: BookingStatus.pickedUp, clearEta: true) else b,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> markBookingCompleted(String bookingId) async {
    bookings = [
      for (final b in bookings)
        if (b.id == bookingId) b.copyWith(status: BookingStatus.completed) else b,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> complete(
    String bookingId, {
    TripCompletedBy completedBy = TripCompletedBy.passenger,
    bool driverRatedPassenger = false,
    bool passengerRatedDriver = false,
  }) async {
    final booking = byId(bookingId);
    await markBookingCompleted(bookingId);
    if (booking != null) {
      await TripCompletionService.instance.recordCompletion(
        bookingId: bookingId,
        from: booking.from,
        to: booking.to,
        price: booking.taxi.price,
        completedBy: completedBy,
        passengerName: ProfileService.instance.fullName.isEmpty
            ? tr('Yo‘lovchi')
            : ProfileService.instance.fullName,
        driverName: booking.taxi.driverName,
        driverRatedPassenger: driverRatedPassenger,
        passengerRatedDriver: passengerRatedDriver,
      );
      final order = DriverTripService.instance.orderById(bookingId);
      if (order != null && order.status != PassengerOrderStatus.done) {
        await DriverTripService.instance.markOrderDone(bookingId);
      }
    }
    notifyListeners();
  }

  Future<void> clear({BookingKind? kind, String? bookingId}) async {
    if (bookingId != null) {
      bookings = [
        for (final b in bookings)
          if (b.id == bookingId) b.copyWith(status: BookingStatus.completed) else b,
      ];
    } else if (kind == null) {
      bookings = [
        for (final b in bookings) b.copyWith(status: BookingStatus.completed),
      ];
    } else {
      bookings = [
        for (final b in bookings)
          if (b.kind == kind && b.isActive) b.copyWith(status: BookingStatus.completed) else b,
      ];
    }
    await _persist();
    notifyListeners();
  }
}
