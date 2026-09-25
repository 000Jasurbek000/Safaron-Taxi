import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/booking/driver_found_screen.dart';
import '../screens/booking/driver_on_way_screen.dart';
import '../screens/booking/prebook_waiting_screen.dart';
import '../screens/booking/trip_confirmed_screen.dart';
import '../screens/booking/waiting_driver_screen.dart';
import '../services/active_booking_service.dart';
import '../theme/app_colors.dart';

void openActiveBooking(BuildContext context, {ActiveBooking? booking}) {
  final b = booking ?? ActiveBookingService.instance.booking;
  if (b == null) return;

  final Widget page;
  if (b.kind == BookingKind.instant) {
    page = switch (b.status) {
      BookingStatus.waiting ||
      BookingStatus.counterOffer ||
      BookingStatus.expired ||
      BookingStatus.cancelled =>
        WaitingDriverScreen(
          taxi: b.taxi,
          seats: b.seats,
          exactPickup: b.pickupLabel ?? '',
          bookingId: b.id,
        ),
      _ => DriverOnWayScreen(
          taxi: b.taxi,
          seats: b.seats,
          pickupLabel: b.pickupLabel,
          bookingId: b.id,
        ),
    };
  } else {
    final req = b.prebook!;
    page = switch (b.status) {
      BookingStatus.waiting ||
      BookingStatus.counterOffer ||
      BookingStatus.expired ||
      BookingStatus.cancelled =>
        PrebookWaitingScreen(request: req),
      BookingStatus.driverFound =>
        b.taxi.id == 'pending'
            ? PrebookWaitingScreen(request: req)
            : DriverFoundScreen(request: req, taxi: b.taxi),
      BookingStatus.confirmed ||
      BookingStatus.onWay ||
      BookingStatus.pickedUp ||
      BookingStatus.completed =>
        TripConfirmedScreen(request: req, taxi: b.taxi),
    };
  }

  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

/// Bosh sahifa: hozirgi bo‘lsa u, aks holda oldindan bron.
class ActiveBookingBanner extends StatelessWidget {
  const ActiveBookingBanner({super.key, this.kindFilter});

  final BookingKind? kindFilter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ActiveBookingService.instance,
      builder: (context, _) {
        final svc = ActiveBookingService.instance;
        final ActiveBooking? b;
        if (kindFilter != null) {
          b = svc.bookingOf(kindFilter!);
        } else {
          // Asosiy menyu: avvalo hozirgi taksi
          b = svc.instantBooking ?? svc.prebookBooking;
        }
        if (b == null) return const SizedBox.shrink();

        final isPrebook = b.kind == BookingKind.prebook;
        final title = isPrebook ? tr('Oldindan bron') : tr('Hozirgi taksi');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => openActiveBooking(context, booking: b),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPrebook
                      ? const [Color(0xFF3D5A80), Color(0xFF1A232E)]
                      : [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (isPrebook ? AppColors.navy : AppColors.primary).withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPrebook
                          ? Icons.event_available_rounded
                          : b.status == BookingStatus.waiting
                              ? Icons.hourglass_top_rounded
                              : Icons.local_taxi_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          b.statusTitle,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          b.routeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ochish',
                      style: GoogleFonts.montserrat(
                        color: isPrebook ? AppColors.navy : AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
