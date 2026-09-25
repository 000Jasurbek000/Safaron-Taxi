import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/popular_routes.dart';
import '../../l10n/app_strings.dart';
import '../../models/place_record.dart';
import '../../services/app_navigation.dart';
import '../../services/chat_service.dart';
import '../../services/location_place_service.dart';
import '../../services/place_registry_service.dart';
import '../../services/profile_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/active_booking_banner.dart';
import '../../widgets/exact_pickup_dialog.dart';
import '../../widgets/place_picker_field.dart';
import 'inline_map_panel.dart';
import '../booking/available_taxis_screen.dart';
import '../booking/prebook_screen.dart';

enum _MapTarget { none, from, to }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  int _passengers = 1;
  _MapTarget _mapTarget = _MapTarget.none;
  String? _exactPickup;
  bool _dialogOpen = false;
  PlaceSelection? _fromSelection;
  PlaceSelection? _toSelection;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _askExactPickupAndOpen() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty || _dialogOpen) return;

    // Allaqachon kiritilgan bo‘lsa — qayta so‘ralmaydi
    if (_exactPickup != null && _exactPickup!.trim().isNotEmpty) {
      _openTaxis();
      return;
    }

    _dialogOpen = true;
    final result = await showExactPickupDialog(
      context,
      from: from,
      to: to,
      initialValue: _exactPickup,
    );
    _dialogOpen = false;
    if (!mounted) return;

    if (result == null || result.trim().isEmpty) return;

    setState(() => _exactPickup = result.trim());
    _openTaxis();
  }

  void _openTaxis() {
    final from = PlaceRegistryService.instance.canonicalName(_fromController.text.trim());
    final to = PlaceRegistryService.instance.canonicalName(_toController.text.trim());
    final pickup = _exactPickup?.trim() ?? '';
    if (from.isEmpty || to.isEmpty || pickup.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AvailableTaxisScreen(
          from: from,
          to: to,
          passengers: _passengers,
          exactPickup: pickup,
          fromLat: _fromSelection?.latitude,
          fromLng: _fromSelection?.longitude,
          toLat: _toSelection?.latitude,
          toLng: _toSelection?.longitude,
        ),
      ),
    );
  }

  Future<void> _onFindTaxi() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t('enter_addresses')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _askExactPickupAndOpen();
  }

  Future<void> _fillRouteAndGo(String from, String to) async {
    setState(() {
      _fromController.text = from;
      _toController.text = to;
      _fromSelection = PlaceRegistryService.instance.selectionFromText(from);
      _toSelection = PlaceRegistryService.instance.selectionFromText(to);
      _mapTarget = _MapTarget.none;
      _exactPickup = null;
    });
    await _askExactPickupAndOpen();
  }

  void _swapPlaces() {
    final temp = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = temp;
    setState(() {
      if (_mapTarget == _MapTarget.from) {
        _mapTarget = _MapTarget.to;
      } else if (_mapTarget == _MapTarget.to) {
        _mapTarget = _MapTarget.from;
      }
    });
  }

  void _toggleMap(_MapTarget target) {
    setState(() {
      _mapTarget = _mapTarget == target ? _MapTarget.none : target;
    });
  }

  void _confirmMap(MapPickResult pick) {
    setState(() {
      final sel = pick.toSelection();
      if (_mapTarget == _MapTarget.from) {
        _fromController.text = pick.label;
        _fromSelection = sel;
      } else if (_mapTarget == _MapTarget.to) {
        _toController.text = pick.label;
        _toSelection = sel;
      }
      _mapTarget = _MapTarget.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _TopBar(),
            const SizedBox(height: 12),
            const ActiveBookingBanner(),
            const SizedBox(height: 16),
            Text(
              AppStrings.t('home_title'),
              style: GoogleFonts.montserrat(
                color: AppColors.primaryDark,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            _SearchCard(
              fromController: _fromController,
              toController: _toController,
              passengers: _passengers,
              mapTarget: _mapTarget,
              exactPickup: _exactPickup,
              onSwap: _swapPlaces,
              onToggleFromMap: () => _toggleMap(_MapTarget.from),
              onToggleToMap: () => _toggleMap(_MapTarget.to),
              onConfirmMap: _confirmMap,
              onCloseMap: () => setState(() => _mapTarget = _MapTarget.none),
              onFromSelection: (s) => _fromSelection = s,
              onToSelection: (s) => _toSelection = s,
              onPassengerMinus: _passengers <= 1
                  ? null
                  : () => setState(() => _passengers--),
              onPassengerPlus: _passengers >= 15
                  ? null
                  : () => setState(() => _passengers++),
              onEditPickup: () async {
                final from = _fromController.text.trim();
                final to = _toController.text.trim();
                if (from.isEmpty || to.isEmpty) return;
                final result = await showExactPickupDialog(
                  context,
                  from: from,
                  to: to,
                  initialValue: _exactPickup,
                );
                if (!mounted || result == null || result.trim().isEmpty) return;
                setState(() => _exactPickup = result.trim());
              },
            ),
            const SizedBox(height: 14),
            _FindTaxiButton(onTap: _onFindTaxi),
            const SizedBox(height: 10),
            _PrebookBand(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PrebookScreen(
                      initialFrom: _fromController.text.trim(),
                      initialTo: _toController.text.trim(),
                      initialPassengers: _passengers,
                    ),
                  ),
                );
              },
            ),
            if (popularRoutes().isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t('popular_routes'),
                      style: GoogleFonts.montserrat(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => AppNavigation.goTaxis(),
                    child: Text(
                      AppStrings.t('see_all'),
                      style: GoogleFonts.montserrat(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 168,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final r in popularRoutes()) ...[
                      _RouteCard(
                        title: r.title,
                        subtitle: r.subtitle,
                        price: r.priceLabel,
                        imageAsset: r.imageAsset,
                        onTap: () => _fillRouteAndGo(r.from, r.to),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _place = LocationPlaceService.instance;

  @override
  void initState() {
    super.initState();
    _place.addListener(_refresh);
    _place.ensure();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _place.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeService.instance, ChatService.instance, ProfileService.instance]),
      builder: (context, _) {
        final dark = ThemeService.instance.isDark;
        final hasUnread = ChatService.instance.hasUnread;
        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _place.ensure(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _place.regionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _place.districtLabel.isEmpty
                          ? (_place.loading ? AppStrings.t('locating') : AppStrings.t('tap_to_refresh'))
                          : _place.districtLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _CircleAction(
                  icon: Icons.notifications_outlined,
                  onTap: () => AppNavigation.goMessages(),
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
            const SizedBox(width: 6),
            _CircleAction(
              icon: dark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              onTap: () => ThemeService.instance.toggleLightDark(),
            ),
          ],
        );
      },
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.fromController,
    required this.toController,
    required this.passengers,
    required this.mapTarget,
    required this.onSwap,
    required this.onToggleFromMap,
    required this.onToggleToMap,
    required this.onConfirmMap,
    required this.onCloseMap,
    required this.onPassengerMinus,
    required this.onPassengerPlus,
    this.exactPickup,
    this.onEditPickup,
    this.onFromSelection,
    this.onToSelection,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final int passengers;
  final _MapTarget mapTarget;
  final VoidCallback onSwap;
  final VoidCallback onToggleFromMap;
  final VoidCallback onToggleToMap;
  final ValueChanged<MapPickResult> onConfirmMap;
  final VoidCallback onCloseMap;
  final VoidCallback? onPassengerMinus;
  final VoidCallback? onPassengerPlus;
  final String? exactPickup;
  final VoidCallback? onEditPickup;
  final ValueChanged<PlaceSelection>? onFromSelection;
  final ValueChanged<PlaceSelection>? onToSelection;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          PlacePickerField(
            label: AppStrings.t('from'),
            hint: AppStrings.t('pick_place'),
            controller: fromController,
            mapOpen: mapTarget == _MapTarget.from,
            onMapTap: onToggleFromMap,
            accent: AppColors.primary,
            onSelectionChanged: onFromSelection,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: mapTarget == _MapTarget.from
                ? Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: InlineMapPanel(
                      accent: AppColors.primary,
                      onConfirm: onConfirmMap,
                      onClose: onCloseMap,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.9))),
              const SizedBox(width: 10),
              _CircleAction(
                icon: Icons.swap_vert_rounded,
                filled: true,
                onTap: onSwap,
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.9))),
            ],
          ),
          const SizedBox(height: 4),
          PlacePickerField(
            label: AppStrings.t('to'),
            hint: AppStrings.t('pick_place'),
            controller: toController,
            mapOpen: mapTarget == _MapTarget.to,
            onMapTap: onToggleToMap,
            accent: AppColors.destination,
            onSelectionChanged: onToSelection,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: mapTarget == _MapTarget.to
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InlineMapPanel(
                      accent: AppColors.destination,
                      onConfirm: onConfirmMap,
                      onClose: onCloseMap,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (exactPickup != null && exactPickup!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: AppColors.mintSoft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onEditPickup,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('exact_pickup'),
                              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                            Text(
                              exactPickup!,
                              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        AppStrings.t('edit'),
                        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _PassengerBar(
            passengers: passengers,
            onMinus: onPassengerMinus,
            onPlus: onPassengerPlus,
          ),
        ],
      ),
    );
  }
}

