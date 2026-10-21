import 'dart:async';
import '../l10n/phrase.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import 'place_registry_service.dart';
import '../models/taxi_offer.dart';
import '../screens/booking/prebook_screen.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/driver_trip_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/safaron_api.dart';
import '../services/trip_catalog_service.dart';
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
        'driverPhoto': t.driverPhoto,
        if (t.driverUserId != null) 'driverUserId': t.driverUserId,
        if (t.remoteTripId != null) 'remoteTripId': t.remoteTripId,
        'period': t.period.name,
        'badge': t.badge,
        'duration': t.duration,
        'distance': t.distance,
        'prebookOnly': t.prebookOnly,
        'etaMinutes': t.etaMinutes,
        'isOnline': t.isOnline,
        'fromAliases': t.fromAliases,
        'toAliases': t.toAliases,
        if (t.avgResponseSec != null) 'avgResponseSec': t.avgResponseSec,
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
        driverPhoto: j['driverPhoto'] as String? ?? '',
        driverUserId: j['driverUserId'] as int?,
        remoteTripId: j['remoteTripId'] as int?,
        period: TimeOfDayFilter.values.byName(j['period'] as String),
        badge: j['badge'] as String?,
        duration: j['duration'] as String? ?? '',
        distance: j['distance'] as String? ?? '',
        prebookOnly: j['prebookOnly'] as bool? ?? false,
        etaMinutes: j['etaMinutes'] as int? ?? 12,
        isOnline: j['isOnline'] as bool? ?? true,
        fromAliases: (j['fromAliases'] as List?)?.cast<String>() ?? const [],
        toAliases: (j['toAliases'] as List?)?.cast<String>() ?? const [],
        avgResponseSec: j['avgResponseSec'] as int?,
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

  /// Hisobdan chiqishda — bu qurilmadagi keyingi foydalanuvchi oldingisining
  /// faol bronlarini ko‘rmasligi uchun.
  Future<void> clearForLogout() async {
    bookings = [];
    await _persist();
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

  Timer? _fastPollTimer;

  void _armTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // ignore: unawaited_futures
      _expireInactiveInstant();
      // ignore: unawaited_futures
      _pollRemoteBookings(const {
        BookingStatus.confirmed,
        BookingStatus.onWay,
        BookingStatus.pickedUp,
      });
      if (bookings.any((b) => b.status == BookingStatus.onWay && b.etaArriveAt != null)) {
        notifyListeners();
      }
    });
    // Haydovchi javobi kutilayotgan bosqichlar — eng yuqori e'tibor paytida
    // tezroq (prebook_waiting_screen'dagi 3s poll bilan bir xil ruhda).
    _fastPollTimer?.cancel();
    _fastPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // ignore: unawaited_futures
      _pollRemoteBookings(const {BookingStatus.waiting, BookingStatus.counterOffer});
    });
  }

  int? _parseRemoteBookingId(String bookingId) {
    if (!bookingId.startsWith('inst_')) return null;
    return int.tryParse(bookingId.substring(5));
  }

  // Faqat instant (BookingKind.instant) bronlarga qo'llanadi — driverFound
  // faqat prebook oqimida ishlatiladi, bu yerda to'liqlik uchun kiritilgan.
  int _statusRank(BookingStatus s) => switch (s) {
        BookingStatus.waiting => 0,
        BookingStatus.driverFound => 1,
        BookingStatus.counterOffer => 1,
        BookingStatus.confirmed => 2,
        BookingStatus.onWay => 3,
        BookingStatus.pickedUp => 4,
        BookingStatus.completed => 5,
        BookingStatus.expired => 5,
        BookingStatus.cancelled => 5,
      };

  /// Haydovchi boshqa qurilmada javob bergan bo‘lsa — server holatini
  /// mahalliyga ko‘chiradi, mavjud setterlar orqali (ekranlar o‘zgarmaydi).
  Future<void> _pollRemoteBookings(Set<BookingStatus> statuses) async {
    final targets = bookings
        .where((b) => b.kind == BookingKind.instant && b.isActive && statuses.contains(b.status))
        .toList();
    for (final b in targets) {
      final remoteId = _parseRemoteBookingId(b.id);
      if (remoteId == null) continue;
      try {
        final row = await TripApi.instance.getBooking(remoteId);
        await _applyServerBookingRow(b, row);
      } catch (_) {
        // Internet yo'q yoki vaqtinchalik xato — keyingi urinishda davom etadi.
      }
    }
  }

  Future<void> _applyServerBookingRow(ActiveBooking b, Map<String, dynamic> row) async {
    final status = row['status'] as String? ?? '';
    if (status == 'REJECTED' || status == 'EXPIRED') {
      if (b.isActive) {
        await markExpired(
          b.id,
          message: status == 'REJECTED'
              ? tr('Haydovchi so‘rovni rad etdi. Boshqa haydovchini tanlashingiz mumkin.')
              : tr('Haydovchi javob bermadi.'),
        );
      }
      return;
    }
    if (status == 'CANCELLED') {
      if (b.isActive) {
        final reason = (row['cancel_reason'] as String?)?.trim();
        await markCancelled(
          bookingId: b.id,
          reason: (reason != null && reason.isNotEmpty) ? reason : tr('Safar bekor qilindi'),
          cancelledBy: (row['cancelled_by'] as String?) ?? '',
        );
      }
      return;
    }

    final trip = row['trip'] as Map<String, dynamic>;
    final agreedPrice = row['agreed_price'] as int?;
    // `trip.price`/`booking.agreed_price` serverda HAR DOIM 1 o'rindiq uchun
    // narx sifatida saqlanadi (confirm_trip_screen.dart'dagi "N kishi × narx"
    // hisob-kitobi bilan bir xil) — shu safar necha o'rindiq band
    // qilinganiga (`row['seats']`) ko'paytirmasak, band qilish bir nechta
    // o'rindiqni qamrab olganda ham narx maydonida bitta o'rindiqlik summa
    // ko'rinardi.
    final seats = row['seats'] as int? ?? b.seats;
    final unitPrice = agreedPrice ?? trip['price'] as int;
    final taxi = TripCatalogService.fromApi(trip).copyWith(price: unitPrice * seats);

    switch (status) {
      case 'COUNTERED':
        if (_statusRank(b.status) < 1 && agreedPrice != null) {
          await setCounterOffer(
            bookingId: b.id,
            taxi: taxi,
            counterPrice: agreedPrice * seats,
            offeredPrice: (trip['price'] as int) * seats,
          );
        }
        break;
      case 'CONFIRMED':
        if (_statusRank(b.status) < 2) {
          await setDriverAccepted(bookingId: b.id, taxi: taxi);
        }
        break;
      case 'DRIVER_ON_WAY':
        if (_statusRank(b.status) < 3) {
          await setDriverAccepted(bookingId: b.id, taxi: taxi, etaMinutes: (row['eta_minutes'] as int?) ?? 1);
        }
        break;
      case 'PASSENGER_PICKED':
        if (_statusRank(b.status) < 4) {
          await markPickedUp(b.id);
        }
        break;
      case 'COMPLETED':
        if (_statusRank(b.status) < 5) {
          await markBookingCompleted(b.id);
        }
        break;
    }
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
    String? note,
  }) async {
    if (!force && hasSameRoute(taxi.from, taxi.to)) {
      return 'Bu yo‘nalishda allaqachon faol bron bor';
    }
    String id;
    // Haydovchi serverda e'lon qilgan safar — so'rovni serverga yuboramiz va
    // haqiqiy booking id'sini olamiz (shu id orqali haydovchi o'z inbox'ida
    // ko'radi va keyinroq holatini pollab turamiz — boshqa qurilmada ham).
    if (taxi.remoteTripId != null) {
      try {
        final created = await TripApi.instance.book(taxi.remoteTripId!, seats: seats, note: note);
        id = 'inst_${created['id']}';
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    } else {
      id = 'inst_${DateTime.now().microsecondsSinceEpoch}';
    }
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
    if (taxi.remoteTripId == null) {
      // Faqat server-backed bo'lmagan (demo) taksilar uchun mahalliy ko'chirma —
      // haqiqiy safarlarda haydovchi so'rovni DriverTripService.pollInbox()
      // orqali serverdan o'zi bilib oladi.
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
    }
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
        : 'pre_${DateTime.now().microsecondsSinceEpoch}';
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
    ChatService.instance.ensureThread(taxi);
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
    ChatService.instance.ensureThread(taxi);
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

  /// Natija: muvaffaqiyatda `null`, serverdan xato kelsa xabar matni.
  /// `passengerStars` berilsa — haydovchining haqiqiy user id'si ma'lum
  /// bo'lsa, baho serverga (`RatingApi`) ham yuboriladi.
  Future<String?> complete(
    String bookingId, {
    TripCompletedBy completedBy = TripCompletedBy.passenger,
    bool driverRatedPassenger = false,
    bool passengerRatedDriver = false,
    int? passengerStars,
  }) async {
    final booking = byId(bookingId);
    final remoteId = _parseRemoteBookingId(bookingId);
    if (remoteId != null) {
      try {
        await TripApi.instance.advanceBookingStatus(remoteId, 'COMPLETED');
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    }
    await markBookingCompleted(bookingId);
    if (booking != null) {
      var ratedDriver = passengerRatedDriver;
      if (passengerStars != null) {
        ratedDriver = true;
        final toUserId = booking.taxi.driverUserId;
        if (toUserId != null) {
          try {
            await RatingApi.instance.rate(
              toUserId: toUserId,
              stars: passengerStars,
              tripId: booking.taxi.remoteTripId,
            );
          } catch (_) {}
        }
      }
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
        passengerRatedDriver: ratedDriver,
        driverUserId: booking.taxi.driverUserId,
        passengerUserId: AuthService.instance.user?.id,
        remoteTripId: booking.taxi.remoteTripId,
      );
      final order = DriverTripService.instance.orderById(bookingId);
      if (order != null && order.status != PassengerOrderStatus.done) {
        await DriverTripService.instance.markOrderDone(bookingId);
      }
    }
    notifyListeners();
    return null;
  }

  /// Haydovchi qarshi narx yuborganda yo'lovchi tasdiqlaydi. Server-backed
  /// (haqiqiy) bronlar uchun tarmoqqa ulanadi; demo/mock taksilar uchun eski
  /// mahalliy oqim (`DriverTripService.passengerConfirmCounter`) ishlatiladi.
  /// Natija: muvaffaqiyatda `null`, xato kelsa xabar matni.
  Future<String?> confirmCounterOffer(String bookingId) async {
    final booking = byId(bookingId);
    if (booking == null) return null;
    final remoteId = _parseRemoteBookingId(bookingId);
    if (remoteId == null) {
      await DriverTripService.instance.passengerConfirmCounter(bookingId);
      return null;
    }
    try {
      await TripApi.instance.confirmCounter(remoteId);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
    }
    if (booking.driverEtaMinutes != null) {
      await setDriverAccepted(bookingId: bookingId, taxi: booking.taxi, etaMinutes: booking.driverEtaMinutes!);
    } else {
      await setStatus(BookingStatus.confirmed, bookingId: bookingId, taxi: booking.taxi);
      await setStatus(BookingStatus.onWay, bookingId: bookingId, taxi: booking.taxi);
    }
    notifyListeners();
    return null;
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
