import 'dart:async';
import '../l10n/phrase.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/taxi_offer.dart';
import '../services/active_booking_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../services/safaron_api.dart';
import '../services/trip_completion_service.dart';
import '../utils/money.dart';
import 'api_client.dart';

enum PassengerOrderKind { instant, prebook }

enum PassengerOrderStatus {
  open,
  counterOffered,
  // Oldindan bron oqimida: men (haydovchi) so'rovga javob berdim, ammo
  // yo'lovchi hali meni TANLAMAGAN (boshqa haydovchilar ham javob
  // bergan/berishi mumkin). Avval bu `accepted` bilan bir xil hisoblanardi
  // — shuning uchun yo'lovchi hali tasdiqlamagan bo'lsa ham "Yo'lovchini
  // oldim" tugmasi chiqib qolardi.
  awaitingSelection,
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
    this.pickedUpAt,
    this.expiresAt,
    this.broadcastGroupId,
    this.passengerUserId,
    this.passengerPhoto,
    this.pendingSeats,
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
  final DateTime? pickedUpAt;
  final String targetTaxiId;
  final DateTime? expiresAt;
  /// Oldindan bron — barcha haydovchilarga yuborilgan guruh id.
  final String? broadcastGroupId;
  final int? passengerUserId;
  final String? passengerPhoto;

  /// Yo'lovchi so'ragan, hali javob berilmagan yangi o'rindiq soni
  /// (null — kutilayotgan so'rov yo'q). Faqat `instant` buyurtmalarda.
  final int? pendingSeats;

  /// Yo'lovchi "raqamimni yashirish"ni yoqqan bo'lsa, server
  /// `passengerPhone`ni "+998***" shaklida yuboradi — qo'ng'iroq tugmasini
  /// shu belgiga qarab o'chiramiz.
  bool get passengerPhoneHidden => passengerPhone.contains('*');

  String get routeLabel {
    if (from.isEmpty && to.isEmpty) return 'Taksi';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from → $to';
  }

  int get displayPrice => agreedPrice ?? offeredPrice;
  String get offeredPriceLabel => formatSom(offeredPrice);
  String get priceLabel => formatSom(displayPrice);

  /// Bitta o'rindiq narxini `passengers`ga ko'paytiradi — faqat `instant`
  /// (e'lon qilingan safarga band qilish) buyurtmalar uchun, chunki
  /// `offeredPrice`/`agreedPrice` ularda har doim 1 o'rindiq narxi sifatida
  /// saqlanadi (confirm_trip_screen.dart'dagi hisob bilan bir xil).
  /// `prebook` so'rovlarida esa `offeredPrice` boshidanoq butun guruh uchun
  /// bitta umumiy taklif (prebook_screen.dart'da bitta maydon, o'rindiqqa
  /// bo'linmaydi) — shuning uchun qayta ko'paytirilmaydi.
  int get totalOfferedPrice => kind == PassengerOrderKind.instant ? offeredPrice * passengers : offeredPrice;
  int? get totalAgreedPrice =>
      agreedPrice == null ? null : (kind == PassengerOrderKind.instant ? agreedPrice! * passengers : agreedPrice);
  int get totalPrice => totalAgreedPrice ?? totalOfferedPrice;
  String get totalOfferedPriceLabel => formatSom(totalOfferedPrice);
  String get totalPriceLabel => formatSom(totalPrice);
  String get totalAgreedPriceLabel => totalAgreedPrice == null ? '' : formatSom(totalAgreedPrice!);

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
    DateTime? pickedUpAt,
    bool clearEta = false,
    DateTime? expiresAt,
    String? broadcastGroupId,
    int? pendingSeats,
    bool clearPendingSeats = false,
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
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      targetTaxiId: targetTaxiId,
      expiresAt: expiresAt ?? this.expiresAt,
      broadcastGroupId: broadcastGroupId ?? this.broadcastGroupId,
      passengerUserId: passengerUserId,
      passengerPhoto: passengerPhoto,
      pendingSeats: clearPendingSeats ? null : (pendingSeats ?? this.pendingSeats),
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
        if (pickedUpAt != null) 'pickedUpAt': pickedUpAt!.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (broadcastGroupId != null) 'broadcastGroupId': broadcastGroupId,
        if (passengerUserId != null) 'passengerUserId': passengerUserId,
        if (passengerPhoto != null) 'passengerPhoto': passengerPhoto,
        if (pendingSeats != null) 'pendingSeats': pendingSeats,
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
      pickedUpAt: j['pickedUpAt'] == null ? null : DateTime.tryParse(j['pickedUpAt'] as String),
      targetTaxiId: j['targetTaxiId'] as String? ?? '',
      expiresAt: j['expiresAt'] == null ? null : DateTime.tryParse(j['expiresAt'] as String),
      broadcastGroupId: j['broadcastGroupId'] as String?,
      passengerUserId: j['passengerUserId'] as int?,
      passengerPhoto: j['passengerPhoto'] as String?,
      pendingSeats: j['pendingSeats'] as int?,
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
    this.minAutoAcceptPrice,
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

  /// Shundan yuqori taklif qilingan narx kelsa, so‘rov qo‘lda kutmasdan
  /// avtomatik qabul qilinadi (haydovchi javob tezligini oshirish uchun).
  final int? minAutoAcceptPrice;

  bool get isOpenTrip => from.isEmpty && to.isEmpty;

