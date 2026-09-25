import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/active_booking_service.dart';
import '../services/driver_exclusion_service.dart';
import '../services/driver_trip_service.dart';
import '../services/trip_cancel_service.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';

/// Yo‘lovchi: haydovchi qarshi narx yuborganida tasdiqlash / rad etish.
class CounterOfferCard extends StatelessWidget {
  const CounterOfferCard({
    super.key,
    required this.bookingId,
    required this.offeredPrice,
    required this.counterPrice,
    required this.driverName,
    this.onConfirmed,
    this.onRejected,
  });

  final String bookingId;
  final int offeredPrice;
  final int counterPrice;
  final String driverName;
  final VoidCallback? onConfirmed;
  final VoidCallback? onRejected;

  Future<void> _accept(BuildContext context) async {
    await DriverTripService.instance.passengerConfirmCounter(bookingId);
    await ActiveBookingService.instance.setStatus(BookingStatus.confirmed, bookingId: bookingId);
    onConfirmed?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Narx tasdiqlandi')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final booking = ActiveBookingService.instance.byId(bookingId);
    if (booking != null) {
      DriverExclusionService.instance.excludeForTwoHours(booking.taxi.id);
    }
    await TripCancelService.instance.cancelByPassenger(
      bookingId: bookingId,
      reason: tr('Qarshi narx rad etildi'),
    );
    onRejected?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Taklif rad etildi. Boshqa haydovchini tanlashingiz mumkin.')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Haydovchi qarshi narx yubordi'),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            '$driverName sizning ${formatSom(offeredPrice)} o‘rniga ${formatSom(counterPrice)} taklif qildi.',
            style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destination,
                    side: BorderSide(color: AppColors.destination.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Bekor', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _accept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Tasdiqlash', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
