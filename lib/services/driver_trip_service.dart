import 'dart:async';
import '../l10n/phrase.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/taxi_offer.dart';
import '../services/active_booking_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/trip_completion_service.dart';
import '../utils/money.dart';

enum PassengerOrderKind { instant, prebook }

enum PassengerOrderStatus {
  open,
  counterOffered,
  accepted,
  onWay,
  pickedUp,
  done,
  cancelled,
  expired,
}

/// Yo‘lovchi so‘rovi — faqat maqsad haydovchiga ko‘rinadi.
class PassengerOrder {
  const PassengerOrder({
    required this.id,
    required this.kind,
    required this.from,
    required this.to,
    required this.passengers,
    required this.createdAt,
    required this.offeredPrice,
    required this.targetTaxiId,
    this.exactPickup = '',
    this.dateLabel = '',
    this.timeLabel = '',
    this.agreedPrice,
    this.passengerName = 'Yo‘lovchi',
    this.passengerPhone = '+998 90 000 00 00',
    this.status = PassengerOrderStatus.open,
    this.etaArriveAt,
    this.driverEtaMinutes,
    this.pickedUp = false,
    this.expiresAt,
    this.broadcastGroupId,
  });

  final String id;
  final PassengerOrderKind kind;
  final String from;
  final String to;
  final String exactPickup;
  final int passengers;
  final DateTime createdAt;
  final String dateLabel;
  final String timeLabel;
  final int offeredPrice;
  final int? agreedPrice;
  final String passengerName;
  final String passengerPhone;
  final PassengerOrderStatus status;
  final DateTime? etaArriveAt;
  final int? driverEtaMinutes;
  final bool pickedUp;
  final String targetTaxiId;
  final DateTime? expiresAt;
  /// Oldindan bron — barcha haydovchilarga yuborilgan guruh id.
  final String? broadcastGroupId;

  String get routeLabel {
    if (from.isEmpty && to.isEmpty) return 'Taksi';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from → $to';
  }

  int get displayPrice => agreedPrice ?? offeredPrice;
  String get offeredPriceLabel => formatSom(offeredPrice);
  String get priceLabel => formatSom(displayPrice);

  bool get hasCounterOffer =>
      status == PassengerOrderStatus.counterOffered ||
      (agreedPrice != null && agreedPrice != offeredPrice);

  String get agreedPriceLabel => agreedPrice == null ? '' : formatSom(agreedPrice!);

  bool get acceptedAtOfferedPrice =>
      (status == PassengerOrderStatus.accepted || status == PassengerOrderStatus.onWay) &&
      agreedPrice != null &&
      agreedPrice == offeredPrice;

