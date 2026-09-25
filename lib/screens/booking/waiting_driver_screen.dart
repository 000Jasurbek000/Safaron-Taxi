import 'dart:async';
import '../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/taxi_offer.dart';
import '../../services/active_booking_service.dart';
import '../../services/driver_trip_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/booking_mockup.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../widgets/counter_offer_card.dart';
import '../../widgets/duplicate_route_dialog.dart';
import '../../widgets/nav_actions.dart';
import 'driver_on_way_screen.dart';

class WaitingDriverScreen extends StatefulWidget {
  const WaitingDriverScreen({
    super.key,
    required this.taxi,
    required this.seats,
    this.exactPickup = '',
    this.bookingId,
    this.forceInstant = false,
  });

  final TaxiOffer taxi;
  final int seats;
  final String exactPickup;
  final String? bookingId;
  final bool forceInstant;

  @override
  State<WaitingDriverScreen> createState() => _WaitingDriverScreenState();
}

class _WaitingDriverScreenState extends State<WaitingDriverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;
  bool _started = false;
  int _elapsed = 0;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBooking());
  }

  Future<void> _ensureBooking() async {
    if (_started) return;
    _started = true;
    final svc = ActiveBookingService.instance;
    final existing = widget.bookingId != null
        ? svc.byId(widget.bookingId!)
        : svc.activeBookings.where((b) => b.taxi.id == widget.taxi.id && b.isActive).firstOrNull;

    if (existing == null) {
      final err = await svc.startInstant(
        taxi: widget.taxi,
        seats: widget.seats,
        pickupLabel: widget.exactPickup.trim().isEmpty
            ? widget.taxi.from
            : '${widget.taxi.from} · ${widget.exactPickup.trim()}',
        force: widget.forceInstant,
      );
      if (err != null && mounted) {
        if (err.contains('faol bron')) {
          final proceed = await showDuplicateRouteDialog(context);
          if (!mounted) return;
          if (!proceed) {
            Navigator.of(context).maybePop();
            return;
          }
          final retry = await svc.startInstant(
            taxi: widget.taxi,
            seats: widget.seats,
            pickupLabel: widget.exactPickup.trim().isEmpty
                ? widget.taxi.from
                : '${widget.taxi.from} · ${widget.exactPickup.trim()}',
            force: true,
          );
          if (retry != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(retry), behavior: SnackBarBehavior.floating),
            );
            Navigator.of(context).maybePop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
          );
          Navigator.of(context).maybePop();
        }
      }
    }
  }

  String? get _bookingId {
    final id = widget.bookingId;
    if (id != null) return id;
    final list = ActiveBookingService.instance.activeBookings
        .where((b) => b.kind == BookingKind.instant && b.taxi.id == widget.taxi.id);
    return list.isEmpty ? ActiveBookingService.instance.instantBooking?.id : list.first.id;
  }

  ActiveBooking? get _booking {
    final id = _bookingId;
    if (id == null) return ActiveBookingService.instance.instantBooking;
    return ActiveBookingService.instance.byId(id);
  }

  void _maybeNavigate(ActiveBooking? b) {
    if (b == null || !mounted) return;
    if (b.status == BookingStatus.onWay ||
        b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.pickedUp) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DriverOnWayScreen(
            taxi: b.taxi,
            seats: b.seats,
            pickupLabel: b.pickupLabel,
            bookingId: b.id,
          ),
        ),
      );
    }
  }

  Future<void> _exitKeep() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Chiqish', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
        content: Text(
          "So'rov davom etadi. «Faol bron» orqali topasiz.",
          style: GoogleFonts.montserrat(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Yo'q")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Ha'))),
        ],
      ),
    );
    if (ok == true && mounted) goToHome(context);
  }

  Future<void> _cancel() async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;
    final id = _bookingId;
    if (id != null) {
      await TripCancelService.instance.cancelByPassenger(
        bookingId: id,
        reason: reason,
        kind: BookingKind.instant,
      );
    } else {
      final b = ActiveBookingService.instance.instantBooking;
      if (b != null) {
        await TripCancelService.instance.cancelByPassenger(
          bookingId: b.id,
          reason: reason,
          kind: BookingKind.instant,
        );
      }
    }
    if (!mounted) return;
    goToHome(context);
  }

  Future<void> _recall() async {
    final id = _bookingId;
    if (id != null) {
      await DriverTripService.instance.passengerCancelRequest(id);
      await ActiveBookingService.instance.clear(bookingId: id);
    } else {
      await ActiveBookingService.instance.clear(kind: BookingKind.instant);
    }
    _started = false;
    if (mounted) setState(() => _elapsed = 0);
    await _ensureBooking();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ActiveBookingService.instance, DriverTripService.instance]),
      builder: (context, _) {
        final notice = DriverTripService.instance.lastPassengerNotice;
        if (notice != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DriverTripService.instance.clearPassengerNotice();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(notice), behavior: SnackBarBehavior.floating),
              );
            }
          });
        }

        final b = _booking;
        if (b != null &&
            b.status != BookingStatus.waiting &&
            b.status != BookingStatus.counterOffer &&
            b.status != BookingStatus.expired) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeNavigate(b));
        }

        final isExpired = b?.status == BookingStatus.expired;
        final isCounter = b?.status == BookingStatus.counterOffer;
        final offlineWaitEnded = !widget.taxi.isOnline && _elapsed >= 3600;
        final waitLabel = () {
          final left = (3600 - _elapsed).clamp(0, 3600);
          final m = (left ~/ 60).toString().padLeft(2, '0');
          final s = (left % 60).toString().padLeft(2, '0');
          return '$m:$s';
        }();

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      AppBackButton(onTap: _exitKeep),
                      const Spacer(),
                    ],
                  ),
                ),
                const Spacer(),
                if (isExpired) ...[
                  Icon(Icons.info_outline_rounded, size: 56, color: AppColors.destination),
                  const SizedBox(height: 16),
                  Text(
                    tr('So‘rov yopildi'),
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      b?.statusMessage ?? tr('Haydovchi javob bermadi. Boshqa haydovchini tanlang.'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                    ),
                  ),
                ] else if (isCounter && b != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CounterOfferCard(
                      bookingId: b.id,
                      offeredPrice: b.offeredPrice ?? b.taxi.price,
                      counterPrice: b.counterPrice ?? b.taxi.price,
                      driverName: b.taxi.driverName,
                      onConfirmed: () => _maybeNavigate(ActiveBookingService.instance.byId(b.id)),
                      onRejected: () {
                        if (mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ] else ...[
                  const RadarPulse(),
                  const SizedBox(height: 20),
                  Text(
                    tr('Haydovchi javobini kutyapmiz'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.taxi.isOnline
                          ? "So'rovingiz faqat tanlangan haydovchiga yuborildi. 1 soat ichida javob kutiladi."
                          : "Haydovchi oflayn. 1 soat kutish — keyin qayta chaqirish yoki bekor qilish mumkin.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                    ),
                  ),
                  if (!widget.taxi.isOnline) ...[
                    const SizedBox(height: 10),
                    Text(
                      waitLabel,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primaryDark),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (context, _) {
                      final phase = (_dots.value * 3).floor() % 3;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == phase ? AppColors.primary : const Color(0xFFC8E6D5),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
                const Spacer(),
                if (!isExpired && offlineWaitEnded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.destination,
                              side: const BorderSide(color: AppColors.destination),
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(tr('Bekor qilish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _recall,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(tr('Qayta chaqirish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isExpired)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: CancelBookingButton(onPressed: _cancel),
                  ),
                if (isExpired)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => goToHome(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(tr('Boshqa haydovchi tanlash'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                const BottomHomeBar(),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
