import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/active_booking_service.dart';
import '../../services/app_navigation.dart';
import '../../services/chat_service.dart';
import '../../services/driver_trip_service.dart';
import '../../services/profile_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_colors.dart';
import '../driver/driver_create_trip_screen.dart';
import '../driver/driver_home_screen.dart';
import '../driver/driver_my_trips_screen.dart';
import '../driver/driver_orders_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/trips_screen.dart';
import '../../widgets/pending_rating_listener.dart';
import 'available_taxis_tab.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  List<Widget> get _passengerPages => const [
        HomeScreen(),
        TripsScreen(),
        TaxisScreen(),
        MessagesScreen(),
        ProfileScreen(),
      ];

  List<Widget> get _driverPages => const [
        DriverHomeScreen(),
        DriverOrdersScreen(),
        DriverCreateTripScreen(),
        DriverMyTripsScreen(),
        ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    AppNavigation.tabIndex.addListener(_onNav);
    ProfileService.instance.addListener(_onRole);
  }

  void _onNav() {
    final v = AppNavigation.tabIndex.value;
    if (v != _index && mounted) setState(() => _index = v);
  }

  void _onRole() {
    if (!mounted) return;
    setState(() {
      _index = 0;
      AppNavigation.goHome();
    });
  }

  @override
  void dispose() {
    AppNavigation.tabIndex.removeListener(_onNav);
    ProfileService.instance.removeListener(_onRole);
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(AppStrings.t('exit_title'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy)),
        content: Text(
          AppStrings.t('exit_message'),
          style: GoogleFonts.montserrat(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t('no'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.t('yes'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.destination)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ActiveBookingService.instance,
        ChatService.instance,
        ProfileService.instance,
        DriverTripService.instance,
        ThemeService.instance,
      ]),
      builder: (context, _) {
        final driver = ProfileService.instance.isDriverRole;
        final pages = driver ? _driverPages : _passengerPages;
        final safeIndex = _index.clamp(0, pages.length - 1);

        return PendingRatingListener(
          child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await _confirmExit();
            if (leave && context.mounted) {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.white,
            body: IndexedStack(
              key: ValueKey(ThemeService.instance.isDark),
              index: safeIndex,
              children: pages,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 68,
                  child: driver ? _driverNav(safeIndex) : _passengerNav(safeIndex),
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _passengerNav(int index) {
    return Row(
      children: [
        _NavItem(
          icon: Icons.home_rounded,
          label: AppStrings.t('nav_home'),
          selected: index == 0,
          onTap: () {
            AppNavigation.goHome();
            setState(() => _index = 0);
          },
        ),
        _NavItem(
          icon: Icons.calendar_month_outlined,
          label: AppStrings.t('nav_trips'),
          selected: index == 1,
          onTap: () {
            AppNavigation.goTrips();
            setState(() => _index = 1);
          },
          badge: ActiveBookingService.instance.hasActive,
        ),
        _CenterNav(
          selected: index == 2,
          label: AppStrings.t('find_taxi'),
          icon: Icons.local_taxi_rounded,
          onTap: () {
            AppNavigation.goTaxis();
            setState(() => _index = 2);
          },
        ),
        _NavItem(
          icon: Icons.chat_bubble_outline_rounded,
          label: AppStrings.t('nav_messages'),
          selected: index == 3,
          onTap: () {
            AppNavigation.goMessages();
            setState(() => _index = 3);
          },
          badge: ChatService.instance.hasUnread,
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          label: AppStrings.t('nav_profile'),
          selected: index == 4,
          onTap: () {
            AppNavigation.goProfile();
            setState(() => _index = 4);
          },
        ),
      ],
    );
  }

  Widget _driverNav(int index) {
    return Row(
      children: [
        _NavItem(
          icon: Icons.home_rounded,
          label: AppStrings.t('nav_home'),
          selected: index == 0,
          onTap: () {
            AppNavigation.goHome();
            setState(() => _index = 0);
          },
        ),
        _NavItem(
          icon: Icons.inbox_outlined,
          label: AppStrings.t('nav_order'),
          selected: index == 1,
          onTap: () {
            AppNavigation.goTrips();
            setState(() => _index = 1);
          },
          badge: DriverTripService.instance.openOrders.isNotEmpty,
        ),
        _CenterNav(
          selected: index == 2,
          label: AppStrings.t('nav_create_trip'),
          icon: Icons.add_road_rounded,
          onTap: () {
            AppNavigation.goTaxis();
            setState(() => _index = 2);
          },
        ),
        _NavItem(
          icon: Icons.route_rounded,
          label: AppStrings.t('nav_my_trips'),
          selected: index == 3,
          onTap: () {
            AppNavigation.goMessages();
            setState(() => _index = 3);
          },
          badge: DriverTripService.instance.acceptedOrders.isNotEmpty,
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          label: AppStrings.t('nav_profile'),
          selected: index == 4,
          onTap: () {
            AppNavigation.goProfile();
            setState(() => _index = 4);
          },
        ),
      ],
    );
  }
}

class _CenterNav extends StatelessWidget {
  const _CenterNav({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: selected ? Border.all(color: AppColors.accent, width: 2.5) : null,
              ),
              child: Icon(icon, color: AppColors.onPrimary, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.destination,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
