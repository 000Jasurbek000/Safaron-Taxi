import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_taxis.dart';
import '../../models/taxi_offer.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/place_registry_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/nav_actions.dart';
import 'confirm_trip_screen.dart';
import 'prebook_screen.dart';
import 'register_screen.dart';

class AvailableTaxisScreen extends StatefulWidget {
  const AvailableTaxisScreen({
    super.key,
    required this.from,
    required this.to,
    required this.passengers,
    this.exactPickup = '',
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  final String from;
  final String to;
  final int passengers;
  final String exactPickup;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  @override
  State<AvailableTaxisScreen> createState() => _AvailableTaxisScreenState();
}

class _AvailableTaxisScreenState extends State<AvailableTaxisScreen> {
  int _dateMode = 0; // 0 bugun, 1 ertaga, 2 oldindan
  TimeOfDayFilter _timeFilter = TimeOfDayFilter.all;

  @override
  void initState() {
    super.initState();
    LocationService.instance.start();
  }

  List<TaxiOffer> get _taxis => mockTaxisFor(
        from: widget.from,
        to: widget.to,
        passengers: widget.passengers,
        dateMode: _dateMode,
        timeFilter: _timeFilter,
      );

  String _short(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return value;
    return parts.first;
  }

  Future<void> _book(TaxiOffer taxi) async {
    await AuthService.instance.load();
    if (!mounted) return;

    if (!AuthService.instance.registered) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      if (ok != true || !mounted) return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmTripScreen(
          taxi: taxi,
          passengers: widget.passengers,
          exactPickup: widget.exactPickup,
          searchFrom: widget.from,
          searchTo: widget.to,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromRaw = widget.from.trim();
    final toRaw = widget.to.trim();
    final from = fromRaw.isEmpty ? '—' : fromRaw;
    final to = toRaw.isEmpty ? '—' : toRaw;
    final taxis = _taxis;
    LocationService.instance.registerDrivers(taxis.map((t) => t.id));
    final routeKm = PlaceRegistryService.instance.routeDistanceLabel(
      fromName: fromRaw,
      toName: toRaw,
      fromLat: widget.fromLat,
      fromLng: widget.fromLng,
      toLat: widget.toLat,
      toLng: widget.toLng,
    );

    return ListenableBuilder(
      listenable: LocationService.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Text(
                      tr('Mavjud taksilar'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            if (routeKm.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Yo‘l masofasi: $routeKm',
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const _Dot(color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _short(from),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const _Dot(color: AppColors.destination),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _short(to),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.exactPickup.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Olib ketish: ${widget.exactPickup.trim()}',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrebookScreen(
                          initialFrom: widget.from,
                          initialTo: widget.to,
                          initialPassengers: widget.passengers,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Oldindan bron qilish'),
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy),
                              ),
                              Text(
                                tr('Kerakli sana va vaqtga buyurtma'),
                                style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterPill(
                    label: tr('Bugun'),
                    selected: _dateMode == 0,
                    onTap: () => setState(() => _dateMode = 0),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: tr('Ertaga'),
                    selected: _dateMode == 1,
                    onTap: () => setState(() => _dateMode = 1),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: tr('Barchasi'),
                    selected: _dateMode == 2,
                    icon: Icons.grid_view_rounded,
                    onTap: () => setState(() => _dateMode = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${taxis.length} ta taksi · onlayn va oflayn',
                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final item in [
                    (TimeOfDayFilter.all, Icons.grid_view_rounded, tr('Barchasi')),
                    (TimeOfDayFilter.morning, Icons.wb_twilight_outlined, tr('Ertalab')),
                    (TimeOfDayFilter.day, Icons.wb_sunny_outlined, tr('Kunduz')),
                    (TimeOfDayFilter.evening, Icons.nights_stay_outlined, tr('Kechqurun')),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TimeChip(
                        icon: item.$2,
                        label: item.$3,
                        selected: _timeFilter == item.$1,
                        onTap: () => setState(() => _timeFilter = item.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: taxis.isEmpty
                  ? Center(
                      child: Text(
                        "Mos taksi topilmadi",
                        style: GoogleFonts.montserrat(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: taxis.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final taxi = taxis[index];
                        return _TaxiCard(
                          taxi: taxi,
                          onBook: () => _book(taxi),
                        );
                      },
                    ),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: selected ? null : Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.white : AppColors.primary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: selected ? AppColors.white : AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.selectedFill : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: selected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: selected ? AppColors.primary : AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxiCard extends StatelessWidget {
  const _TaxiCard({
    required this.taxi,
    required this.onBook,
  });

  final TaxiOffer taxi;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Image.asset(
                          taxi.imageAsset,
                          width: 100,
                          height: 80,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, 0.4),
                        ),
                        if (taxi.badge != null)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                taxi.badge!,
                                style: GoogleFonts.montserrat(
                                  color: AppColors.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: taxi.isOnline ? AppColors.mintSoft : AppColors.surface,
                      child: Text(
                        taxi.isOnline ? tr('Onlayn') : tr('Oflayn'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: taxi.isOnline ? AppColors.primaryDark : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      color: AppColors.surface,
                      child: Text(
                        LocationService.instance.distanceLabel(taxi.id, seed: taxi.id.hashCode),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          taxi.time,
                          style: GoogleFonts.montserrat(
                            color: AppColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          taxi.priceLabel,
                          style: GoogleFonts.montserrat(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_seat_outlined, size: 15, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          "${taxi.seats} ta bo'sh joy",
                          style: GoogleFonts.montserrat(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (taxi.toAliases.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${taxi.extraDestinationsLabel}: ${taxi.toAliases.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          color: AppColors.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.mintSoft,
                child: Text(
                  taxi.driverName.characters.first,
                  style: GoogleFonts.montserrat(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taxi.driverName,
                      style: GoogleFonts.montserrat(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text(
                          '${taxi.rating}',
                          style: GoogleFonts.montserrat(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: onBook,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(
                      tr('Band qilish'),
                      style: GoogleFonts.montserrat(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

