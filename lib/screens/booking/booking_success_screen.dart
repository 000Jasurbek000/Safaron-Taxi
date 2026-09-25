import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/taxi_offer.dart';
import '../../services/active_booking_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/booking_mockup.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/safaron_header.dart';
import 'driver_on_way_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.taxi,
    required this.seats,
    this.exactPickup = '',
  });

  final TaxiOffer taxi;
  final int seats;
  final String exactPickup;

  Future<void> _cancel(BuildContext context) async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !context.mounted) return;
    final b = ActiveBookingService.instance.instantBooking;
    if (b != null) {
      await TripCancelService.instance.cancelByPassenger(
        bookingId: b.id,
        reason: reason,
        kind: BookingKind.instant,
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
                    title: tr('Taksi band qilindi!'),
                    subtitle: "Haydovchi so'rovingizni qabul qildi.",
                  ),
                  const SizedBox(height: 18),
                  SoftCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(taxi.imageAsset, width: 88, height: 64, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(taxi.carModel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.mintSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      taxi.plate,
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ClipOval(
                                        child: Image.asset('assets/images/driver_avatar.png', width: 28, height: 28, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(taxi.driverName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5B301)),
                                      Text(' ${taxi.rating}', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    taxi.phone,
                                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _Act(Icons.phone_rounded, tr('Aloqa'), () => showDriverCallSheet(context, taxi))),
                      const SizedBox(width: 8),
                      Expanded(child: _Act(Icons.chat_bubble_outline_rounded, 'Chat', () => openDriverChat(context, taxi))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      children: [
                        _Row(Icons.route_rounded, '${taxi.from} → ${taxi.to}'),
                        if (exactPickup.trim().isNotEmpty)
                          _Row(Icons.add_location_alt_rounded, 'Olib ketish: ${exactPickup.trim()}'),
                        _Row(Icons.schedule_rounded, taxi.time),
                        _Row(Icons.directions_car_outlined, '${taxi.carModel} · ${taxi.plate}'),
                        _Row(Icons.phone_outlined, taxi.phone),
                        _Row(Icons.event_seat_outlined, '$seats ta joy'),
                        _Row(Icons.payments_outlined, taxi.priceLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: PrimaryPillButton(
                label: 'Yaxshi',
                icon: null,
                onTap: () {
                  ActiveBookingService.instance.setStatus(BookingStatus.onWay, kind: BookingKind.instant);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => DriverOnWayScreen(
                        taxi: taxi,
                        seats: seats,
                        pickupLabel: exactPickup.trim().isEmpty
                            ? taxi.from
                            : '${taxi.from} · ${exactPickup.trim()}',
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CancelBookingButton(onPressed: () => _cancel(context)),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mintSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}
