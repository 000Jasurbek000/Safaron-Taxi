import 'dart:async';
import '../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/taxi_offer.dart';
import '../../services/active_booking_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../services/api_client.dart';
import '../../services/platform_config_service.dart';
import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/eta_util.dart';
import '../../widgets/booking_mockup.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/safaron_header.dart';

class DriverOnWayScreen extends StatefulWidget {
  const DriverOnWayScreen({
    super.key,
    required this.taxi,
    required this.seats,
    this.pickupLabel,
    this.bookingId,
  });

  final TaxiOffer taxi;
  final int seats;
  final String? pickupLabel;
  final String? bookingId;

  @override
  State<DriverOnWayScreen> createState() => _DriverOnWayScreenState();
}

class _DriverOnWayScreenState extends State<DriverOnWayScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final b = _booking;
      if (b != null && b.status == BookingStatus.onWay && b.etaArriveAt != null && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  ActiveBooking? get _booking {
    if (widget.bookingId != null) {
      return ActiveBookingService.instance.byId(widget.bookingId!);
    }
    return ActiveBookingService.instance.instantBooking;
  }

  Future<void> _cancel() async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;
    final id = _booking?.id;
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

  Future<void> _complete() async {
    final id = _booking?.id;
    if (id == null) return;
    final stars = await showTripRatingDialog(context, title: tr('Haydovchini baholang'));
    if (stars == null || !mounted) return;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Safarni boshlash uchun joylashuv xizmatini yoqing.'))),
          );
        }
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('Safaron uchun joylashuv ruxsatini bering.'))),
            );
          }
        } else {
          final pos = await Geolocator.getCurrentPosition();
          await PlatformConfigService.instance.reportGps(
            bookingId: id,
            role: 'passenger',
            phase: 'END',
            lat: pos.latitude,
            lng: pos.longitude,
            accuracy: pos.accuracy,
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Server bilan bog‘lanib bo‘lmadi. Keyinroq urinib ko‘ring.'))),
        );
      }
    }
    await ActiveBookingService.instance.complete(
      id,
      completedBy: TripCompletedBy.passenger,
      passengerRatedDriver: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Safar yakunlandi · $stars★'), behavior: SnackBarBehavior.floating),
    );
    goToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ActiveBookingService.instance,
      builder: (context, _) {
        final booking = _booking;
        final taxi = booking?.taxi ?? widget.taxi;
        final status = booking?.status ?? BookingStatus.onWay;
        final pickedUp = status == BookingStatus.pickedUp;
        final onWay = status == BookingStatus.onWay || status == BookingStatus.confirmed;

        final title = pickedUp ? 'Safarda' : tr("Haydovchi yo'lda");
        final subtitle = pickedUp ? null : tr('Haydovchi siz tomon harakatlanmoqda');

        final fromLabel = booking?.pickupLabel ?? widget.pickupLabel ?? taxi.from;
        final routeText = '$fromLabel → ${booking?.to ?? taxi.to}';

        String? etaLine;
        if (onWay && booking?.etaArriveAt != null) {
          etaLine = EtaUtil.countdownLabel(booking!.etaArriveAt!);
        }

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Column(
              children: [
                const SafaronBookingHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy)),
                      if (subtitle != null)
                        Text(subtitle, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            options: const MapOptions(
                              initialCenter: _center,
                              initialZoom: 13.8,
                              interactionOptions: InteractionOptions(
                                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.safaron.app',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(points: const [_driver, _center], color: AppColors.primary, strokeWidth: 4),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _driver,
                                    width: 40,
                                    height: 40,
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.local_taxi_rounded, color: AppColors.primary, size: 22),
                                    ),
                                  ),
                                  const Marker(
                                    point: _center,
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.topCenter,
                                    child: Icon(Icons.location_on_rounded, color: AppColors.destination, size: 32),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DriverVehicleCard(taxi: taxi, showTelegram: false),
                      const SizedBox(height: 10),
                      SoftCard(
                        child: Column(
                          children: [
                            _Detail(Icons.route_rounded, routeText),
                            if (etaLine != null) _Detail(Icons.timer_outlined, etaLine, highlight: true),
                            _Detail(Icons.event_seat_outlined, '${widget.seats} ta joy'),
                            _Detail(Icons.payments_outlined, taxi.priceLabel),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      InfoBanner(
                        text: pickedUp
                            ? tr('Manzilga yetib bordingizmi? Safarni yakunlang.')
                            : tr('Haydovchi siz tomon yaqinlashmoqda. Iltimos, belgilangan joyda bo‘ling.'),
                      ),
                    ],
                  ),
                ),
                if (pickedUp)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _complete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(tr('Safarni yakunlash'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                if (!pickedUp)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: CancelBookingButton(
                      label: tr('Bekor qilish'),
                      onPressed: _cancel,
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

  static const _center = LatLng(41.6911, 60.7525);
  static const _driver = LatLng(41.6985, 60.7602);
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.text, {this.highlight = false});
  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? AppColors.primaryDark : AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                fontSize: highlight ? 14 : 13,
                color: highlight ? AppColors.primaryDark : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
