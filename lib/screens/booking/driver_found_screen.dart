import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/phrase.dart';
import '../../models/taxi_offer.dart';
import '../../services/active_booking_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../services/driver_exclusion_service.dart';
import '../../services/driver_trip_service.dart';
import '../../services/safaron_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_mockup.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/safaron_header.dart';
import 'prebook_screen.dart';
import 'prebook_waiting_screen.dart';
import 'trip_confirmed_screen.dart';

class DriverFoundScreen extends StatelessWidget {
  const DriverFoundScreen({
    super.key,
    required this.request,
    required this.taxi,
    this.remoteRequestId,
    this.remoteDriverId,
  });

  final PrebookRequest request;
  final TaxiOffer taxi;
  final int? remoteRequestId;
  final int? remoteDriverId;

  Future<void> _askAnother(BuildContext context) async {
    DriverExclusionService.instance.excludeForTwoHours(taxi.id);
    final booking = ActiveBookingService.instance.prebookBooking;
    if (booking != null) {
      await DriverTripService.instance.cancelBroadcastForTarget(booking.id, taxi.id);
    }
    await ActiveBookingService.instance.setStatus(BookingStatus.waiting, kind: BookingKind.prebook);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrebookWaitingScreen(request: request, excludedIds: {taxi.id}),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !context.mounted) return;
    final b = ActiveBookingService.instance.prebookBooking;
    final id = b?.id ?? (remoteRequestId != null ? 'req_$remoteRequestId' : null);
    if (id != null) {
      await TripCancelService.instance.cancelByPassenger(
        bookingId: id,
        reason: reason,
        kind: BookingKind.prebook,
      );
    }
    if (!context.mounted) return;
    goToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SafaronBookingHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  SuccessCheckHero(
                    title: tr('Haydovchi topildi!'),
                    subtitle: "Haydovchi sizning so'rovingizni qabul qildi.",
                  ),
                  const SizedBox(height: 16),
                  DriverVehicleCard(taxi: taxi, showTelegram: false),
                  const SizedBox(height: 12),
                  MiniRouteMap(
                    fromLabel: request.from,
                    fromSub: request.exactPlace,
                    toLabel: request.to,
                    toSub: 'Markaz',
                  ),
                  const SizedBox(height: 12),
                  SoftMetaCard(
                    dateTime: '${request.dateLabel}\n${request.timeLabel}',
                    passengers: '${request.passengers} kishi',
                    luggage: request.hasLuggage ? tr('Bagaj bor') : "Bagaj yo'q",
                    price: taxi.priceLabel,
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Mashina ma’lumotlari'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('${taxi.carModel} · ${taxi.plate}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(taxi.phone, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InfoBanner(
                    text:
                        tr('Haydovchi belgilangan vaqtda siz ko‘rsatgan manzilda bo‘ladi. Iltimos, vaqtda tayyor bo‘ling.'),
                  ),
                  const SizedBox(height: 12),
                  TripTimelineBar(
                    activeIndex: 1,
                    steps: [
                      (label: "So'rov yuborildi", time: '09:32', icon: Icons.check_rounded),
                      (label: tr('Haydovchi topildi'), time: '09:35', icon: Icons.local_taxi_rounded),
                      (label: tr('Safar boshlanishi'), time: request.timeLabel, icon: Icons.schedule_rounded),
                      (label: tr('Safar yakunlandi'), time: '—', icon: Icons.flag_outlined),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      color: const Color(0xFFFFEBEE),
                      fg: AppColors.destination,
                      icon: Icons.close_rounded,
                      label: tr('Bekor qilish'),
                      onTap: () => _cancel(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ActionBtn(
                      color: const Color(0xFFE8EEF5),
                      fg: AppColors.navy,
                      icon: Icons.refresh_rounded,
                      label: 'Boshqa',
                      onTap: () => _askAnother(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _ActionBtn(
                      color: AppColors.primary,
                      fg: Colors.white,
                      icon: Icons.check_rounded,
                      label: 'Tasdiqlash',
                      filled: true,
                      onTap: () async {
                        try {
                          if (remoteRequestId != null && remoteDriverId != null) {
                            await RequestApi.instance.select(remoteRequestId!, remoteDriverId!);
                          }
                          final booking = ActiveBookingService.instance.prebookBooking;
                          if (booking != null) {
                            final orderId = '${booking.id}__${taxi.id}';
                            await DriverTripService.instance.confirmBroadcastSelection(
                              booking.id,
                              acceptedOrderId: orderId,
                            );
                          }
                          await ActiveBookingService.instance.setStatus(BookingStatus.confirmed, taxi: taxi, kind: BookingKind.prebook);
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => TripConfirmedScreen(request: request, taxi: taxi),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('Amal bajarilmadi. Qayta urinib ko‘ring.')), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.color,
    required this.fg,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final Color color;
  final Color fg;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: filled
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, color: fg),
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 11, color: fg, height: 1.1),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