  String get routeLabel {
    if (isOpenTrip) return 'Taksi';
    if (from.isEmpty || to.isEmpty) return from.isEmpty ? to : from;
    return '$from → $to';
  }

  String get priceLabel => price <= 0 ? tr('Yo‘lovchi narx yuboradi') : formatSom(price);

  DriverPublishedTrip copyWith({bool? active, int? seats, int? minAutoAcceptPrice, bool clearMinAutoAcceptPrice = false}) {
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
      minAutoAcceptPrice: clearMinAutoAcceptPrice ? null : (minAutoAcceptPrice ?? this.minAutoAcceptPrice),
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
        if (minAutoAcceptPrice != null) 'minAutoAcceptPrice': minAutoAcceptPrice,
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
        minAutoAcceptPrice: j['minAutoAcceptPrice'] as int?,
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
  static const defaultRouteMinutes = 20;
  static const inactiveTimeout = Duration(hours: 5);
  /// Yo‘lovchi olingandan keyin haydovchi "Safarni yakunlash"ni unutib qoysa —
  /// shu vaqtdan so‘ng safar avtomatik (muvaffaqiyatli) yakunlanadi.
  static const autoCompleteAfterPickup = Duration(hours: 2);

  bool _loaded = false;
  bool isOnline = true;
  List<PassengerOrder> orders = [];
  List<DriverPublishedTrip> myTrips = [];
  Timer? _expiryTimer;
  Timer? _heartbeatTimer;
  Timer? _inboxPollTimer;

  /// `pollInbox()` bir vaqtning o'zida bir nechta joydan (oddiy 7s taymer,
  /// `AppRefresh.run()` ilova fondan qaytganda, pastga tortib yangilash)
  /// chaqirilishi mumkin. Agar ESKI so'rovning javobi YANGI so'rov
  /// yuborilgandan KEYIN kelsa (tarmoq kechikishi tasodifiy tartibni
  /// buzsa), eski (allaqachon eskirgan) javob yangi ma'lumotni qayta yozib
  /// yuborib, tasdiqlangan buyurtmani bir lahzaga "yo'qolib" ko'rsatib
  /// yuborishi mumkin edi. Har bir pollInbox() chaqiruvi o'zining avlod
  /// raqamini oladi — javob qaytganda bu hali ENG YANGISIMI tekshiriladi,
  /// aks holda natija e'tiborsiz qoldiriladi.
  int _pollGeneration = 0;
  String? _lastPassengerNotice;
  String? _lastDriverNotice;

  int? _remoteBookingId(String orderId) {
    if (!orderId.startsWith('inst_')) return null;
    return int.tryParse(orderId.substring(5));
  }

  /// Oldindan bron (TripRequest) id'si — `req_<id>` shaklida, odatda
  /// `order.broadcastGroupId ?? order.id` dan olinadi (broadcast order'lar
  /// `'${groupId}__<targetTaxiId>'` ko'rinishida bo'lgani uchun).
  int? _remoteRequestId(String bookingId) {
    if (!bookingId.startsWith('req_')) return null;
    return int.tryParse(bookingId.substring(4));
  }

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
              o.status == PassengerOrderStatus.awaitingSelection ||
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
              o.status == PassengerOrderStatus.awaitingSelection ||
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
    if (!_loaded) {
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
    }
    if (isOnline) {
      // Bu qism _loaded qo'riqlovidan tashqarida qasddan — ilk urinish ilova
      // ochilishida tarmoq/autentifikatsiya hali tayyor bo'lmay muvaffaqiyatsiz
      // bo'lsa, oldin bu hech qachon qayta urinilmasdi va server haydovchini
      // abadiy "oflayn" deb bilib, e'lonlari hech kimga (hatto o'ziga ham)
      // ko'rinmay qolardi — Onlayn/Oflayn tugmasini qo'lda bosmaguncha. Endi
      // har bir AppRefresh.run() (pastga tortib yangilash) chaqirig'ida ham
      // qayta uriniladi.
      // ignore: unawaited_futures
      DriverApi.instance.setOnline(true).catchError((_) {});
      _syncHeartbeat();
    }
    // Oflayn bo'lsa ham ishga tushishi kerak — allaqachon qabul qilingan
    // band qilishlar (tasdiqlangan/yo'lda) backend tomonidan oflaynda ham
    // ko'rsatiladi, shuning uchun ularning holati (masalan, yo'lovchi bekor
    // qildi) oflayn haydovchida ham yangilanishi kerak.
    _armInboxPoll();
    if (ProfileService.instance.isApprovedDriver) {
      // Qayta o'rnatilgan ilova yoki boshqa qurilmada kirilganda ham
      // haydovchining e'lon qilgan safarlari bo'sh ko'rinmasligi uchun.
      // ignore: unawaited_futures
      syncFromServer();
    }
    notifyListeners();
  }