  PassengerOrder copyWith({
    PassengerOrderStatus? status,
    int? agreedPrice,
    bool clearAgreedPrice = false,
    DateTime? etaArriveAt,
    int? driverEtaMinutes,
    bool? pickedUp,
    bool clearEta = false,
    DateTime? expiresAt,
    String? broadcastGroupId,
  }) {
    return PassengerOrder(
      id: id,
      kind: kind,
      from: from,
      to: to,
      exactPickup: exactPickup,
      passengers: passengers,
      createdAt: createdAt,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      offeredPrice: offeredPrice,
      agreedPrice: clearAgreedPrice ? null : (agreedPrice ?? this.agreedPrice),
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      status: status ?? this.status,
      etaArriveAt: clearEta ? null : (etaArriveAt ?? this.etaArriveAt),
      driverEtaMinutes: driverEtaMinutes ?? this.driverEtaMinutes,
      pickedUp: pickedUp ?? this.pickedUp,
      targetTaxiId: targetTaxiId,
      expiresAt: expiresAt ?? this.expiresAt,
      broadcastGroupId: broadcastGroupId ?? this.broadcastGroupId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'from': from,
        'to': to,
        'exactPickup': exactPickup,
        'passengers': passengers,
        'createdAt': createdAt.toIso8601String(),
        'dateLabel': dateLabel,
        'timeLabel': timeLabel,
        'offeredPrice': offeredPrice,
        'agreedPrice': agreedPrice,
        'passengerName': passengerName,
        'passengerPhone': passengerPhone,
        'status': status.name,
        'targetTaxiId': targetTaxiId,
        if (etaArriveAt != null) 'etaArriveAt': etaArriveAt!.toIso8601String(),
        if (driverEtaMinutes != null) 'driverEtaMinutes': driverEtaMinutes,
        'pickedUp': pickedUp,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (broadcastGroupId != null) 'broadcastGroupId': broadcastGroupId,
      };

  static PassengerOrder fromJson(Map<String, dynamic> j) {
    final offered = j['offeredPrice'] as int? ?? j['price'] as int? ?? 20000;
    final statusRaw = j['status'] as String? ?? 'open';
    PassengerOrderStatus status;
    try {
      status = PassengerOrderStatus.values.byName(statusRaw);
    } catch (_) {
      status = PassengerOrderStatus.open;
    }
    return PassengerOrder(
      id: j['id'] as String,
      kind: PassengerOrderKind.values.byName(j['kind'] as String),
      from: j['from'] as String? ?? '',
      to: j['to'] as String? ?? '',
      exactPickup: j['exactPickup'] as String? ?? '',
      passengers: j['passengers'] as int? ?? 1,
      createdAt: DateTime.parse(j['createdAt'] as String),
      dateLabel: j['dateLabel'] as String? ?? '',
      timeLabel: j['timeLabel'] as String? ?? '',
      offeredPrice: offered,
      agreedPrice: j['agreedPrice'] as int?,
      passengerName: j['passengerName'] as String? ?? tr('Yo‘lovchi'),
      passengerPhone: j['passengerPhone'] as String? ?? '',
      status: status,
      etaArriveAt: j['etaArriveAt'] == null ? null : DateTime.tryParse(j['etaArriveAt'] as String),
      driverEtaMinutes: j['driverEtaMinutes'] as int?,
      pickedUp: j['pickedUp'] as bool? ?? false,
      targetTaxiId: j['targetTaxiId'] as String? ?? '',
      expiresAt: j['expiresAt'] == null ? null : DateTime.tryParse(j['expiresAt'] as String),
      broadcastGroupId: j['broadcastGroupId'] as String?,
    );
  }
}

/// Haydovchi e’lon qilgan safar (maydonlar ixtiyoriy — ochiq taksi).
class DriverPublishedTrip {
  const DriverPublishedTrip({
    required this.id,
    required this.from,
    required this.to,
    required this.timeLabel,
    required this.dateLabel,
    required this.seats,
    required this.price,
    required this.createdAt,
    this.toAliases = const [],
    this.active = true,
  });

  final String id;
  final String from;
  final String to;
  final List<String> toAliases;
  final String timeLabel;
  final String dateLabel;
  final int seats;
  final int price;
  final DateTime createdAt;
  final bool active;

  bool get isOpenTrip => from.isEmpty && to.isEmpty;

  String get routeLabel {
    if (isOpenTrip) return 'Taksi';
    if (from.isEmpty || to.isEmpty) return from.isEmpty ? to : from;
    return '$from → $to';
  }

  String get priceLabel => price <= 0 ? 'Yo‘lovchi narx yuboradi' : formatSom(price);