class _PassengerBar extends StatelessWidget {
  const _PassengerBar({
    required this.passengers,
    required this.onMinus,
    required this.onPlus,
  });

  final int passengers;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.mintSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.t('passengers'),
              style: GoogleFonts.montserrat(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _CircleAction(
            icon: Icons.remove_rounded,
            onTap: onMinus,
            enabled: onMinus != null,
          ),
          SizedBox(
            width: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Text(
                '$passengers',
                key: ValueKey(passengers),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _CircleAction(
            icon: Icons.add_rounded,
            onTap: onPlus,
            enabled: onPlus != null,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : 0.4,
      child: Material(
        color: filled ? AppColors.primary : AppColors.mintSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: active ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: filled ? AppColors.onPrimary : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FindTaxiButton extends StatelessWidget {
  const _FindTaxiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_rounded, color: AppColors.onPrimary, size: 22),
              const SizedBox(width: 8),
              Text(
                AppStrings.t('find_taxi'),
                style: GoogleFonts.montserrat(
                  color: AppColors.onPrimary,
                  fontSize: 17,
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

class _PrebookBand extends StatelessWidget {
  const _PrebookBand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.mintSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('prebook_title'),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      AppStrings.t('prebook_subtitle'),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.imageAsset,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final String imageAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(imageAsset, fit: BoxFit.cover),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.navy.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.montserrat(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.montserrat(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
