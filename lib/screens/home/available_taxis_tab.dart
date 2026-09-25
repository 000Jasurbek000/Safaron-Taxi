import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_taxis.dart';
import '../../models/taxi_offer.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../l10n/app_strings.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../booking/confirm_trip_screen.dart';
import '../booking/prebook_screen.dart';
import '../booking/register_screen.dart';
import '../../widgets/active_booking_banner.dart';

class TaxisScreen extends StatefulWidget {
  const TaxisScreen({super.key});

  @override
  State<TaxisScreen> createState() => _TaxisScreenState();
}

class _TaxisScreenState extends State<TaxisScreen> {
  OnlineFilter _filter = OnlineFilter.all;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    LocationService.instance.start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TaxiOffer> get _taxis => catalogTaxis(filter: _filter, query: _search.text);

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmTripScreen(taxi: taxi, passengers: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taxis = _taxis;
    LocationService.instance.registerDrivers(taxis.map((t) => t.id));
    final onlineCount = catalogTaxis(filter: OnlineFilter.online, query: _search.text).length;
    final offlineCount = catalogTaxis(filter: OnlineFilter.offline, query: _search.text).length;

    final searched = _search.text.trim().isNotEmpty;
    return ListenableBuilder(
      listenable: Listenable.merge([LocationService.instance, ProfileService.instance]),
      builder: (context, _) => ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t('available_taxis'),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.t('taxis_hint'),
                    style: GoogleFonts.montserrat(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ActiveBookingBanner(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      hintText: tr('Masalan: qi, sadvin, beruniy, balnitsa...'),
                      hintStyle: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => _search.clear(),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrebookScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  Text(
                                    tr('Sana va vaqtni tanlab buyurtma bering'),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: tr('Barchasi'),
                          count: onlineCount + offlineCount,
                          selected: _filter == OnlineFilter.all,
                          onTap: () => setState(() => _filter = OnlineFilter.all),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: tr('Onlayn'),
                          count: onlineCount,
                          selected: _filter == OnlineFilter.online,
                          onlineStyle: true,
                          onTap: () => setState(() => _filter = OnlineFilter.online),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: tr('Oflayn'),
                          count: offlineCount,
                          selected: _filter == OnlineFilter.offline,
                          onTap: () => setState(() => _filter = OnlineFilter.offline),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: taxis.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                      children: [
                        Image.asset(
                          'assets/images/prebook_waiting_hero.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searched ? AppStrings.t('taxis_no_match') : AppStrings.t('taxis_empty'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          searched ? AppStrings.t('taxis_no_match_hint') : AppStrings.t('taxis_empty_hint'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: taxis.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final taxi = taxis[index];
                        final showDivider = index > 0 &&
                            _filter == OnlineFilter.all &&
                            taxi.isOnline == false &&
                            taxis[index - 1].isOnline == true;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index == 0 && taxi.isOnline && _filter == OnlineFilter.all)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 4),
                                child: Text(
                                  tr('Onlayn'),
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            if (showDivider)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 6),
                                child: Text(
                                  tr('Oflayn'),
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            _CatalogTaxiCard(
                              taxi: taxi,
                              onBook: () => _book(taxi),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onlineStyle = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool onlineStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.cardBorder,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onlineStyle) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.navy,
                    ),
                  ),
                ],
              ),
              Text(
                '$count',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? Colors.white : AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogTaxiCard extends StatelessWidget {
  const _CatalogTaxiCard({required this.taxi, required this.onBook});

  final TaxiOffer taxi;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final online = taxi.isOnline;
    return Opacity(
      opacity: online ? 1 : 0.72,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        taxi.imageAsset,
                        width: 88,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        width: 88,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        color: online ? AppColors.mintSoft : AppColors.surface,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: online ? AppColors.primary : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              online ? AppStrings.t('online_status') : AppStrings.t('offline_status'),
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: online ? AppColors.primaryDark : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 88,
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
                      Text(
                        taxi.driverName,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${taxi.carModel} · ${taxi.plate}',
                        style: GoogleFonts.montserrat(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B301)),
                          Text(
                            ' ${taxi.rating}',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.navy),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.event_seat_outlined, size: 14, color: AppColors.primary),
                          Text(
                            ' ${taxi.seats} joy',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.navy),
                          ),
                          const Spacer(),
                          Text(
                            taxi.priceLabel,
                            style: GoogleFonts.montserrat(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${taxi.from} → ${taxi.to}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (taxi.toAliases.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${taxi.extraDestinationsLabel}: ${taxi.toAliases.join(', ')}',
                            style: GoogleFonts.montserrat(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  online ? tr('Band qilish') : tr('Oflayn · bron qilish'),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