  DriverPublishedTrip copyWith({bool? active, int? seats}) {
    return DriverPublishedTrip(
      id: id,
      from: from,
      to: to,
      toAliases: toAliases,
      timeLabel: timeLabel,
      dateLabel: dateLabel,
      seats: seats ?? this.seats,
      price: price,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'toAliases': toAliases,
        'timeLabel': timeLabel,
        'dateLabel': dateLabel,
        'seats': seats,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
        'active': active,
      };

  static DriverPublishedTrip fromJson(Map<String, dynamic> j) => DriverPublishedTrip(
        id: j['id'] as String,
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        toAliases: (j['toAliases'] as List?)?.cast<String>() ?? const [],
        timeLabel: j['timeLabel'] as String? ?? '',
        dateLabel: j['dateLabel'] as String? ?? '',
        seats: j['seats'] as int,
        price: j['price'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        active: j['active'] as bool? ?? true,
      );
}

class DriverTripService extends ChangeNotifier {
  DriverTripService._();
  static final DriverTripService instance = DriverTripService._();

  static const _kOrders = 'safaron_passenger_orders_v3';
  static const _kTrips = 'safaron_driver_trips';
  static const _kOnline = 'safaron_driver_online';
  static const orderTimeout = Duration(hours: 1);
  static const defaultRouteMinutes = 30;
  static const inactiveTimeout = Duration(hours: 5);

  bool _loaded = false;
  bool isOnline = true;
  List<PassengerOrder> orders = [];
  List<DriverPublishedTrip> myTrips = [];
  Timer? _expiryTimer;
  String? _lastPassengerNotice;
  String? _lastDriverNotice;

  String? get lastPassengerNotice => _lastPassengerNotice;
  String? get lastDriverNotice => _lastDriverNotice;

  void setPassengerNotice(String message) {
    _lastPassengerNotice = message;
    notifyListeners();
  }

  void setDriverNotice(String message) {
    _lastDriverNotice = message;
    notifyListeners();
  }

  void clearPassengerNotice() {
    _lastPassengerNotice = null;
  }

  void clearDriverNotice() {
    _lastDriverNotice = null;
  }

  bool orderBelongsToBooking(PassengerOrder o, String bookingId) {
    if (o.id == bookingId) return true;
    if (o.broadcastGroupId == bookingId) return true;
    if (bookingId.isNotEmpty && o.id.startsWith('${bookingId}__')) return true;
    return false;
  }

  /// Haydovchi katalog identifikatorlari (e’lonlar + shaxsiy id).
  String get myDriverId {
    final u = AuthService.instance.user;
    if (u?.driverId != null) return 'drv_${u!.driverId}';
    if (u != null) return 'user_${u.id}';
    final phone = ProfileService.instance.phone.replaceAll(RegExp(r'\D'), '');
    return phone.isEmpty ? 'drv_local' : 'drv_$phone';
  }

  Set<String> get _myTargetIds {
    final ids = {myDriverId};
    for (final t in myTrips) {
      ids.add(t.id);
    }
    return ids;
  }

  bool _isForMe(PassengerOrder o) =>
      o.targetTaxiId.isNotEmpty && _myTargetIds.contains(o.targetTaxiId);

  List<PassengerOrder> get openOrders =>
      orders.where((o) => o.status == PassengerOrderStatus.open && _isForMe(o)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PassengerOrder> get acceptedOrders => orders
      .where((o) =>
          _isForMe(o) &&
          (o.status == PassengerOrderStatus.accepted ||
              o.status == PassengerOrderStatus.counterOffered ||
              o.status == PassengerOrderStatus.onWay ||
              o.status == PassengerOrderStatus.pickedUp))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Barcha ochiq yo‘lovchi so‘rovlari (e’lon yopilgan bo‘lsa ham).
  List<PassengerOrder> get homeIncomingOrders => openOrders;

  List<PassengerOrder> get liveOrders => orders
      .where((o) =>
          _isForMe(o) &&
          (o.status == PassengerOrderStatus.accepted ||
              o.status == PassengerOrderStatus.onWay ||
              o.status == PassengerOrderStatus.pickedUp))
      .toList();

  List<PassengerOrder> get archivedOrders => orders
      .where((o) =>
          _isForMe(o) &&
          (o.status == PassengerOrderStatus.done ||
              o.status == PassengerOrderStatus.cancelled ||
              o.status == PassengerOrderStatus.expired))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DriverPublishedTrip> get activeTrips => myTrips.where((t) => t.active).toList();

  List<DriverPublishedTrip> get archivedTrips => myTrips.where((t) => !t.active).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  PassengerOrder? orderById(String id) {
    try {
      return orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    isOnline = prefs.getBool(_kOnline) ?? true;

    final ordersRaw = prefs.getString(_kOrders);
    if (ordersRaw != null && ordersRaw.isNotEmpty) {
      try {
        final list = (jsonDecode(ordersRaw) as List).cast<Map<String, dynamic>>();
        orders = list.map(PassengerOrder.fromJson).toList();
      } catch (_) {
        orders = [];
      }
    }

    final tripsRaw = prefs.getString(_kTrips);
    if (tripsRaw != null && tripsRaw.isNotEmpty) {
      try {
        final list = (jsonDecode(tripsRaw) as List).cast<Map<String, dynamic>>();
        myTrips = list.map(DriverPublishedTrip.fromJson).toList();
      } catch (_) {
        myTrips = [];
      }
    }

    _loaded = true;
    _armExpiryTimer();
    await _expireStaleOrders();
    notifyListeners();
  }

  void _armExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // ignore: unawaited_futures
      _expireStaleOrders();
    });
  }

  Future<void> _expireStaleOrders() async {
    final now = DateTime.now();
    var changed = false;
    orders = [
      for (final o in orders)
        if (o.status == PassengerOrderStatus.open &&
            (o.expiresAt ?? o.createdAt.add(orderTimeout)).isBefore(now))
          () {
            changed = true;
            // ignore: unawaited_futures
            _notifyPassengerExpired(o);
            return o.copyWith(status: PassengerOrderStatus.expired);
          }()
        else if (o.kind == PassengerOrderKind.instant &&
            o.status != PassengerOrderStatus.done &&
            o.status != PassengerOrderStatus.cancelled &&
            o.status != PassengerOrderStatus.expired &&
            o.status != PassengerOrderStatus.open &&
            o.createdAt.add(inactiveTimeout).isBefore(now))
          () {
            changed = true;
            // ignore: unawaited_futures
            _notifyPassengerInactiveClosed(o);
            return o.copyWith(status: PassengerOrderStatus.expired);
          }()
        else
          o,
    ];
    if (changed) {
      await _persistOrders();
      notifyListeners();
    }
  }

  Future<void> _notifyPassengerInactiveClosed(PassengerOrder o) async {
    _lastPassengerNotice =
        'Safar 5 soat davomida faol bo‘lmagani uchun avtomatik yopildi.';
    await ActiveBookingService.instance.markExpired(
      o.id,
      message: _lastPassengerNotice!,
    );
  }

  Future<void> _notifyPassengerExpired(PassengerOrder o) async {
    _lastPassengerNotice =
        'Haydovchi 1 soat ichida javob bermadi. Boshqa haydovchini tanlashingiz mumkin.';
    await ActiveBookingService.instance.markExpired(
      o.id,
      message: _lastPassengerNotice!,
    );
  }

  TaxiOffer _driverTaxiOffer({required int price, String? tripId, String from = '', String to = ''}) {
    final p = ProfileService.instance;
    final carPhoto = p.carPhotoPath;
    return TaxiOffer(
      id: tripId ?? myDriverId,
      from: from,
      to: to,
      time: '',
      seats: p.seats,
      price: price,
      driverName: p.fullName.isEmpty ? 'Haydovchi' : p.fullName,
      rating: AuthService.instance.user?.ratingAvg ?? 5.0,
      reviews: 0,
      carModel: p.carName.isEmpty ? 'Avtomobil' : p.carName,
      plate: p.plate,
      phone: p.phone,
      imageAsset: carPhoto.isNotEmpty ? carPhoto : 'assets/images/car_cobalt.png',
      period: TimeOfDayFilter.all,
      etaMinutes: 12,
      isOnline: isOnline,
    );
  }

  /// Qabul/bekor faqat haydovchi manzil VA o‘z narxini qo‘ygan, yo‘lovchi shu narxda shu yo‘nalishni tanlaganda.
  bool orderLocksPrice(PassengerOrder order) {
    try {
      final trip = myTrips.firstWhere((t) => t.id == order.targetTaxiId);
      if (trip.price <= 0 || trip.from.trim().isEmpty || trip.to.trim().isEmpty) return false;
      final sameFrom = trip.from.trim().toLowerCase() == order.from.trim().toLowerCase();
      final sameTo = trip.to.trim().toLowerCase() == order.to.trim().toLowerCase();
      return sameFrom && sameTo && order.offeredPrice == trip.price;
    } catch (_) {
      return false;
    }
  }

  /// Onlayn tasdiqlangan haydovchi e’lonlari katalogga (oflayn ham oxirida ko‘rinadi).
  List<TaxiOffer> publishedCatalogOffers() {
    if (!ProfileService.instance.isApprovedDriver) return [];
    final p = ProfileService.instance;
    return activeTrips.map((t) {
      return TaxiOffer(
        id: t.id,
        from: t.from,
        to: t.to,
        time: t.timeLabel,
        seats: t.seats,
        price: t.price,
        driverName: p.fullName.isEmpty ? 'Haydovchi' : p.fullName,
        rating: AuthService.instance.user?.ratingAvg ?? 5.0,
        reviews: 0,
        carModel: p.carName.isEmpty ? 'Avtomobil' : p.carName,
        plate: p.plate,
        phone: p.phone,
        imageAsset: p.carPhotoPath.isNotEmpty ? p.carPhotoPath : 'assets/images/car_cobalt.png',
        period: TimeOfDayFilter.all,
        badge: t.isOpenTrip ? 'Ochiq taksi' : null,
        etaMinutes: 12,
        isOnline: true,
        toAliases: t.toAliases,
      );
    }).toList();
  }

  Future<void> setOnline(bool value) async {
    isOnline = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnline, value);
    notifyListeners();
  }

