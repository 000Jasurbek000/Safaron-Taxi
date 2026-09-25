import 'dart:convert';
import '../l10n/phrase.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TripCompletedBy { driver, passenger }

enum TripOutcome { completed, cancelled, expired }

class CompletedTripRecord {
  const CompletedTripRecord({
    required this.bookingId,
    required this.from,
    required this.to,
    required this.price,
    required this.completedAt,
    required this.completedBy,
    this.passengerName = 'Yo‘lovchi',
    this.driverName = 'Haydovchi',
    this.driverRatedPassenger = false,
    this.passengerRatedDriver = false,
    this.outcome = TripOutcome.completed,
    this.cancelReason,
    this.cancelledBy,
  });

  final String bookingId;
  final String from;
  final String to;
  final int price;
  final DateTime completedAt;
  final TripCompletedBy completedBy;
  final String passengerName;
  final String driverName;
  final bool driverRatedPassenger;
  final bool passengerRatedDriver;
  final TripOutcome outcome;
  final String? cancelReason;
  final String? cancelledBy;

  String get routeLabel {
    if (from.isEmpty && to.isEmpty) return 'Safar';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from → $to';
  }

  bool get needsDriverRating => outcome == TripOutcome.completed && !driverRatedPassenger;
  bool get needsPassengerRating => outcome == TripOutcome.completed && !passengerRatedDriver;

  String get outcomeLabel => switch (outcome) {
        TripOutcome.completed => tr('Yakunlangan'),
        TripOutcome.cancelled => tr('Bekor qilingan'),
        TripOutcome.expired => tr('Muddati o‘tgan'),
      };

  CompletedTripRecord copyWith({
    bool? driverRatedPassenger,
    bool? passengerRatedDriver,
  }) {
    return CompletedTripRecord(
      bookingId: bookingId,
      from: from,
      to: to,
      price: price,
      completedAt: completedAt,
      completedBy: completedBy,
      passengerName: passengerName,
      driverName: driverName,
      driverRatedPassenger: driverRatedPassenger ?? this.driverRatedPassenger,
      passengerRatedDriver: passengerRatedDriver ?? this.passengerRatedDriver,
    );
  }

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'from': from,
        'to': to,
        'price': price,
        'completedAt': completedAt.toIso8601String(),
        'completedBy': completedBy.name,
        'passengerName': passengerName,
        'driverName': driverName,
        'driverRatedPassenger': driverRatedPassenger,
        'passengerRatedDriver': passengerRatedDriver,
        'outcome': outcome.name,
        if (cancelReason != null) 'cancelReason': cancelReason,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
      };

  static CompletedTripRecord fromJson(Map<String, dynamic> j) => CompletedTripRecord(
        bookingId: j['bookingId'] as String,
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        price: j['price'] as int? ?? 0,
        completedAt: DateTime.parse(j['completedAt'] as String),
        completedBy: TripCompletedBy.values.byName(j['completedBy'] as String),
        passengerName: j['passengerName'] as String? ?? tr('Yo‘lovchi'),
        driverName: j['driverName'] as String? ?? 'Haydovchi',
        driverRatedPassenger: j['driverRatedPassenger'] as bool? ?? false,
        passengerRatedDriver: j['passengerRatedDriver'] as bool? ?? false,
        outcome: TripOutcome.values.byName(j['outcome'] as String? ?? 'completed'),
        cancelReason: j['cancelReason'] as String?,
        cancelledBy: j['cancelledBy'] as String?,
      );
}

class EarningsSummary {
  const EarningsSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.total,
    required this.tripCount,
  });

  final int today;
  final int week;
  final int month;
  final int total;
  final int tripCount;
}

class TripCompletionService extends ChangeNotifier {
  TripCompletionService._();
  static final TripCompletionService instance = TripCompletionService._();

  static const _kKey = 'safaron_completed_trips_v1';

  List<CompletedTripRecord> records = [];
  bool _loaded = false;

