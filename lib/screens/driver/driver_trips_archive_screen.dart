import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_trip_service.dart';
import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/money.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/safaron_header.dart';

class DriverTripsArchiveScreen extends StatelessWidget {
  const DriverTripsArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            DriverTripService.instance,
            TripCompletionService.instance,
          ]),
          builder: (context, _) {
            final svc = DriverTripService.instance;
            final trips = svc.archivedTrips;
            final orders = svc.archivedOrders;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Row(
                  children: [
                    AppBackButton(),
                    const SizedBox(width: 8),
                    Text(
                      tr('Arxiv'),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr('Yopilgan, tugallangan va bekor qilingan safarlar'),
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(tr('E’lon qilingan safarlar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (trips.isEmpty)
                  SoftCard(
                    child: Text(tr('Arxivda e’lon yo‘q'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                  )
                else
                  ...trips.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text(
                              '${t.dateLabel} · ${t.timeLabel} · ${t.priceLabel}',
                              style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(tr('Yo‘lovchi buyurtmalari'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  SoftCard(
                    child: Text(tr('Arxivda buyurtma yo‘q'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                  )
                else
                  ...orders.map((o) {
                    final record = TripCompletionService.instance.byBookingId(o.broadcastGroupId ?? o.id);
                    final needsRating = record?.needsDriverRating ?? false;
                    final statusLabel = switch (o.status) {
                      PassengerOrderStatus.done => 'Tugallangan',
                      PassengerOrderStatus.cancelled => tr('Bekor qilingan'),
                      PassengerOrderStatus.expired => 'Yopilgan',
                      _ => o.status.name,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.textMuted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const Spacer(),
                                Text(formatSom(o.displayPrice), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(o.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('${o.passengerName} · ${o.passengerPhone}', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
                            if (needsRating) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final stars = await showTripRatingDialog(
                                      context,
                                      title: '${o.passengerName} ni baholang',
                                    );
                                    if (stars == null) return;
                                    await TripCompletionService.instance.markDriverRatedPassenger(o.id);
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
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