  Future<void> addPassengerOrder(PassengerOrder order) async {
    orders = [order, ...orders.where((o) => o.id != order.id)];
    await _persistOrders();
    notifyListeners();
  }

  Future<void> acceptOrder(String id, {int? driverPrice, int? etaMinutes}) async {
    final order = orderById(id);
    if (order == null) return;

    final agreed = driverPrice ?? order.offeredPrice;
    final isCounter = agreed != order.offeredPrice;
    final newStatus = isCounter ? PassengerOrderStatus.counterOffered : PassengerOrderStatus.accepted;

    orders = [
      for (final o in orders)
        if (o.id == id)
          o.copyWith(
            status: newStatus,
            agreedPrice: agreed,
            driverEtaMinutes: etaMinutes,
            etaArriveAt: etaMinutes == null ? null : DateTime.now().add(Duration(minutes: etaMinutes)),
          )
        else
          o,
    ];
    await _persistOrders();

    final taxi = _driverTaxiOffer(
      price: agreed,
      tripId: order.targetTaxiId,
      from: order.from,
      to: order.to,
    );

    final bookingId = order.broadcastGroupId ?? id;
    if (isCounter) {
      await ActiveBookingService.instance.setCounterOffer(
        bookingId: bookingId,
        taxi: taxi,
        counterPrice: agreed,
        offeredPrice: order.offeredPrice,
      );
    } else if (order.kind == PassengerOrderKind.prebook) {
      await ActiveBookingService.instance.setStatus(
        BookingStatus.driverFound,
        bookingId: bookingId,
        taxi: taxi,
        kind: BookingKind.prebook,
      );
    } else {
      if (etaMinutes != null) {
        await ActiveBookingService.instance.setDriverAccepted(
          bookingId: bookingId,
          taxi: taxi,
          etaMinutes: etaMinutes,
        );
      } else {
        await ActiveBookingService.instance.setDriverAccepted(
          bookingId: bookingId,
          taxi: taxi,
        );
      }
    }

    if (!isCounter && activeTrips.isNotEmpty) {
      final trip = activeTrips.firstWhere(
        (t) => t.id == order.targetTaxiId,
        orElse: () => activeTrips.first,
      );
      final left = (trip.seats - order.passengers).clamp(0, trip.seats);
      myTrips = [
        for (final t in myTrips)
          if (t.id == trip.id) t.copyWith(seats: left, active: left > 0) else t,
      ];
      await _persistTrips();
    }

    notifyListeners();
  }

