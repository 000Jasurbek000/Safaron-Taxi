import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_navigation.dart';
import '../../services/app_refresh.dart';
import '../../services/driver_trip_service.dart';
import '../../services/notification_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../services/profile_service.dart';
import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/eta_util.dart';
import '../../utils/money.dart';
import '../../widgets/booking_alert_banner.dart';
import '../../widgets/driver_inbox_banner.dart';
import '../../widgets/safaron_header.dart';
import '../notifications/notifications_screen.dart';

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
          listenable: Listenable.merge([profile, svc, NotificationService.instance]),
          builder: (context, _) {
            final hasUnread = NotificationService.instance.hasUnread;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: AppRefresh.run,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Assalomu alaykum,'),
                            style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                          ),
                          Text(
                            profile.fullName,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Material(
                          color: AppColors.mintSoft,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                            ),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.notifications_outlined, color: AppColors.primary, size: 22),
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(color: AppColors.destination, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.carName} · ${profile.plate}',
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const BookingAlertBanner(),
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
                        onChanged: (v) async {
                          try {
                            await svc.setOnline(v);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('Holatni yangilab bo‘lmadi — internetni tekshirib, qayta urinib ko‘ring.')),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
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
                                Text(o.totalOfferedPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(o.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                            Text('${o.passengers} ${tr('yo‘lovchi')} · ${o.passengerName}', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
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
            ),
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
    final awaitingSelection = order.status == PassengerOrderStatus.awaitingSelection;
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
              Text('${order.passengers} ${tr('joy')}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12)),
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
          if (order.pendingSeats != null)
            // Yo'lovchining o'rindiq sonini oshirish so'rovi — avval bu
            // faqat "Buyurtmalarim" ekranida ko'rinardi, haydovchi bosh
            // sahifada qolib, "Buyurtmalarim"ga o'tmasa, so'rovni umuman
            // ko'rmay qolardi.
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Yo‘lovchi {count} kishiga oshirishni so‘radi').replaceAll('{count}', '${order.pendingSeats}'),
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tr('Qabul qilsangiz jami narx')}: ${formatSom(order.displayPrice * order.pendingSeats!)}',
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () async {
                              final err = await DriverTripService.instance.respondSeatIncrease(order.id, true);
                              if (context.mounted && err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(tr('Qabul qilish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: OutlinedButton(
                            onPressed: () async {
                              final err = await DriverTripService.instance.respondSeatIncrease(order.id, false);
                              if (context.mounted && err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.destination,
                              side: const BorderSide(color: AppColors.destination, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(tr('Rad etish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (awaitingSelection)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF3F6FA), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Javobingiz yuborildi — yo‘lovchi hali tanlamadi'),
                      style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          if (onWay)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () async {
                  final err = await DriverTripService.instance.markPassengerPickedUp(order.id);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
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
                  // Haydovchi yo'lovchini baholamaydi — bu yerda reyting
                  // so'ralmaydi, faqat safar yakunlanadi.
                  final err = await DriverTripService.instance.completeOrder(
                    order.id,
                    completedBy: TripCompletedBy.driver,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? tr('Safar yakunlandi')), behavior: SnackBarBehavior.floating),
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
                    final err = await TripCancelService.instance.cancelByDriver(
                      orderId: order.id,
                      reason: reason,
                    );
                    if (context.mounted && err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                      );
                    }
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
