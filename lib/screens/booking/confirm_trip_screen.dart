import 'dart:io';
import '../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/taxi_offer.dart';
import '../../theme/app_colors.dart';
import '../../utils/money.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/nav_actions.dart';
import '../../services/active_booking_service.dart';
import '../../widgets/duplicate_route_dialog.dart';
import '../../widgets/safaron_header.dart';
import 'waiting_driver_screen.dart';

class ConfirmTripScreen extends StatefulWidget {
  const ConfirmTripScreen({
    super.key,
    required this.taxi,
    required this.passengers,
    this.exactPickup = '',
    this.searchFrom = '',
    this.searchTo = '',
  });

  final TaxiOffer taxi;
  final int passengers;
  final String exactPickup;
  final String searchFrom;
  final String searchTo;

  @override
  State<ConfirmTripScreen> createState() => _ConfirmTripScreenState();
}

class _ConfirmTripScreenState extends State<ConfirmTripScreen> {
  late int _seats;
  late final bool _isOpenTrip;
  final _note = TextEditingController();
  final _offeredPrice = TextEditingController();
  late final TextEditingController _pickup;
  late final TextEditingController _from;
  late final TextEditingController _to;

  @override
  void initState() {
    super.initState();
    _seats = widget.passengers.clamp(1, widget.taxi.seats);
    _isOpenTrip = widget.taxi.isOpenTrip;
    final fromInit = _isOpenTrip
        ? (widget.searchFrom.trim().isNotEmpty ? widget.searchFrom.trim() : '')
        : widget.taxi.from;
    final toInit = _isOpenTrip
        ? (widget.searchTo.trim().isNotEmpty ? widget.searchTo.trim() : '')
        : widget.taxi.to;
    _from = TextEditingController(text: fromInit);
    _to = TextEditingController(text: toInit);
    final pickup = widget.exactPickup.trim().isNotEmpty
        ? widget.exactPickup.trim()
        : (fromInit.isNotEmpty ? fromInit : widget.taxi.from);
    _pickup = TextEditingController(text: pickup);
    _offeredPrice.addListener(() {
      if (mounted) setState(() {});
    });
  }

  int? get _offeredUnitPrice => parseSomInput(_offeredPrice.text);

  int get _totalPrice {
    final unit = _needsPrice ? _offeredUnitPrice : (widget.taxi.price > 0 ? widget.taxi.price : null);
    if (unit == null || unit <= 0) return 0;
    return unit * _seats;
  }

  String get _totalPriceLabel =>
      _totalPrice <= 0 ? tr('Narx yuborasiz') : formatSom(_totalPrice);

