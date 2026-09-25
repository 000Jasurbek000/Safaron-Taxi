import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_trip_service.dart';
import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/safaron_header.dart';
import 'driver_trips_archive_screen.dart';

class DriverMyTripsScreen extends StatelessWidget {
  const DriverMyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = DriverTripService.instance;

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([svc, TripCompletionService.instance]),
          builder: (context, _) {
            final trips = svc.activeTrips;
            final accepted = svc.acceptedOrders;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Mening safarlarim'),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DriverTripsArchiveScreen()),
                        );
                      },
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text(tr('Arxiv'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr('Faol e’lonlar va joriy yo‘lovchilar'),
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(tr('E’lon qilingan safarlar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (trips.isEmpty)
                  SoftCard(
                    child: Text(tr('Hali faol safar e’lon qilinmagan'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                  )
                else
                  ...trips.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        color: AppColors.mintSoft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Faol',
                                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const Spacer(),
                                Text(t.priceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(t.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('${t.dateLabel} · ${t.timeLabel} · ${t.seats} joy', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
                            if (t.toAliases.isNotEmpty)
                              Text('+ ${t.toAliases.join(', ')}', style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      title: Text(tr('Safarni yopish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                                      content: Text(
                                        '${tr('E’lon yopiladi va yo‘lovchilar bu taksini ko‘rmaydi.')} ${tr('Kelgan so‘rovlar bosh sahifada qoladi.')}',
                                        style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Bekor qilish'))),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: Text(tr('Yopish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.destination)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) await svc.deactivateTrip(t.id);
                                },
                                child: Text(tr('Yopish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(tr('Qabul qilingan yo‘lovchilar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (accepted.isEmpty)
                  SoftCard(
                    child: Text(tr('Hali qabul qilingan yo‘lovchi yo‘q'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                  )
                else
                  ...accepted.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('${o.passengerName} · ${o.passengerPhone}', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 8),
                            if (o.status == PassengerOrderStatus.pickedUp)
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final stars = await showTripRatingDialog(
                                      context,
                                      title: '${o.passengerName} ni baholang',
                                    );
                                    if (stars == null) return;
                                    await svc.completeOrder(
                                      o.id,
                                      completedBy: TripCompletedBy.driver,
                                      driverRatedPassenger: true,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Safar yakunlandi · $stars★'), behavior: SnackBarBehavior.floating),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(tr('Safarni yakunlash'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