  Future<void> passengerConfirmCounter(String bookingId) async {
    orders = [
      for (final o in orders)
        if (o.id == bookingId)
          o.copyWith(status: PassengerOrderStatus.onWay)
        else
          o,
    ];
    await _persistOrders();

    final order = orderById(bookingId);
    if (order != null) {
      final taxi = _driverTaxiOffer(
        price: order.agreedPrice ?? order.offeredPrice,
        tripId: order.targetTaxiId,
        from: order.from,
        to: order.to,
      );
      if (order.driverEtaMinutes != null) {
        await ActiveBookingService.instance.setDriverAccepted(
          bookingId: bookingId,
          taxi: taxi,
          etaMinutes: order.driverEtaMinutes!,
        );
      } else {
        await ActiveBookingService.instance.setStatus(BookingStatus.confirmed, bookingId: bookingId, taxi: taxi);
        await ActiveBookingService.instance.setStatus(BookingStatus.onWay, bookingId: bookingId, taxi: taxi);
      }
    }
    notifyListeners();
  }

  Future<void> passengerRejectCounter(String bookingId) async {
    orders = [
      for (final o in orders)
        if (o.id == bookingId) o.copyWith(status: PassengerOrderStatus.cancelled) else o,
    ];
    await _persistOrders();
    notifyListeners();
  }

