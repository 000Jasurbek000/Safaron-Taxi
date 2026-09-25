import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/taxi_offer.dart';
import '../../services/active_booking_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_mockup.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/safaron_header.dart';
import 'prebook_screen.dart';

class TripConfirmedScreen extends StatelessWidget {
  const TripConfirmedScreen({
    super.key,
    required this.request,
    required this.taxi,
  });

  final PrebookRequest request;
  final TaxiOffer taxi;

  Future<void> _cancel(BuildContext context) async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !context.mounted) return;
    final b = ActiveBookingService.instance.prebookBooking;
    if (b != null) {
      await TripCancelService.instance.cancelByPassenger(
        bookingId: b.id,
        reason: reason,
        kind: BookingKind.prebook,
      );
    }
    if (!context.mounted) return;
    goToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final pickup = request.exactPlace.isEmpty ? request.from : '${request.from} · ${request.exactPlace}';

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
                    title: tr('Safar tasdiqlandi!'),
                    subtitle:
                        tr('Haydovchi sizning safaringizni qabul qildi. Belgilangan vaqtda sizni manzilda kutadi.'),
                  ),
                  const SizedBox(height: 16),
                  DriverVehicleCard(taxi: taxi, showTelegram: false),
                  const SizedBox(height: 12),
                  MiniRouteMap(
                    fromLabel: request.from,
                    fromSub: request.exactPlace.isEmpty ? pickup : request.exactPlace,
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
                  const InfoBanner(
                    text:
                        "Haydovchi belgilangan vaqtda sizni ko'rsatilgan manzilda kutadi. Agar reja o'zgarsa, haydovchi bilan bog'laning.",
                  ),
                  const SizedBox(height: 12),
                  TripTimelineBar(
                    activeIndex: 2,
                    steps: [
                      (label: "So'rov yuborildi", time: '09:32', icon: Icons.check_rounded),
                      (label: tr('Haydovchi topildi'), time: '09:35', icon: Icons.check_rounded),
                      (label: tr('Safar tasdiqlandi'), time: '09:36', icon: Icons.local_taxi_rounded),
                      (label: tr('Safar boshlanishi'), time: request.timeLabel, icon: Icons.place_outlined),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => openDriverChat(context, taxi),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: Text('Yozish', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mintSoft,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => showDriverCallSheet(context, taxi),
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: Text(tr('Aloqa'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mintSoft,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: CancelBookingButton(onPressed: () => _cancel(context)),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }
}

class SoftMetaCard extends StatelessWidget {
  const SoftMetaCard({
    super.key,
    required this.dateTime,
    required this.passengers,
    required this.luggage,
    required this.price,
  });

  final String dateTime;
  final String passengers;
  final String luggage;
  final String price;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          TripMetaRow(dateTime: dateTime, passengers: passengers, luggage: luggage),
          const SizedBox(height: 12),
          PricePaymentRow(price: price),
        ],
      ),
    );
  }
}