  @override
  void dispose() {
    _note.dispose();
    _offeredPrice.dispose();
    _pickup.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  bool get _needsPrice => _isOpenTrip || widget.taxi.price <= 0;

  Widget _carImage(TaxiOffer taxi) {
    final src = taxi.imageAsset;
    if (src.isNotEmpty && !src.startsWith('assets/')) {
      return Image.file(File(src), width: 72, height: 58, fit: BoxFit.cover);
    }
    return Image.asset(src, width: 72, height: 58, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final taxi = widget.taxi;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          tr('Taksini band qilish'),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                        ),
                        Text(
                          "Ma'lumotlarni tekshirib, tasdiqlang",
                          style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  SoftCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _carImage(taxi),
                            ),
                            const SizedBox(width: 10),
                            ClipOval(
                              child: Image.asset('assets/images/driver_avatar.png', width: 40, height: 40, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(taxi.driverName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B301)),
                                      Text(' ${taxi.rating} (${taxi.reviews} ta baho)', style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                taxi.plate,
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Material(
                              color: AppColors.mintSoft,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () => showDriverCallSheet(context, taxi),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(tr('Aloqa'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryDark)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isOpenTrip)
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Yo‘nalishingiz'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
                          Text(
                            tr('Haydovchi ochiq taksi e’lon qilgan — qayerdan, qayerga va narxni o‘zingiz kiriting.'),
                            style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _from,
                            decoration: InputDecoration(
                              labelText: tr('Qayerdan *'),
                              labelStyle: GoogleFonts.montserrat(),
                              prefixIcon: const Icon(Icons.radio_button_checked, color: AppColors.primary, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _to,
                            decoration: InputDecoration(
                              labelText: tr('Qayerga *'),
                              labelStyle: GoogleFonts.montserrat(),
                              prefixIcon: const Icon(Icons.place_rounded, color: AppColors.destination, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )
                  else
                    SoftCard(
                      child: Row(
                        children: [
                          Column(
                            children: [
                              const _Dot(AppColors.primary),
                              Container(width: 2, height: 28, color: AppColors.mintSoft),
                              const _Dot(AppColors.destination),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(taxi.from, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy)),
                                Text('Qayerdan', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
                                const SizedBox(height: 10),
                                Text(taxi.to, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy)),
                                Text('Qayerga', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(taxi.time.isEmpty ? '—' : taxi.time, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.navy)),
                              if (taxi.distance.isNotEmpty)
                                Text(taxi.distance, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
                              const SizedBox(height: 6),
                              Text(
                                _totalPriceLabel,
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
                              ),
                              if (_seats > 1 && _totalPrice > 0)
                                Text(
                                  '$_seats kishi × ${formatSom(_totalPrice ~/ _seats)}',
                                  style: GoogleFonts.montserrat(fontSize: 10, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.place_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tr('Sizni qayerdan olib ketishadi?'),
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pickup,
                          readOnly: !_isOpenTrip,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primary),
                            hintText: 'Aniq manzil (masalan: 44-maktab oldi)',
                            hintStyle: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy),
                        ),
                        if (!_isOpenTrip)
                          Text(
                            tr('Taksi qidirishda kiritilgan manzil · o‘zgartirib bo‘lmaydi'),
                            style: GoogleFonts.montserrat(fontSize: 10, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Haydovchiga qo'shimcha ma'lumot", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                        TextField(
                          controller: _note,
                          maxLength: 100,
                          maxLines: 2,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: tr('Masalan: Oq mashina yonida kutaman'),
                            hintStyle: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                          ),
                          style: GoogleFonts.montserrat(color: AppColors.navy),
                        ),
                      ],
                    ),
                  ),
                  if (_needsPrice) ...[
                    const SizedBox(height: 10),
                    SoftCard(
                      color: AppColors.mintSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Taklif narxingiz (1 kishi)', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                          TextField(
                            controller: _offeredPrice,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: tr('Masalan: 20000'),
                              suffixText: tr("so'm"),
                            ),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primaryDark),
                          ),
                          if (_seats > 1 && _totalPrice > 0)
                            Text(
                              'Jami: ${_totalPriceLabel}',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDark),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(tr('Band qilinadigan joylar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy))),
                            _Round(Icons.remove_rounded, _seats <= 1 ? null : () => setState(() => _seats--)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('$_seats', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy)),
                            ),
                            _Round(Icons.add_rounded, _seats >= taxi.seats ? null : () => setState(() => _seats++), filled: true),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.directions_car_outlined, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                taxi.carModel,
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy),
                              ),
                            ),
                            Text(
                              'Maks. ${taxi.seats} joy',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (!_needsPrice && _totalPrice > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Jami narx: ', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                              Text(_totalPriceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                              if (_seats > 1)
                                Text(
                                  '  · $_seats kishi',
                                  style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: PrimaryPillButton(
                label: tr('Safarni tasdiqlash'),
                onTap: () async {
                  var bookTaxi = taxi;
                  if (_isOpenTrip) {
                    final from = _from.text.trim();
                    final to = _to.text.trim();
                    if (from.isEmpty || to.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('Qayerdan va qayerga manzilni kiriting')), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    bookTaxi = taxi.copyWith(from: from, to: to);
                  }
                  if (_needsPrice) {
                    final offered = _offeredUnitPrice;
                    if (offered == null || offered < 1000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Taklif narxini kiriting (kamida 1000)'), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    bookTaxi = bookTaxi.copyWith(price: _totalPrice);
                  } else if (bookTaxi.price > 0) {
                    bookTaxi = bookTaxi.copyWith(price: _totalPrice);
                  }

                  var forceDuplicate = false;
                  if (ActiveBookingService.instance.hasSameRoute(bookTaxi.from, bookTaxi.to)) {
                    forceDuplicate = await showDuplicateRouteDialog(context);
                    if (!forceDuplicate || !context.mounted) return;
                  }

                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WaitingDriverScreen(
                        taxi: bookTaxi,
                        seats: _seats,
                        exactPickup: _pickup.text.trim(),
                        forceInstant: forceDuplicate,
                      ),
                    ),
                  );
                },
              ),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _Round extends StatelessWidget {
  const _Round(this.icon, this.onTap, {this.filled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: filled ? AppColors.primary : AppColors.mintSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: filled ? Colors.white : AppColors.primary)),
        ),
      ),
    );
  }
}