  /// Yo‘lovchi safarni bekor qiladi — barcha holat va haydovchilarda yopiladi.
  Future<void> passengerCancelRequest(String bookingId) async {
    await cancelAllForBooking(bookingId, cancelledBy: 'passenger');
  }

  Future<void> cancelAllForBooking(
    String bookingId, {
    required String cancelledBy,
    String? reason,
  }) async {
    orders = [
      for (final o in orders)
        if (orderBelongsToBooking(o, bookingId) &&
            o.status != PassengerOrderStatus.done &&
            o.status != PassengerOrderStatus.cancelled)
          o.copyWith(status: PassengerOrderStatus.cancelled)
        else
          o,
    ];
    await _persistOrders();
    notifyListeners();
  }

  /// Ochiq so‘rovni rad etish — faqat shu haydovchi nusxasi (broadcast).
  Future<void> rejectOpenOrder(String orderId, {required String reason}) async {
    final order = orderById(orderId);
    if (order == null) return;
    if (order.status != PassengerOrderStatus.open) {
      await cancelAllForBooking(
        order.broadcastGroupId ?? orderId,
        cancelledBy: 'driver',
        reason: reason,
      );
      return;
    }
    if (order.broadcastGroupId != null) {
      orders = [
        for (final o in orders)
          if (o.id == orderId) o.copyWith(status: PassengerOrderStatus.cancelled) else o,
      ];
    } else {
      orders = [
        for (final o in orders)
          if (o.id == orderId) o.copyWith(status: PassengerOrderStatus.cancelled) else o,
      ];
      setPassengerNotice(tr('Haydovchi so‘rovni rad etdi. Boshqa haydovchini tanlashingiz mumkin.'));
      await ActiveBookingService.instance.markExpired(
        orderId,
        message: tr('Haydovchi so‘rovni rad etdi'),
      );
    }
    await _persistOrders();
    notifyListeners();
  }

  /// Yo‘lovchi haydovchini tanlaganda — qolgan haydovchilardan olib tashlash.
  Future<void> confirmBroadcastSelection(String groupId, {required String acceptedOrderId}) async {
    orders = [
      for (final o in orders)
        if (o.broadcastGroupId == groupId && o.id != acceptedOrderId && o.status == PassengerOrderStatus.open)
          o.copyWith(status: PassengerOrderStatus.cancelled)
        else if (o.broadcastGroupId == groupId && o.id == acceptedOrderId)
          o.copyWith(status: PassengerOrderStatus.accepted)
        else
          o,
    ];
    await _persistOrders();
    notifyListeners();
  }

  /// «Boshqa taksi» — faqat shu haydovchi uchun yopiladi.
  Future<void> cancelBroadcastForTarget(String groupId, String targetTaxiId) async {
    orders = [
      for (final o in orders)
        if (o.broadcastGroupId == groupId && o.targetTaxiId == targetTaxiId)
          o.copyWith(status: PassengerOrderStatus.cancelled)
        else
          o,
    ];
    await _persistOrders();
    notifyListeners();
  }

  List<String> _broadcastTargetIds({
    required String from,
    required String to,
    required int passengers,
  }) {
    final ids = <String>{};
    for (final t in myTrips.where((t) => t.active && t.seats >= passengers)) {
      if (t.isOpenTrip) {
        ids.add(t.id);
        continue;
      }
      if (t.from.trim().isNotEmpty &&
          t.to.trim().isNotEmpty &&
          _routeSame(t.from, t.to, from, to)) {
        ids.add(t.id);
      }
    }
    if (ProfileService.instance.isApprovedDriver) ids.add(myDriverId);
    return ids.toList();
  }

  Future<void> expireOrderInactive(String bookingId) async {
    orders = [
      for (final o in orders)
        if (o.id == bookingId) o.copyWith(status: PassengerOrderStatus.expired) else o,
    ];
    await _persistOrders();
    notifyListeners();
  }

  Future<void> markPassengerPickedUp(String id) async {
    orders = [
      for (final o in orders)
        if (o.id == id)
          o.copyWith(status: PassengerOrderStatus.pickedUp, pickedUp: true, clearEta: true)
        else
          o,
    ];
    await _persistOrders();
    await ActiveBookingService.instance.markPickedUp(id);
    notifyListeners();
  }

