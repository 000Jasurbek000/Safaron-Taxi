import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/trip_history.dart';
import '../../services/active_booking_service.dart';
import '../../services/auth_service.dart';
import '../../services/trip_completion_service.dart';
import '../../widgets/rating_dialog.dart';
import '../../theme/app_colors.dart';
import '../../widgets/active_booking_banner.dart';
import '../../widgets/safaron_header.dart';
import '../booking/available_taxis_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        if (!AuthService.instance.registered) {
          return ColoredBox(
            color: AppColors.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr('Mening safarlarim'),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      tr('Safarlarni ko‘rish uchun avval ro‘yxatdan o‘ting'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.navy,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        }
        return const _TripsBody();
      },
    );
  }
}

class _TripsBody extends StatelessWidget {
  const _TripsBody();

  @override
  Widget build(BuildContext context) {
    final past = completedPastTrips;

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              tr('Mening safarlarim'),
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Hozirgi buyurtma va oldindan bron alohida'),
              style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: ActiveBookingService.instance,
              builder: (context, _) {
                final svc = ActiveBookingService.instance;
                final instant = svc.activeBookings.where((b) => b.kind == BookingKind.instant).toList();
                final prebook = svc.activeBookings.where((b) => b.kind == BookingKind.prebook).toList();

                if (instant.isEmpty && prebook.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Faol bronlar'),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                      ),
                      const SizedBox(height: 8),
                      SoftCard(
                        child: Text(
                          tr('Hozircha faol bron yo‘q'),
                          style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (instant.isNotEmpty) ...[
                      Text(
                        tr('Hozirgi safarlar'),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                      ),
                      const SizedBox(height: 8),
                      for (final b in instant)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActiveTripCard(booking: b, isPrebook: false),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (prebook.isNotEmpty) ...[
                      Text(
                        tr('Oldindan bron'),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                      ),
                      const SizedBox(height: 8),
                      for (final b in prebook)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActiveTripCard(booking: b, isPrebook: true),
                        ),
                    ],
                  ],
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                ActiveBookingService.instance,
                TripCompletionService.instance,
              ]),
              builder: (context, _) {
                final completed = ActiveBookingService.instance.bookings
                    .where((b) => b.status == BookingStatus.completed)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (completed.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      tr('Yakunlangan safarlar'),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                    ),
                    const SizedBox(height: 10),
                    for (final b in completed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CompletedTripCard(booking: b),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              tr('O‘tgan safarlar'),
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
            ),
            const SizedBox(height: 10),
            if (past.isEmpty)
              SoftCard(
                child: Text(
                  tr('Hali yakunlangan safar yo‘q'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: AppColors.textMuted),
                ),
              )
            else
              ...past.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.from} → ${t.to}',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${t.dateLabel} · ${t.timeLabel}',
                          style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.directions_car_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(t.plate, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(t.phone, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.booking, this.isPrebook = false});

  final ActiveBooking booking;
  final bool isPrebook;

  @override
  Widget build(BuildContext context) {
    final prebook = booking.prebook;
    const prebookBlue = Color(0xFF2C4A6E);
    final accent = isPrebook ? prebookBlue : AppColors.primary;
    final softBg = isPrebook ? const Color(0xFFE8EEF5) : AppColors.mintSoft;
    final cardBg = isPrebook ? const Color(0xFFF3F6FA) : const Color(0xFFF3FBF7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: softBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPrebook ? tr('Oldindan bron') : tr('Hozirgi'),
              style: GoogleFonts.montserrat(
                color: isPrebook ? prebookBlue : AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            booking.statusTitle,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy),
          ),
          Text(booking.routeLabel, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13)),
          if (isPrebook && prebook != null) ...[
            const SizedBox(height: 4),
            Text(
              '${prebook.dateLabel} · ${prebook.timeLabel}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: prebookBlue),
            ),
            if (prebook.exactPlace.isNotEmpty)
              Text(
                'Olib ketish: ${prebook.exactPlace}',
                style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: softBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Taklif narxi: ',
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                  Text(
                    booking.taxi.priceLabel,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: accent),
                  ),
                ],
              ),
            ),
          ],
          Text(booking.statusSubtitle, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
          if (booking.taxi.id != 'pending' && booking.taxi.driverName != '—') ...[
            const SizedBox(height: 6),
            Text(
              '${booking.taxi.plate} · ${booking.taxi.phone}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: accent),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () => openActiveBooking(context, booking: booking),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Batafsil', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTripCard extends StatelessWidget {
  const _CompletedTripCard({required this.booking});

  final ActiveBooking booking;

  @override
  Widget build(BuildContext context) {
    final record = TripCompletionService.instance.byBookingId(booking.id);
    final needsRating = record?.needsPassengerRating ?? false;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AvailableTaxisScreen(
                from: booking.from,
                to: booking.to,
                passengers: booking.seats,
                exactPickup: booking.pickupLabel?.trim() ?? '',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            booking.routeLabel,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.taxi.driverName} · ${booking.taxi.priceLabel}',
            style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
          ),
          if (needsRating) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () async {
                  final stars = await showTripRatingDialog(
                    context,
                    title: '${booking.taxi.driverName} ni baholang',
                  );
                  if (stars == null) return;
                  await TripCompletionService.instance.markPassengerRatedDriver(booking.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Baho yuborildi · $stars★'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: Text('Baholash', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
              const SizedBox(height: 8),
              Text(
                tr('Qayta taksi topish'),
                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
