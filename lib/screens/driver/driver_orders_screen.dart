import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../services/app_navigation.dart';
import '../../services/driver_trip_service.dart';
import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rating_dialog.dart';
import '../../utils/eta_util.dart';
import '../../utils/money.dart';
import '../../widgets/driver_eta_dialog.dart';
import '../../widgets/safaron_header.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  int _tab = 0; // 0 ochiq, 1 qabul qilingan, 2 oldindan

  @override
  void initState() {
    super.initState();
    _tab = AppNavigation.driverOrdersTab.value;
    AppNavigation.driverOrdersTab.addListener(_onExternalTab);
  }

  void _onExternalTab() {
    if (mounted) setState(() => _tab = AppNavigation.driverOrdersTab.value);
  }

  @override
  void dispose() {
    AppNavigation.driverOrdersTab.removeListener(_onExternalTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = DriverTripService.instance;

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: svc,
          builder: (context, _) {
            final open = svc.openOrders;
            final accepted = svc.acceptedOrders;
            final prebookOpen = open.where((o) => o.kind == PassengerOrderKind.prebook).toList();
            final instantOpen = open.where((o) => o.kind == PassengerOrderKind.instant).toList();
            final shown = switch (_tab) {
              1 => accepted,
              2 => prebookOpen,
              _ => instantOpen,
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buyurtmalar',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                      ),
                      Text(
                        tr('Yo‘lovchi narxini qabul qiling yoki o‘z narxingizni yozing'),
                        style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Chip(label: tr('Hozirgi'), selected: _tab == 0, onTap: () => setState(() => _tab = 0), count: instantOpen.length),
                          const SizedBox(width: 8),
                          _Chip(label: tr('Oldindan'), selected: _tab == 2, onTap: () => setState(() => _tab = 2), count: prebookOpen.length),
                          const SizedBox(width: 8),
                          _Chip(label: tr('Qabul'), selected: _tab == 1, onTap: () => setState(() => _tab = 1), count: accepted.length),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text(
                            tr('Buyurtma yo‘q'),
                            style: GoogleFonts.montserrat(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _OrderCard(order: shown[i]),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, required this.count});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.primary : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: selected ? Colors.white : AppColors.navy)),
                Text('$count', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: selected ? Colors.white : AppColors.primaryDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final PassengerOrder order;

  Future<void> _call() async {
    final uri = Uri.parse('tel:${order.passengerPhone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _rejectOrder(BuildContext context) async {
    await DriverTripService.instance.rejectOpenOrder(order.id, reason: tr('Haydovchi rad etdi'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('So‘rov rad etildi')), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _acceptAtOffered(BuildContext context) async {
    final eta = await askDriverEtaMinutes(
      context,
      timeLabel: order.timeLabel,
      isPrebook: order.kind == PassengerOrderKind.prebook,
    );
    if (order.kind != PassengerOrderKind.prebook && EtaUtil.untilDeparture(order.timeLabel) == null && eta == null) {
      return; // dialog cancelled
    }
    await DriverTripService.instance.acceptOrder(order.id, etaMinutes: eta);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Qabul qilindi · yo‘lovchi narxi: ${order.offeredPriceLabel}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _acceptWithOwnPrice(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(tr('O‘z narxingiz bilan qabul'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Yo‘lovchi taklifi'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    Text(order.offeredPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF2C4A6E))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(tr('Sizning narxingiz'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13)),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: tr('Masalan: 120000'),
                  hintStyle: GoogleFonts.montserrat(color: AppColors.textMuted),
                  suffixText: tr("so'm"),
                  suffixStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final p = parseSomInput(controller.text);
                    if (p == null || p < 1000) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(tr('O‘z narxingizni kiriting')), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    Navigator.pop(ctx, p);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('Shu narxda qabul qilish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    final eta = await askDriverEtaMinutes(
      context,
      timeLabel: order.timeLabel,
      isPrebook: order.kind == PassengerOrderKind.prebook,
    );
    if (order.kind != PassengerOrderKind.prebook && EtaUtil.untilDeparture(order.timeLabel) == null && eta == null) {
      return;
    }
    await DriverTripService.instance.acceptOrder(order.id, driverPrice: result, etaMinutes: eta);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == order.offeredPrice
              ? 'Qabul · ${formatSom(result)}'
              : 'Qarshi narx: ${formatSom(result)} (yo‘lovchi: ${order.offeredPriceLabel})',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPre = order.kind == PassengerOrderKind.prebook;
    final status = order.status;
    final isOpen = status == PassengerOrderStatus.open;
    final isCounterPending = status == PassengerOrderStatus.counterOffered;
    final isAcceptedOrOnWay =
        status == PassengerOrderStatus.accepted || status == PassengerOrderStatus.onWay;
    final isPickedUp = status == PassengerOrderStatus.pickedUp;
    final inProgress = isAcceptedOrOnWay || isPickedUp || isCounterPending;
    final accent = isPre ? const Color(0xFF2C4A6E) : AppColors.primary;
    final fixedRoute = DriverTripService.instance.orderLocksPrice(order);

    return SoftCard(
      color: isPre ? const Color(0xFFF3F6FA) : AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: isPre ? const Color(0xFFE8EEF5) : AppColors.mintSoft, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isPre ? tr('Oldindan bron') : tr('Hozirgi so‘rov'),
                  style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: accent),
                ),
              ),
              const Spacer(),
              if (isCounterPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('Javob kutilmoqda'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
                )
              else if (isAcceptedOrOnWay && order.hasCounterOffer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('Qarshi narx'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
                )
              else if (isAcceptedOrOnWay && order.acceptedAtOfferedPrice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('Yo‘lovchi narxi'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
          if (order.exactPickup.isNotEmpty)
            Text('Olib ketish: ${order.exactPickup}', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
          if (isPre && order.dateLabel.isNotEmpty)
            Text('${order.dateLabel} · ${order.timeLabel}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: accent)),
          const SizedBox(height: 10),
          _PriceBlock(order: order, accent: accent, inProgress: inProgress),
          const SizedBox(height: 8),
          Text(
            '${order.passengerName} · ${order.passengers} kishi · ${order.passengerPhone}',
            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (isOpen || isCounterPending) ...[
            if (isCounterPending)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  tr('Qarshi narx yuborildi — yo‘lovchi javobini kuting'),
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE65100)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isCounterPending ? null : () => _acceptAtOffered(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        fixedRoute ? AppStrings.t('accept') : AppStrings.t('accept_this_price'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, height: 1.15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: fixedRoute
                        ? OutlinedButton(
                            onPressed: isCounterPending ? null : () => _rejectOrder(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.destination,
                              side: const BorderSide(color: AppColors.destination, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              AppStrings.t('reject'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, height: 1.15),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: isCounterPending ? null : () => _acceptWithOwnPrice(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              AppStrings.t('own_price'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, height: 1.15),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            if (isOpen && !fixedRoute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton.icon(
                  onPressed: _call,
                  icon: Icon(Icons.phone_rounded, size: 18, color: accent),
                  label: Text(tr('Aloqa'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: accent)),
                ),
              ),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: Text(tr('Qo‘ng‘iroq'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: isPickedUp
                          ? () async {
                              final stars = await showTripRatingDialog(
                                context,
                                title: '${order.passengerName} ni baholang',
                              );
                              if (stars == null) return;
                              await DriverTripService.instance.completeOrder(
                                order.id,
                                completedBy: TripCompletedBy.driver,
                                driverRatedPassenger: true,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Safar yakunlandi · $stars★'), behavior: SnackBarBehavior.floating),
                                );
                              }
                            }
                          : () => DriverTripService.instance.markPassengerPickedUp(order.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isPickedUp ? 'Yakunlash' : tr('Yo‘lovchini oldim'),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.order, required this.accent, required this.inProgress});
  final PassengerOrder order;
  final Color accent;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    if (!inProgress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('YO‘LOVCHI NARXI'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: accent)),
            const SizedBox(height: 2),
            Text(order.offeredPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: accent)),
            Text(
              tr('Shu summani qabul qiling yoki pastroq/yuqoriroq o‘z narxingizni yozing'),
              style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, height: 1.3),
            ),
          ],
        ),
      );
    }

    if (order.hasCounterOffer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('NARX TAFSILOTI'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: const Color(0xFFE65100))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Yo‘lovchi taklifi'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                      Text(order.offeredPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy, decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFFE65100)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tr('Sizning narxingiz'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                      Text(order.agreedPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFFE65100))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('KELISHILGAN NARX'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.primaryDark)),
          Text(order.offeredPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primaryDark)),
          Text(tr('Yo‘lovchi taklifiga mos keldi'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