  Future<void> cancelOrder(String id) async {
    final order = orderById(id);
    if (order == null) return;
    final isLive = order.status == PassengerOrderStatus.accepted ||
        order.status == PassengerOrderStatus.onWay ||
        order.status == PassengerOrderStatus.pickedUp ||
        order.status == PassengerOrderStatus.counterOffered;
    if (isLive) {
      // TripCancelService handles full cancel when called from UI with reason.
      await cancelAllForBooking(order.broadcastGroupId ?? id, cancelledBy: 'driver');
      setPassengerNotice(tr('Haydovchi safarni bekor qildi'));
      await ActiveBookingService.instance.markCancelled(
        bookingId: order.broadcastGroupId ?? id,
        reason: tr('Haydovchi safarni bekor qildi'),
        cancelledBy: 'driver',
      );
    } else {
      await rejectOpenOrder(id, reason: tr('Haydovchi rad etdi'));
    }
    await _persistOrders();
    notifyListeners();
  }

  Future<void> markOrderDone(String id) async {
    orders = [
      for (final o in orders)
        if (o.id == id) o.copyWith(status: PassengerOrderStatus.done) else o,
    ];
    await _persistOrders();
    notifyListeners();
  }

  Future<void> completeOrder(
    String id, {
    TripCompletedBy completedBy = TripCompletedBy.driver,
    bool driverRatedPassenger = false,
    bool passengerRatedDriver = false,
  }) async {
    final order = orderById(id);
    await markOrderDone(id);
    await ActiveBookingService.instance.markBookingCompleted(id);
    if (order != null) {
      await TripCompletionService.instance.recordCompletion(
        bookingId: id,
        from: order.from,
        to: order.to,
        price: order.displayPrice,
        completedBy: completedBy,
        passengerName: order.passengerName,
        driverName: ProfileService.instance.fullName.isEmpty
            ? 'Haydovchi'
            : ProfileService.instance.fullName,
        driverRatedPassenger: driverRatedPassenger,
        passengerRatedDriver: passengerRatedDriver,
      );
    }
    notifyListeners();
  }

  /// Eng ko‘p e’lon qilingan yo‘nalishlar (top 3).
  List<({String from, String to, int count})> get topRoutes {
    final counts = <String, ({String from, String to, int count})>{};
    for (final t in myTrips) {
      final key = '${t.from}|${t.to}';
      final prev = counts[key];
      counts[key] = (from: t.from, to: t.to, count: (prev?.count ?? 0) + 1);
    }
    final list = counts.values.toList()..sort((a, b) => b.count.compareTo(a.count));
    return list.take(3).toList();
  }

  String? publishBlockReason({required String from, required String to}) {
    final now = DateTime.now();
    final f = from.trim();
    final t = to.trim();
    for (final trip in activeTrips) {
      final tf = trip.from.trim();
      final tt = trip.to.trim();
      final sameDir = _routeSame(tf, tt, f, t);
      final opposite = _routeSame(tf, tt, t, f);
      if (sameDir) {
        final blockUntil = trip.createdAt.add(Duration(minutes: defaultRouteMinutes * 2));
        if (now.isBefore(blockUntil)) {
          return 'Bu yo‘nalishda ${defaultRouteMinutes * 2} daqiqa kutish kerak (borish+qaytish). '
              '${blockUntil.hour.toString().padLeft(2, '0')}:${blockUntil.minute.toString().padLeft(2, '0')} dan keyin e’lon qiling.';
        }
      } else if (opposite) {
        final blockUntil = trip.createdAt.add(Duration(minutes: defaultRouteMinutes));
        if (now.isBefore(blockUntil)) {
          return 'Qarama-qarshi yo‘nalish uchun ${defaultRouteMinutes} daqiqa kuting '
              '(${blockUntil.hour.toString().padLeft(2, '0')}:${blockUntil.minute.toString().padLeft(2, '0')}).';
        }
      }
    }
    return null;
  }