  /// Hisobdan chiqishda — bu qurilmadagi keyingi foydalanuvchi oldingisining
  /// buyurtmalari/safarlarini ko‘rmasligi uchun.
  Future<void> clearForLogout() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _inboxPollTimer?.cancel();
    _inboxPollTimer = null;
    orders = [];
    myTrips = [];
    await _persistOrders();
    await _persistTrips();
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
    final staleToComplete = <String>[];
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
        else if (o.status == PassengerOrderStatus.pickedUp &&
            (o.pickedUpAt ?? o.createdAt).add(autoCompleteAfterPickup).isBefore(now))
          () {
            // Yo‘lovchi olingan, ammo "Safarni yakunlash" unutilgan — avtomatik
            // (muvaffaqiyatli) yakunlash uchun belgilaymiz, pastda completeOrder chaqiriladi.
            staleToComplete.add(o.id);
            return o;
          }()
        else if (o.kind == PassengerOrderKind.instant &&
            o.status != PassengerOrderStatus.done &&
            o.status != PassengerOrderStatus.cancelled &&
            o.status != PassengerOrderStatus.expired &&
            o.status != PassengerOrderStatus.open &&
            o.status != PassengerOrderStatus.pickedUp &&
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
    for (final id in staleToComplete) {
      await completeOrder(id, completedBy: TripCompletedBy.auto);
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
    final id = tripId ?? myDriverId;
    return TaxiOffer(
      id: id,
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
      driverPhoto: p.avatarPath,
      driverUserId: AuthService.instance.user?.id,
      remoteTripId: id.startsWith('dt_') ? int.tryParse(id.substring(3)) : null,
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
    if (!isOnline) return [];
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
        driverPhoto: p.avatarPath,
        driverUserId: AuthService.instance.user?.id,
        remoteTripId: int.tryParse(t.id.substring(3)),
        period: TimeOfDayFilter.all,
        badge: t.isOpenTrip ? 'Ochiq taksi' : null,
        etaMinutes: 12,
        isOnline: true,
        toAliases: t.toAliases,
      );
    }).toList();
  }

  /// Haydovchi "Onlayn/Oflayn" tugmasini bosganda — mahalliy holatni
  /// o'zgartirish bilan birga serverga ham yuboradi, aks holda yo'lovchilar
  /// uni hamon oflayn deb ko'radi (server ko'rinishi mahalliy UI dan mustaqil).
  Future<void> setOnline(bool value) async {
    await DriverApi.instance.setOnline(value);
    isOnline = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnline, value);
    _syncHeartbeat();
    _armInboxPoll();
    notifyListeners();
  }

  /// Onlayn bo'lgan vaqtda serverga davriy signal yuborib, "faolligi tugagan"
  /// deb avtomatik oflaynga o'tkazilib qolinmasligi uchun.
  void _syncHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (!isOnline) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      DriverApi.instance.heartbeat().catchError((_) {});
    });
  }

  /// Boshqa qurilmadagi yo'lovchilarning so'rovlarini serverdan tortib,
  /// mahalliy "Kelgan buyurtmalar" ro'yxatiga qo'shadi — aks holda haydovchi
  /// faqat shu qurilmada yaratilgan (mahalliy push) so'rovlarnigina ko'rardi.
  /// Online/oflayndan qat'i nazar doim ishga tushadi — allaqachon qabul
  /// qilingan (COUNTERED/CONFIRMED/DRIVER_ON_WAY/PASSENGER_PICKED) band
  /// qilishlar backend tomonidan oflaynda ham ko'rsatiladi (haydovchining
  /// faol majburiyati), faqat YANGI (PENDING) so'rovlar oflaynda
  /// yashiriladi — shu farq `pollInbox()`ning o'zida hisobga olinadi.
  void _armInboxPoll() {
    _inboxPollTimer?.cancel();
    _inboxPollTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      // ignore: unawaited_futures
      pollInbox();
    });
  }

  Future<void> pollInbox() async {
    if (!AuthService.instance.registered) return;
    final myGen = ++_pollGeneration;
    try {
      final rows = await TripApi.instance.bookingsInbox();
      // Shu kutish paytida yana yangiroq pollInbox() boshlangan bo'lsa, bu
      // javob endi eskirgan — qo'llamaymiz (pastdagi izohga qarang).
      if (myGen != _pollGeneration) return;
      final seenIds = <String>{};
      for (final row in rows) {
        final order = _orderFromServerRow(row);
        seenIds.add(order.id);
        await addPassengerOrder(order);
      }
      // Yo'lovchi band qilishni bekor qilsa (tasdiqlashdan oldin HAM,
      // tasdiqlangandan KEYIN ham) yoki muddati o'tsa, bu band qilish endi
      // `/inbox`da ko'rinmaydi — shuni mahalliyda ham "bekor qilindi" deb
      // belgilaymiz, aks holda eski so'rov haydovchi ekranida abadiy osilib
      // qolardi. `open` (PENDING) holati bundan mustasno — u faqat ONLAYN
      // paytda tekshiriladi, chunki backend PENDING qatorlarni oflaynda
      // ataylab yashiradi (yangi ish ko'rsatilmasligi kerak), shuning uchun
      // "yo'qligi" u holatda hali bekor qilindi degani emas. COUNTERED/
      // CONFIRMED/DRIVER_ON_WAY esa backend tomonidan oflaynda HAM doim
      // qaytariladi (haydovchining faol majburiyati) — shuning uchun ular
      // online holatidan qat'i nazar tekshiriladi, aks holda haydovchi
      // oflaynga o'tganda yo'lovchi bekor qilgan tasdiqlangan safar abadiy
      // "faol" ko'rinib qolaveradi.
      final staleIds = orders
          .where((o) =>
              o.kind == PassengerOrderKind.instant &&
              _isForMe(o) &&
              !seenIds.contains(o.id) &&
              (o.status == PassengerOrderStatus.counterOffered ||
                  o.status == PassengerOrderStatus.accepted ||
                  o.status == PassengerOrderStatus.onWay ||
                  (o.status == PassengerOrderStatus.open && isOnline)))
          .map((o) => o.id)
          .toList();
      if (staleIds.isNotEmpty) {
        orders = [
          for (final o in orders)
            if (staleIds.contains(o.id))
              o.copyWith(status: PassengerOrderStatus.cancelled)
            else
              o,
        ];
        await _persistOrders();
        setDriverNotice(tr('Yo‘lovchi safarni bekor qildi.'));
      }
    } catch (_) {
      // Internet yo'q yoki server javob bermadi — mahalliy ro'yxat o'zgarishsiz qoladi.
    }
    if (myGen != _pollGeneration) return;
    await _pollPrebookInbox(myGen);
  }

  /// Oldindan bron so'rovlarini serverdan tortadi. Bitta so'rovga bir nechta
  /// haydovchi javob berishi mumkin (broadcast) — shuning uchun, agar bu
  /// safar boshqa haydovchiga berilgan bo'lsa, server uni endi bu haydovchi
  /// uchun `/inbox`da ko'rsatmaydi; shuni "poll'dan tushib qoldi" deb bilib,
  /// mahalliy nusxasini yopamiz (aks holda "qabul qilindi" degan abadiy
  /// noto'g'ri holatda osilib qolardi).
  Future<void> _pollPrebookInbox(int myGen) async {
    try {
      final rows = await RequestApi.instance.inbox();
      if (myGen != _pollGeneration) return;
      final seenIds = <String>{};
      var droppedAny = false;
      for (final row in rows) {
        final order = _prebookOrderFromServerRow(row);
        if (order == null) continue;
        seenIds.add(order.id);
        await addPassengerOrder(order);
      }
      // `/requests/inbox` endi haydovchi vaqtincha oflayn ko'ringanda ham
      // ACCEPTED/SELECTED/CONFIRMED qatorlarini ko'rsatadi (backend tuzatildi
      // — faqat yangi PENDING ishlar oflaynda yashiriladi), shuning uchun
      // haqiqiy "yo'lovchi bekor qildi/boshqa haydovchini tanladi" holati
      // bitta pollda ham ishonchli aniqlanadi — kechiktirish shart emas
      // (avval shart edi, chunki eski backend bir lahzalik oflayn
      // holatida ham BARCHASINI bo'sh qaytarib, haqiqiy bekor qilishni
      // soxta bekor qilishdan ajrata olmasdi).
      final staleIds = orders
          .where((o) =>
              o.kind == PassengerOrderKind.prebook &&
              _isForMe(o) &&
              !seenIds.contains(o.id) &&
              (o.status == PassengerOrderStatus.counterOffered ||
                  o.status == PassengerOrderStatus.accepted ||
                  (o.status == PassengerOrderStatus.open && isOnline)))
          .map((o) => o.id)
          .toList();
      if (staleIds.isNotEmpty) {
        orders = [
          for (final o in orders)
            if (staleIds.contains(o.id)) o.copyWith(status: PassengerOrderStatus.cancelled) else o,
        ];
        droppedAny = true;
        await _persistOrders();
      }
      if (droppedAny) {
        setDriverNotice(tr('Yo‘lovchi boshqa haydovchini tanladi.'));
      }
      notifyListeners();
    } catch (_) {
      // Internet yo'q yoki server javob bermadi — mahalliy ro'yxat o'zgarishsiz qoladi.
    }
  }

  PassengerOrderStatus _mapPrebookStatus(String myResponseStatus, String requestStatus) {
    switch (myResponseStatus) {
      case 'PENDING':
        return PassengerOrderStatus.open;
      case 'ACCEPTED':
        return PassengerOrderStatus.awaitingSelection;
      case 'SELECTED':
      case 'CONFIRMED':
        return switch (requestStatus) {
          'DRIVER_ON_WAY' => PassengerOrderStatus.onWay,
          'PASSENGER_PICKED' || 'IN_PROGRESS' => PassengerOrderStatus.pickedUp,
          'COMPLETED' => PassengerOrderStatus.done,
          _ => PassengerOrderStatus.accepted,
        };
      default:
        return PassengerOrderStatus.cancelled;
    }
  }

  /// Server so'rov qatorini mahalliy `PassengerOrder`ga aylantiradi.
  /// `responses` backend tomonidan allaqachon shu haydovchining o'z javobiga
  /// filtrlangan (requests.py: `_build_request_out(..., viewer_driver_id=...)`),
  /// shuning uchun bu yerda bitta elementdan ko'p bo'lmaydi.
  PassengerOrder? _prebookOrderFromServerRow(TripRequestDto dto) {
    final row = dto.raw;
    final responses = (row['responses'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (responses.isEmpty) return null;
    final myResponse = responses.first;
    final id = 'req_${row['id']}';
    final name = row['passenger_name'] as String?;
    final scheduled = DateTime.tryParse(row['scheduled_at'] as String? ?? '');
    return PassengerOrder(
      id: id,
      kind: PassengerOrderKind.prebook,
      from: row['from_text'] as String? ?? '',
      to: row['to_text'] as String? ?? '',
      exactPickup: row['exact_place'] as String? ?? '',
      passengers: row['passengers_count'] as int? ?? 1,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      dateLabel: scheduled == null
          ? ''
          : '${scheduled.day.toString().padLeft(2, '0')}.${scheduled.month.toString().padLeft(2, '0')}',
      timeLabel: scheduled == null
          ? ''
          : '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
      offeredPrice: row['offered_price'] as int? ?? 0,
      agreedPrice: myResponse['offered_price'] as int?,
      passengerName: (name != null && name.isNotEmpty) ? name : tr('Yo‘lovchi'),
      passengerPhone: row['passenger_phone'] as String? ?? '',
      status: _mapPrebookStatus(
        myResponse['status'] as String? ?? 'PENDING',
        row['status'] as String? ?? 'SEARCHING',
      ),
      targetTaxiId: myDriverId,
      expiresAt: DateTime.tryParse(row['expires_at'] as String? ?? ''),
      broadcastGroupId: id,
      passengerUserId: row['passenger_id'] as int?,
      passengerPhoto: row['passenger_photo'] as String?,
    );
  }

  PassengerOrderStatus _mapServerBookingStatus(String s) => switch (s) {
        'PENDING' => PassengerOrderStatus.open,
        'COUNTERED' => PassengerOrderStatus.counterOffered,
        'CONFIRMED' => PassengerOrderStatus.accepted,
        'DRIVER_ON_WAY' => PassengerOrderStatus.onWay,
        'PASSENGER_PICKED' => PassengerOrderStatus.pickedUp,
        'COMPLETED' => PassengerOrderStatus.done,
        _ => PassengerOrderStatus.cancelled,
      };

  /// Server booking qatorini mahalliy `PassengerOrder`ga aylantiradi.
  /// `targetTaxiId` atayin `'dt_<tripId>'` ko'rinishida — haydovchining o'zi
  /// e'lon qilganda ishlatgan sxema bilan bir xil, aks holda `_isForMe()`
  /// mos kelmay, so'rov hech kimga ko'rinmay qoladi.
  PassengerOrder _orderFromServerRow(Map<String, dynamic> row) {
    final trip = row['trip'] as Map<String, dynamic>;
    final etaArrive = row['eta_arrive_at'] as String?;
    final pickedUpAt = row['picked_up_at'] as String?;
    final expiresAt = row['expires_at'] as String?;
    final name = row['passenger_name'] as String?;
    return PassengerOrder(
      id: 'inst_${row['id']}',
      kind: PassengerOrderKind.instant,
      from: trip['from_text'] as String? ?? '',
      to: trip['to_text'] as String? ?? '',
      exactPickup: row['exact_pickup'] as String? ?? '',
      passengers: row['seats'] as int? ?? 1,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      offeredPrice: trip['price'] as int? ?? 0,
      agreedPrice: row['agreed_price'] as int?,
      passengerName: (name != null && name.isNotEmpty) ? name : tr('Yo‘lovchi'),
      passengerPhone: row['passenger_phone'] as String? ?? '',
      status: _mapServerBookingStatus(row['status'] as String? ?? 'PENDING'),
      driverEtaMinutes: row['eta_minutes'] as int?,
      etaArriveAt: etaArrive == null ? null : DateTime.tryParse(etaArrive),
      pickedUp: pickedUpAt != null,
      pickedUpAt: pickedUpAt == null ? null : DateTime.tryParse(pickedUpAt),
      targetTaxiId: 'dt_${trip['id']}',
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
      passengerUserId: row['passenger_id'] as int?,
      passengerPhoto: row['passenger_photo'] as String?,
      pendingSeats: row['pending_seats'] as int?,
    );
  }

  Future<void> addPassengerOrder(PassengerOrder order) async {
    orders = [order, ...orders.where((o) => o.id != order.id)];
    await _persistOrders();
    notifyListeners();
    await _maybeAutoAccept(order);
  }

  /// Yo'lovchining o'rindiq sonini oshirish so'roviga javob — `accept:
  /// true` bo'lsa haqiqatan amalga oshadi (seats/narx yangilanadi), `false`
  /// bo'lsa joriy son o'zgarishsiz qoladi. Natija: muvaffaqiyatda `null`,
  /// xato bo'lsa xabar matni.
  Future<String?> respondSeatIncrease(String id, bool accept) async {
    final remoteId = _remoteBookingId(id);
    if (remoteId == null) return tr('Bu buyurtma uchun mavjud emas.');
    Map<String, dynamic> row;
    try {
      row = await TripApi.instance.respondSeatIncrease(remoteId, accept);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
    }
    await addPassengerOrder(_orderFromServerRow(row));
    return null;
  }

  /// Haydovchi belgilagan "minimal narx"dan yuqori taklif kelsa, qo‘lda kutmasdan
  /// darhol qabul qilinadi — javob tezligi oshsa, safar soni ham oshadi.
  Future<void> _maybeAutoAccept(PassengerOrder order) async {
    if (order.status != PassengerOrderStatus.open) return;
    DriverPublishedTrip? trip;
    for (final t in myTrips) {
      if (t.id == order.targetTaxiId && t.active && t.minAutoAcceptPrice != null) {
        trip = t;
        break;
      }
    }
    if (trip == null) return;
    if (order.offeredPrice < trip.minAutoAcceptPrice!) return;
    await acceptOrder(order.id);
  }

  /// Natija: muvaffaqiyatda `null`, serverdan xato kelsa foydalanuvchiga
  /// ko‘rsatiladigan xabar matni (masalan, joy boshqa so‘rovga berib
  /// yuborilgan bo‘lsa).
  Future<String?> acceptOrder(String id, {int? driverPrice, int? etaMinutes}) async {
    final order = orderById(id);
    if (order == null) return null;

    final agreed = driverPrice ?? order.offeredPrice;
    final isCounter = agreed != order.offeredPrice;

    final remoteId = _remoteBookingId(id);
    final remoteRequestId = _remoteRequestId(order.broadcastGroupId ?? id);
    if (remoteId != null) {
      try {
        await TripApi.instance.respondBooking(
          remoteId,
          action: 'accept',
          offeredPrice: isCounter ? agreed : null,
          etaMinutes: etaMinutes,
        );
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    } else if (remoteRequestId != null) {
      try {
        await RequestApi.instance.respond(
          remoteRequestId,
          action: 'accept',
          offeredPrice: isCounter ? agreed : null,
        );
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    }

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

    // Haydovchi hali Xabarlar bo'limini ochmagan bo'lsa ham, qabul qilgan
    // zahoti yo'lovchi bilan suhbat tayyor bo'lishi uchun proaktiv yaratamiz.
    ChatService.instance.ensureThread(
      taxi,
      passengerNameOverride: order.passengerName,
      passengerUserIdOverride: order.passengerUserId,
      passengerPhotoOverride: order.passengerPhoto,
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

    if (!isCounter) {
      await _decrementTripSeatsFor(order);
    }

    notifyListeners();
    return null;
  }

  /// Safar sig‘imidan qabul qilingan yo‘lovchi o‘rindiqlarini ayiradi —
  /// o‘z narxida va qarshi narx tasdiqlanganda bir xil chaqiriladi,
  /// aks holda haydovchi sig‘imdan ortiq yo‘lovchi qabul qilib qo‘yishi mumkin.
  Future<void> _decrementTripSeatsFor(PassengerOrder order) async {
    // Faqat `targetTaxiId` haqiqatan ham e'lon qilingan safarga mos kelsa
    // kamaytiramiz. Avval mos kelmasa ham "birinchi faol safar"dan
    // kamaytirib yuborilardi — oldindan bron (targetTaxiId == myDriverId,
    // hech qanday e'lon qilingan safarga tegishli emas) uchun bu butunlay
    // tasodifiy boshqa safarning joy sonini buzib qo'yardi.
    DriverPublishedTrip? trip;
    for (final t in activeTrips) {
      if (t.id == order.targetTaxiId) {
        trip = t;
        break;
      }
    }
    if (trip == null) return;
    final left = (trip.seats - order.passengers).clamp(0, trip.seats);
    myTrips = [
      for (final t in myTrips)
        if (t.id == trip.id) t.copyWith(seats: left, active: left > 0) else t,
    ];
    await _persistTrips();
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
      await _decrementTripSeatsFor(order);
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
  /// Natija: muvaffaqiyatda `null`, serverdan xato kelsa xabar matni.
  Future<String?> rejectOpenOrder(String orderId, {required String reason}) async {
    final order = orderById(orderId);
    if (order == null) return null;
    if (order.status != PassengerOrderStatus.open) {
      await cancelAllForBooking(
        order.broadcastGroupId ?? orderId,
        cancelledBy: 'driver',
        reason: reason,
      );
      return null;
    }

    final remoteId = _remoteBookingId(orderId);
    final remoteRequestId = _remoteRequestId(order.broadcastGroupId ?? orderId);
    if (remoteId != null) {
      try {
        await TripApi.instance.respondBooking(remoteId, action: 'reject', message: reason);
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    } else if (remoteRequestId != null) {
      try {
        await RequestApi.instance.respond(remoteRequestId, action: 'reject');
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
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
    return null;
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

  /// Natija: muvaffaqiyatda `null`, serverdan xato kelsa xabar matni.
  Future<String?> markPassengerPickedUp(String id) async {
    final order = orderById(id);
    final remoteId = _remoteBookingId(id);
    final remoteRequestId = _remoteRequestId(order?.broadcastGroupId ?? id);
    if (remoteId != null) {
      try {
        await TripApi.instance.advanceBookingStatus(remoteId, 'PASSENGER_PICKED');
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    } else if (remoteRequestId != null) {
      try {
        // REQUEST_TRANSITIONS CONFIRMED'dan to'g'ridan-to'g'ri
        // PASSENGER_PICKED'ga o'tishga ruxsat bermaydi — avval DRIVER_ON_WAY
        // kerak. Agar allaqachon shu holatda bo'lsa, bu chaqiruv (joriy==yangi)
        // xavfsiz no-op bo'ladi.
        await RequestApi.instance.setStatus(remoteRequestId, 'DRIVER_ON_WAY');
        await RequestApi.instance.setStatus(remoteRequestId, 'PASSENGER_PICKED');
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    }
    orders = [
      for (final o in orders)
        if (o.id == id)
          o.copyWith(status: PassengerOrderStatus.pickedUp, pickedUp: true, pickedUpAt: DateTime.now(), clearEta: true)
        else
          o,
    ];
    await _persistOrders();
    await ActiveBookingService.instance.markPickedUp(id);
    notifyListeners();
    return null;
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

  /// `driverStars` berilsa (foydalanuvchi baholash dialogida yulduzcha
  /// tanlagan bo'lsa) — yo'lovchining haqiqiy user id'si ma'lum bo'lsa,
  /// baho serverga (`RatingApi`) ham yuboriladi, aks holda faqat mahalliy
  /// "baholandi" belgisi qo'yiladi (eski/mahalliy buyurtmalar uchun).
  /// Natija: muvaffaqiyatda `null`, serverdan xato kelsa xabar matni.
  Future<String?> completeOrder(
    String id, {
    TripCompletedBy completedBy = TripCompletedBy.driver,
    bool driverRatedPassenger = false,
    bool passengerRatedDriver = false,
    int? driverStars,
  }) async {
    final order = orderById(id);
    final remoteId = _remoteBookingId(id);
    final remoteRequestId = _remoteRequestId(order?.broadcastGroupId ?? id);
    if (remoteId != null) {
      try {
        await TripApi.instance.advanceBookingStatus(remoteId, 'COMPLETED');
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    } else if (remoteRequestId != null) {
      try {
        // PASSENGER_PICKED'dan to'g'ridan-to'g'ri COMPLETED'ga o'tib
        // bo'lmaydi — avval IN_PROGRESS kerak.
        await RequestApi.instance.setStatus(remoteRequestId, 'IN_PROGRESS');
        await RequestApi.instance.setStatus(remoteRequestId, 'COMPLETED');
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return tr('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
      }
    }
    await markOrderDone(id);
    await ActiveBookingService.instance.markBookingCompleted(id);
    if (order != null) {
      final remoteTripId = order.targetTaxiId.startsWith('dt_')
          ? int.tryParse(order.targetTaxiId.substring(3))
          : null;
      var ratedPassenger = driverRatedPassenger;
      if (driverStars != null) {
        ratedPassenger = true;
        if (order.passengerUserId != null) {
          try {
            await RatingApi.instance.rate(
              toUserId: order.passengerUserId!,
              stars: driverStars,
              tripId: remoteTripId,
              requestId: remoteRequestId,
            );
          } catch (_) {}
        }
      }
      await TripCompletionService.instance.recordCompletion(
        bookingId: id,
        from: order.from,
        to: order.to,
        price: order.totalPrice,
        completedBy: completedBy,
        passengerName: order.passengerName,
        driverName: ProfileService.instance.fullName.isEmpty
            ? 'Haydovchi'
            : ProfileService.instance.fullName,
        driverRatedPassenger: ratedPassenger,
        passengerRatedDriver: passengerRatedDriver,
        driverUserId: AuthService.instance.user?.id,
        passengerUserId: order.passengerUserId,
        remoteTripId: remoteTripId,
      );
    }
    notifyListeners();
    return null;
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
        final mins = now.difference(trip.createdAt).inMinutes;
        final blockUntil = trip.createdAt.add(Duration(minutes: defaultRouteMinutes * 2));
        if (now.isBefore(blockUntil)) {
          return 'Siz $mins daqiqa oldin shu manzilga safar e’lon qilgansiz, hali bu safar yakunlanmadi. '
              '${blockUntil.hour.toString().padLeft(2, '0')}:${blockUntil.minute.toString().padLeft(2, '0')} dan keyin qayta e’lon qiling.';
        }
      } else if (opposite) {
        final mins = now.difference(trip.createdAt).inMinutes;
        final blockUntil = trip.createdAt.add(Duration(minutes: defaultRouteMinutes));
        if (now.isBefore(blockUntil)) {
          return 'Siz $mins daqiqa oldin qarama-qarshi yo‘nalishga safar e’lon qilgansiz, hali bu safar yakunlanmadi. '
              '${blockUntil.hour.toString().padLeft(2, '0')}:${blockUntil.minute.toString().padLeft(2, '0')} dan keyin qayta e’lon qiling.';
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
    int? minAutoAcceptPrice,
    List<String> toAliases = const [],
    DateTime? scheduledAt,
  }) async {
    final block = publishBlockReason(from: from, to: to);
    if (block != null) throw StateError(block);
    var scheduled = scheduledAt ?? DateTime.now().add(const Duration(minutes: 5));
    if (scheduled.isBefore(DateTime.now())) {
      scheduled = DateTime.now().add(const Duration(minutes: 1));
    }
    var id = 'dt_${DateTime.now().microsecondsSinceEpoch}';
    final fromText = from.trim().isEmpty ? 'Ochiq' : from.trim();
    final toText = to.trim().isEmpty ? 'Yo‘nalish ochiq' : to.trim();
    try {
      final remote = await TripApi.instance.create({
        'from_text': fromText,
        'to_text': toText == fromText ? '$toText (qaytish)' : toText,
        'scheduled_at': scheduled.toIso8601String(),
        'seats_total': seats.clamp(1, 15),
        'price': price < 0 ? 0 : price,
        if (toAliases.isNotEmpty) 'to_note': toAliases.join(', '),
      });
      final remoteId = remote['id'];
      if (remoteId != null) id = 'dt_$remoteId';
    } on ApiException catch (e) {
      // Server haqiqiy xatolik qaytardi (masalan, 20 daqiqa cheklovi) —
      // mahalliy nusxa yaratilmaydi, aniq sabab bilan to‘xtatiladi.
      throw StateError(e.message);
    } catch (_) {
      // Internet yo‘q yoki server javob bermadi — soxta "muvaffaqiyat"
      // ko‘rsatib, mahalliy nusxa yaratish o‘rniga aniq xato beramiz, aks
      // holda foydalanuvchi bir necha marta bosib, internet qaytganda
      // bir nechta takroriy safar e’lon qilinib qolishi mumkin edi.
      throw StateError('Internet aloqasi yo‘q yoki server javob bermadi. Qayta urinib ko‘ring.');
    }
    final trip = DriverPublishedTrip(
      id: id,
      from: from,
      to: to,
      toAliases: toAliases,
      timeLabel: timeLabel,
      dateLabel: dateLabel,
      seats: seats,
      price: price,
      createdAt: DateTime.now(),
      minAutoAcceptPrice: (minAutoAcceptPrice != null && minAutoAcceptPrice > 0) ? minAutoAcceptPrice : null,
    );
    myTrips = [trip, ...myTrips];
    await _persistTrips();
    notifyListeners();
  }

  Future<void> deactivateTrip(String id) async {
    // Serverda yaratilgan safar bo'lsa — uni ham bekor qilamiz, aks holda
    // yo'lovchiga u hamon ochiq (band qilish mumkin) bo'lib ko'rinaveradi.
    if (id.startsWith('dt_')) {
      final remoteId = int.tryParse(id.substring(3));
      if (remoteId != null) {
        try {
          await TripApi.instance.cancel(remoteId);
        } catch (_) {
          // Server bilan bog'lanib bo'lmasa ham mahalliy holatni yopamiz —
          // keyingi sinxronlashda farq to'g'rilanadi.
        }
      }
    }
    myTrips = [
      for (final t in myTrips)
        if (t.id == id) t.copyWith(active: false) else t,
    ];
    await _persistTrips();
    notifyListeners();
  }

  /// Serverdagi haqiqiy band qilishlarni (boshqa qurilmadan tasdiqlangan
  /// bo‘lsa ham) mahalliy ro‘yxatga tortadi — joy soni va faollik holatini
  /// yangilaydi.
  Future<void> syncFromServer() async {
    try {
      final remoteTrips = await TripApi.instance.mine();
      final byRemoteId = <int, Map<String, dynamic>>{
        for (final t in remoteTrips)
          if (t['id'] != null) t['id'] as int: t,
      };
      final matchedIds = <int>{};
      myTrips = [
        for (final t in myTrips)
          if (t.id.startsWith('dt_') && int.tryParse(t.id.substring(3)) != null)
            () {
              final remoteId = int.parse(t.id.substring(3));
              final remote = byRemoteId[remoteId];
              if (remote == null) return t;
              matchedIds.add(remoteId);
              final seatsAvailable = remote['seats_available'] as int? ?? t.seats;
              final status = remote['status'] as String? ?? '';
              final stillActive = status == 'OPEN' || status == 'FULL';
              return t.copyWith(seats: seatsAvailable, active: stillActive);
            }()
          else
            t,
      ];
      // Serverda bor, lekin mahalliy ro'yxatda yo'q safarlar (masalan ilova
      // qayta o'rnatilgan yoki boshqa qurilmada kirilgan) — yangi yozuv
      // sifatida qo'shamiz, aks holda haydovchi "Mening safarlarim"da
      // bo'sh ro'yxat ko'rib, qayta e'lon qilishga urinib ko'rardi.
      final newOnes = <DriverPublishedTrip>[];
      for (final entry in byRemoteId.entries) {
        if (matchedIds.contains(entry.key)) continue;
        final remote = entry.value;
        final scheduled = DateTime.tryParse(remote['scheduled_at'] as String? ?? '');
        final created = DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now();
        final status = remote['status'] as String? ?? '';
        newOnes.add(DriverPublishedTrip(
          id: 'dt_${entry.key}',
          from: remote['from_text'] as String? ?? '',
          to: remote['to_text'] as String? ?? '',
          timeLabel: scheduled == null
              ? ''
              : '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
          dateLabel: scheduled == null
              ? ''
              : '${scheduled.day.toString().padLeft(2, '0')}.${scheduled.month.toString().padLeft(2, '0')}',
          seats: remote['seats_available'] as int? ?? remote['seats_total'] as int? ?? 1,
          price: remote['price'] as int? ?? 0,
          createdAt: created,
          active: status == 'OPEN' || status == 'FULL',
        ));
      }
      if (newOnes.isNotEmpty) {
        // Yuqoridagi `await TripApi.instance.mine()`dan keyin, bu yerga
        // yetib kelgunga qadar boshqa joyda (masalan bir vaqtda ishlagan
        // publishTrip()) xuddi shu id allaqachon qo'shilib qolgan bo'lishi
        // mumkin — qayta tekshirib, takrorlanishni oldini olamiz.
        final currentIds = myTrips.map((t) => t.id).toSet();
        final toAdd = newOnes.where((t) => !currentIds.contains(t.id));
        myTrips = [...toAdd, ...myTrips];
      }
      await _persistTrips();
      notifyListeners();
    } catch (_) {
      // Internet yo‘q — mahalliy ro‘yxat o‘zgarishsiz qoladi.
    }
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
    final groupId = bookingId ?? (prebook ? 'pre_${DateTime.now().microsecondsSinceEpoch}' : null);

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
        id: bookingId ?? 'po_${DateTime.now().microsecondsSinceEpoch}',
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
