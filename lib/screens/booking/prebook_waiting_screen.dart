import 'dart:async';
import '../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_taxis.dart';
import '../../models/taxi_offer.dart';
import '../../services/active_booking_service.dart';
import '../../services/trip_cancel_service.dart';
import '../../services/app_navigation.dart';
import '../../services/driver_exclusion_service.dart';
import '../../services/safaron_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/money.dart';
import '../../widgets/booking_mockup.dart';
import '../../widgets/cancel_reason_sheet.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/safaron_header.dart';
import 'driver_found_screen.dart';
import 'prebook_screen.dart';

class PrebookWaitingScreen extends StatefulWidget {
  const PrebookWaitingScreen({
    super.key,
    required this.request,
    this.excludedIds = const {},
    this.remoteRequestId,
  });

  final PrebookRequest request;
  final Set<String> excludedIds;
  final int? remoteRequestId;

  @override
  State<PrebookWaitingScreen> createState() => _PrebookWaitingScreenState();
}

class _PrebookWaitingScreenState extends State<PrebookWaitingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _seconds = 0;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    ActiveBookingService.instance.addListener(_onBookingUpdate);
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    final svc = ActiveBookingService.instance;
    final current = svc.prebookBooking;
    if (current == null || current.from != widget.request.from) {
      svc.startPrebook(request: widget.request);
    }

    final after = svc.prebookBooking;
    if (after?.status == BookingStatus.driverFound && after!.taxi.id != 'pending') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DriverFoundScreen(request: widget.request, taxi: after.taxi),
          ),
        );
      });
      return;
    }

    final elapsed = DateTime.now().difference(svc.prebookBooking?.createdAt ?? DateTime.now()).inSeconds;
    _seconds = elapsed.clamp(0, 3600);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _seconds++);
      if (widget.remoteRequestId != null) {
        if (_seconds % 3 == 0) await _pollRemote();
      } else if (_seconds >= 5 && _seconds % 5 == 0) {
        _foundDriver();
      }
    });
  }

  Future<void> _pollRemote() async {
    final id = widget.remoteRequestId;
    if (id == null) return;
    try {
      final req = await RequestApi.instance.get(id);
      final accepted = req.responses.where((r) => r['status'] == 'ACCEPTED' || r['status'] == 'SELECTED' || r['status'] == 'CONFIRMED').toList();
      if (accepted.isEmpty) return;
      final r = accepted.first;
      final taxi = TaxiOffer(
        id: 'drv_${r['driver_id']}',
        from: req.fromText,
        to: req.toText,
        time: widget.request.timeLabel,
        seats: req.passengersCount,
        price: (r['final_price'] as int?) ?? req.offeredPrice,
        driverName: r['driver_name'] as String? ?? 'Haydovchi',
        rating: (r['driver_rating'] as num?)?.toDouble() ?? 5,
        reviews: 0,
        carModel: r['car_model'] as String? ?? '',
        plate: r['plate'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        imageAsset: 'assets/images/car_cobalt.png',
        period: TimeOfDayFilter.all,
      );
      _timer?.cancel();
      ActiveBookingService.instance.setStatus(BookingStatus.driverFound, taxi: taxi, kind: BookingKind.prebook);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DriverFoundScreen(request: widget.request, taxi: taxi, remoteRequestId: id, remoteDriverId: r['driver_id'] as int?)),
      );
    } catch (_) {
      // keep waiting
    }
  }

  void _onBookingUpdate() {
    final after = ActiveBookingService.instance.prebookBooking;
    if (after?.status == BookingStatus.driverFound && after!.taxi.id != 'pending' && mounted) {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DriverFoundScreen(request: widget.request, taxi: after.taxi),
        ),
      );
    }
  }

  @override
  void dispose() {
    ActiveBookingService.instance.removeListener(_onBookingUpdate);
    _timer?.cancel();
    _dots.dispose();
    super.dispose();
  }

  TaxiOffer? _pickTaxi() {
    final excluded = {...widget.excludedIds, ...DriverExclusionService.instance.activeExcludedIds};
    final list = mockTaxisFor(
      from: widget.request.from,
      to: widget.request.to,
      passengers: widget.request.passengers,
      dateMode: 2,
    ).where((t) => !excluded.contains(t.id)).toList();
    if (list.isEmpty) return null;
    return list.first;
  }

  void _foundDriver() {
    final taxi = _pickTaxi();
    if (taxi == null) return;
    _timer?.cancel();
    ActiveBookingService.instance.setStatus(BookingStatus.driverFound, taxi: taxi, kind: BookingKind.prebook);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DriverFoundScreen(request: widget.request, taxi: taxi)),
    );
  }

  Future<void> _exitKeep() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Chiqish', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
        content: Text(
          "So'rov davom etadi. Bosh sahifa / Safarlarimda «Faol bron» orqali topasiz.",
          style: GoogleFonts.montserrat(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Yo'q")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Ha'))),
        ],
      ),
    );
    if (ok == true && mounted) goToHome(context);
  }

  Future<void> _cancel() async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;
    _timer?.cancel();
    final b = ActiveBookingService.instance.prebookBooking;
    final id = b?.id ?? (widget.remoteRequestId != null ? 'req_${widget.remoteRequestId}' : null);
    if (id != null) {
      await TripCancelService.instance.cancelByPassenger(
        bookingId: id,
        reason: reason,
        kind: BookingKind.prebook,
      );
    }
    if (!mounted) return;
    goToHome(context);
  }

  String get _waitLabel {
    final total = 3600;
    final left = (total - _seconds).clamp(0, total);
    final m = (left ~/ 60).toString().padLeft(2, '0');
    final s = (left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final progress = (_seconds % 30) / 30;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            SafaronHeader(
              onBack: _exitKeep,
              trailing: MessagesPill(onTap: () {
                goToHome(context);
                AppNavigation.goMessages();
              }),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/prebook_waiting_hero.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "So'rovingiz yuborildi!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('Sizning safaringiz uchun mos haydovchilar qidirilmoqda.'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      children: [
                        TripMetaRow(
                          dateTime: '${r.dateLabel} ${r.timeLabel}',
                          passengers: '${r.passengers} kishi',
                          luggage: r.hasLuggage ? tr('Bagaj bor') : "Bagaj yo'q",
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(r.from, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13))),
                                    ],
                                  ),
                                  if (r.exactPlace.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, top: 2),
                                      child: Text(r.exactPlace, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.destination, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(r.to, textAlign: TextAlign.right, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13))),
                                    ],
                                  ),
                                  Text('Markaz (ixtiyoriy)', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: Color(0xFF2C4A6E), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr('Sizning taklif narxingiz'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                    Text(formatSom(r.offeredPrice), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF2C4A6E))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    color: AppColors.mintSoft,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3.5,
                                color: AppColors.primary,
                                backgroundColor: Colors.white,
                              ),
                              const Icon(Icons.local_taxi_rounded, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Haydovchilar javobini kutyapmiz...'),
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              Text(
                                "So'rovingiz yaqin atrofdagi barcha haydovchilarga yuborildi.",
                                style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              AnimatedBuilder(
                                animation: _dots,
                                builder: (context, _) {
                                  final phase = (_dots.value * 3).floor() % 3;
                                  return Row(
                                    children: List.generate(3, (i) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: i == phase ? AppColors.primary : const Color(0xFFC8E6D5),
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(tr('Kutilayotgan vaqt'), style: GoogleFonts.montserrat(fontSize: 9, color: AppColors.textMuted)),
                            Text(_waitLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primaryDark)),
                            Text('(1 soatgacha)', style: GoogleFonts.montserrat(fontSize: 9, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Haydovchilar so'rovni ko'rib chiqib, qabul qilishi yoki rad etishi mumkin.",
                                style: GoogleFonts.montserrat(fontSize: 11, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(tr('Keyingi qadamlar:'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 8),
                        _Step(Icons.groups_rounded, tr('Javob bergan haydovchilar ro‘yxati sizga ko‘rsatiladi.')),
                        _Step(Icons.check_circle_outline_rounded, tr('Siz ulardan birini tanlaysiz.')),
                        _Step(Icons.local_taxi_rounded, tr('Tanlaganingizdan so‘ng buyurtma tasdiqlanadi.')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text("So'rovni bekor qilish", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    foregroundColor: AppColors.destination,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: AppColors.mintSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
