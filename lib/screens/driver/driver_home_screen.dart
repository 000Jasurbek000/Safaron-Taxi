import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_navigation.dart';
import '../../services/driver_trip_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../services/profile_service.dart';
import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/eta_util.dart';
import '../../widgets/driver_inbox_banner.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/safaron_header.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService.instance;
    final svc = DriverTripService.instance;

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([profile, svc]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  tr('Assalomu alaykum,'),
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                ),
                Text(
                  profile.fullName,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.carName} · ${profile.plate}',
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const DriverInboxBanner(),
                if (svc.lastDriverNotice != null) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: svc.clearDriverNotice,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.destination),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                svc.lastDriverNotice!,
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                SoftCard(
                  color: svc.isOnline ? AppColors.mintSoft : const Color(0xFFF0F2F5),
                  child: Row(
                    children: [
                      Icon(
                        svc.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: svc.isOnline ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              svc.isOnline ? tr('Onlayn') : tr('Oflayn'),
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Text(
                              svc.isOnline ? tr('Buyurtmalar keladi') : tr('Buyurtmalar to‘xtatilgan'),
                              style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: svc.isOnline,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => svc.setOnline(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(child: _InlineStat(label: tr('Yangi buyurtma'), value: '${svc.openOrders.length}', color: AppColors.primary)),
                      Container(width: 1, height: 36, color: AppColors.textMuted.withValues(alpha: 0.25)),
                      Expanded(child: _InlineStat(label: tr('Faol safar'), value: '${svc.liveOrders.length}', color: const Color(0xFF2C4A6E))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tr('Kelgan buyurtmalar'),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                ),
                const SizedBox(height: 10),
                if (svc.openOrders.isEmpty)
                  SoftCard(
                    child: Text(
                      tr('Hozircha yangi buyurtma yo‘q'),
                      style: GoogleFonts.montserrat(color: AppColors.textMuted),
                    ),
                  )
                else
                  ...svc.openOrders.map(
                    (o) => Padding(
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
                                    color: o.kind == PassengerOrderKind.prebook ? const Color(0xFFE8EEF5) : AppColors.mintSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    o.kind == PassengerOrderKind.prebook ? tr('Oldindan') : tr('Hozirgi'),
                                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.navy),
                                  ),
                                ),
                                const Spacer(),
                                Text(o.offeredPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(o.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                            Text('${o.passengers} yo‘lovchi · ${o.passengerName}', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton(
                                onPressed: () => AppNavigation.goTrips(driverTab: 0),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(tr('Ko‘rish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  tr('Faol safarlar'),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                ),
                const SizedBox(height: 10),
                if (svc.liveOrders.isEmpty)
                  SoftCard(
                    child: Text(
                      tr('Hozircha faol yo‘lovchi yo‘q'),
                      style: GoogleFonts.montserrat(color: AppColors.textMuted),
                    ),
                  )
                else
                  ...svc.liveOrders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LiveOrderCard(order: o),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiveOrderCard extends StatelessWidget {
  const _LiveOrderCard({required this.order});
  final PassengerOrder order;

  @override
  Widget build(BuildContext context) {
    final onWay = order.status == PassengerOrderStatus.onWay || order.status == PassengerOrderStatus.accepted;
    final picked = order.status == PassengerOrderStatus.pickedUp;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
              ),
              Text('${order.passengers} joy', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12)),
            ],
          ),
          Text(
            '${order.passengerName} · ${order.exactPickup.isEmpty ? order.from : order.exactPickup}',
            style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
          ),
          if (order.etaArriveAt != null && onWay) ...[
            const SizedBox(height: 4),
            Text(EtaUtil.countdownLabel(order.etaArriveAt!), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
          const SizedBox(height: 10),
          if (onWay)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () => DriverTripService.instance.markPassengerPickedUp(order.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tr('Yo‘lovchini oldim'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
              ),
            ),
          if (picked) ...[
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () async {
                  final stars = await showTripRatingDialog(context, title: tr('Yo‘lovchini baholang'));
                  if (stars == null) return;
                  await DriverTripService.instance.completeOrder(
                    order.id,
                    completedBy: TripCompletedBy.driver,
                    driverRatedPassenger: true,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Safar yakunlandi · $stars★'), behavior: SnackBarBehavior.floating),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tr('Safarni yakunlash'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: Text(tr('Bekor qilish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy)),
                    content: Text(tr('Rostdan ham bu safarni bekor qilasizmi?'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Yo‘q'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Ha'), style: GoogleFonts.montserrat(color: AppColors.destination, fontWeight: FontWeight.w800))),
                    ],
                  ),
                );
                if (ok == true) {
                  final reason = await showCancelReasonSheet(context);
                  if (reason != null) {
                    await TripCancelService.instance.cancelByDriver(
                      orderId: order.id,
                      reason: reason,
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destination,
                side: BorderSide(color: AppColors.destination.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr('Safarni bekor qilish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 24, color: color)),
        ],
      ),
    );
  }
}