  /// Baholash kutilayotgan safar (darhol dialog uchun).
  String? pendingDriverRatingBookingId;
  String? pendingPassengerRatingBookingId;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        records = list.map((e) => CompletedTripRecord.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        records = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  CompletedTripRecord? byBookingId(String id) {
    try {
      return records.firstWhere((r) => r.bookingId == id);
    } catch (_) {
      return null;
    }
  }

  int get passengerTripCount => records.length;

  int get driverCompletedCount => records.length;

  EarningsSummary get earningsSummary {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    var today = 0;
    var week = 0;
    var month = 0;
    var total = 0;

    for (final r in records) {
      final p = r.price;
      total += p;
      if (!r.completedAt.isBefore(todayStart)) today += p;
      if (!r.completedAt.isBefore(weekStart)) week += p;
      if (!r.completedAt.isBefore(monthStart)) month += p;
    }

    return EarningsSummary(
      today: today,
      week: week,
      month: month,
      total: total,
      tripCount: records.length,
    );
  }

  List<CompletedTripRecord> recordsSince(DateTime from) =>
      records.where((r) => !r.completedAt.isBefore(from)).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  Future<CompletedTripRecord> recordCancellation({
    required String bookingId,
    required String from,
    required String to,
    required int price,
    required String cancelledBy,
    required String reason,
    String passengerName = 'Yo‘lovchi',
    String driverName = 'Haydovchi',
  }) async {
    final existing = byBookingId(bookingId);
    if (existing != null && existing.outcome == TripOutcome.completed) return existing;

    final record = CompletedTripRecord(
      bookingId: bookingId,
      from: from,
      to: to,
      price: price,
      completedAt: DateTime.now(),
      completedBy: cancelledBy == 'driver' ? TripCompletedBy.driver : TripCompletedBy.passenger,
      passengerName: passengerName,
      driverName: driverName,
      outcome: TripOutcome.cancelled,
      cancelReason: reason,
      cancelledBy: cancelledBy,
      driverRatedPassenger: true,
      passengerRatedDriver: true,
    );
    records = [record, ...records.where((r) => r.bookingId != bookingId)];
    pendingDriverRatingBookingId = null;
    pendingPassengerRatingBookingId = null;
    await _persist();
    notifyListeners();
    return record;
  }

  Future<CompletedTripRecord> recordCompletion({
    required String bookingId,
    required String from,
    required String to,
    required int price,
    required TripCompletedBy completedBy,
    String passengerName = 'Yo‘lovchi',
    String driverName = 'Haydovchi',
    bool driverRatedPassenger = false,
    bool passengerRatedDriver = false,
  }) async {
    final existing = byBookingId(bookingId);
    if (existing != null) {
      final updated = existing.copyWith(
        driverRatedPassenger: driverRatedPassenger || existing.driverRatedPassenger,
        passengerRatedDriver: passengerRatedDriver || existing.passengerRatedDriver,
      );
      records = [for (final r in records) if (r.bookingId == bookingId) updated else r];
      await _persist();
      _updatePending(updated);
      notifyListeners();
      return updated;
    }

    final record = CompletedTripRecord(
      bookingId: bookingId,
      from: from,
      to: to,
      price: price,
      completedAt: DateTime.now(),
      completedBy: completedBy,
      passengerName: passengerName,
      driverName: driverName,
      driverRatedPassenger: driverRatedPassenger,
      passengerRatedDriver: passengerRatedDriver,
    );
    records = [record, ...records];
    await _persist();
    _updatePending(record);
    notifyListeners();
    return record;
  }

  void _updatePending(CompletedTripRecord r) {
    if (r.needsDriverRating) {
      pendingDriverRatingBookingId = r.bookingId;
    } else if (pendingDriverRatingBookingId == r.bookingId) {
      pendingDriverRatingBookingId = null;
    }
    if (r.needsPassengerRating) {
      pendingPassengerRatingBookingId = r.bookingId;
    } else if (pendingPassengerRatingBookingId == r.bookingId) {
      pendingPassengerRatingBookingId = null;
    }
  }

  Future<void> markDriverRatedPassenger(String bookingId) async {
    final r = byBookingId(bookingId);
    if (r == null) return;
    records = [
      for (final item in records)
        if (item.bookingId == bookingId) item.copyWith(driverRatedPassenger: true) else item,
    ];
    if (pendingDriverRatingBookingId == bookingId) pendingDriverRatingBookingId = null;
    await _persist();
    notifyListeners();
  }

  Future<void> markPassengerRatedDriver(String bookingId) async {
    final r = byBookingId(bookingId);
    if (r == null) return;
    records = [
      for (final item in records)
        if (item.bookingId == bookingId) item.copyWith(passengerRatedDriver: true) else item,
    ];
    if (pendingPassengerRatingBookingId == bookingId) pendingPassengerRatingBookingId = null;
    await _persist();
    notifyListeners();
  }

  void clearPendingForRole({required bool isDriver}) {
    if (isDriver) {
      pendingDriverRatingBookingId = null;
    } else {
      pendingPassengerRatingBookingId = null;
    }
    notifyListeners();
  }
}