  bool _routeSame(String aFrom, String aTo, String bFrom, String bTo) {
    if (aFrom.isEmpty && aTo.isEmpty && bFrom.isEmpty && bTo.isEmpty) return true;
    if (aFrom.isEmpty || aTo.isEmpty || bFrom.isEmpty || bTo.isEmpty) return false;
    return aFrom.toLowerCase() == bFrom.toLowerCase() && aTo.toLowerCase() == bTo.toLowerCase();
  }

  Future<void> publishTrip({
    String from = '',
    String to = '',
    String timeLabel = '',
    String dateLabel = '',
    required int seats,
    int price = 0,
    List<String> toAliases = const [],
  }) async {
    final block = publishBlockReason(from: from, to: to);
    if (block != null) throw StateError(block);
    final trip = DriverPublishedTrip(
      id: 'dt_${DateTime.now().millisecondsSinceEpoch}',
      from: from,
      to: to,
      toAliases: toAliases,
      timeLabel: timeLabel,
      dateLabel: dateLabel,
      seats: seats,
      price: price,
      createdAt: DateTime.now(),
    );
    myTrips = [trip, ...myTrips];
    await _persistTrips();
    notifyListeners();
  }

  Future<void> deactivateTrip(String id) async {
    myTrips = [
      for (final t in myTrips)
        if (t.id == id) t.copyWith(active: false) else t,
    ];
    await _persistTrips();
    notifyListeners();
  }

  Future<void> _persistOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOrders, jsonEncode(orders.map((e) => e.toJson()).toList()));
  }

  Future<void> _persistTrips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTrips, jsonEncode(myTrips.map((e) => e.toJson()).toList()));
  }

  Future<void> pushFromPassengerBooking({
    required String from,
    required String to,
    required int passengers,
    required int offeredPrice,
    required String targetTaxiId,
    String exactPickup = '',
    bool prebook = false,
    String dateLabel = '',
    String timeLabel = '',
    String? bookingId,
  }) async {
    final name = ProfileService.instance.fullName;
    final expires = DateTime.now().add(orderTimeout);
    final groupId = bookingId ?? (prebook ? 'pre_${DateTime.now().millisecondsSinceEpoch}' : null);

    if (prebook && groupId != null) {
      final targets = _broadcastTargetIds(from: from, to: to, passengers: passengers);
      if (targets.isEmpty) {
        await addPassengerOrder(
          PassengerOrder(
            id: groupId,
            kind: PassengerOrderKind.prebook,
            from: from,
            to: to,
            exactPickup: exactPickup,
            passengers: passengers,
            createdAt: DateTime.now(),
            dateLabel: dateLabel,
            timeLabel: timeLabel,
            offeredPrice: offeredPrice,
            passengerName: name.isEmpty ? tr('Yo‘lovchi') : name,
            passengerPhone: ProfileService.instance.phone,
            targetTaxiId: myDriverId,
            expiresAt: expires,
            broadcastGroupId: groupId,
          ),
        );
        return;
      }
      for (final tid in targets) {
        await addPassengerOrder(
          PassengerOrder(
            id: '${groupId}__$tid',
            kind: PassengerOrderKind.prebook,
            from: from,
            to: to,
            exactPickup: exactPickup,
            passengers: passengers,
            createdAt: DateTime.now(),
            dateLabel: dateLabel,
            timeLabel: timeLabel,
            offeredPrice: offeredPrice,
            passengerName: name.isEmpty ? tr('Yo‘lovchi') : name,
            passengerPhone: ProfileService.instance.phone,
            targetTaxiId: tid,
            expiresAt: expires,
            broadcastGroupId: groupId,
          ),
        );
      }
      return;
    }

    await addPassengerOrder(
      PassengerOrder(
        id: bookingId ?? 'po_${DateTime.now().millisecondsSinceEpoch}',
        kind: prebook ? PassengerOrderKind.prebook : PassengerOrderKind.instant,
        from: from,
        to: to,
        exactPickup: exactPickup,
        passengers: passengers,
        createdAt: DateTime.now(),
        dateLabel: dateLabel,
        timeLabel: timeLabel,
        offeredPrice: offeredPrice,
        passengerName: name.isEmpty ? tr('Yo‘lovchi') : name,
        passengerPhone: ProfileService.instance.phone,
        targetTaxiId: targetTaxiId,
        expiresAt: expires,
        broadcastGroupId: groupId,
      ),
    );
  }
}
