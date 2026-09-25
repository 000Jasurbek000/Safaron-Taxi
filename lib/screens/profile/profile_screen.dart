import 'dart:io';
import '../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/contact.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/profile_service.dart';
import '../../services/app_navigation.dart';
import '../../services/trip_completion_service.dart';
import '../driver/driver_earnings_screen.dart';
import '../driver/driver_messages_screen.dart';
import '../../services/theme_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safaron_header.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_logo.dart';
import '../booking/register_screen.dart';
import 'driver/become_driver_intro_screen.dart';
import 'driver/my_car_screen.dart';
import 'account_settings_screen.dart';
import 'language_settings_screen.dart';
import 'referral_bonus_screens.dart';
import '../../services/platform_config_service.dart';
import 'role_select_sheet.dart';
import 'simple_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profile = ProfileService.instance;

  @override
  void initState() {
    super.initState();
    _profile.load().then((_) {
      if (mounted) setState(() {});
    });
    _profile.addListener(_onChange);
    AuthService.instance.addListener(_onChange);
    ThemeService.instance.addListener(_onChange);
    TripCompletionService.instance.addListener(_onChange);
    ChatService.instance.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _profile.removeListener(_onChange);
    AuthService.instance.removeListener(_onChange);
    ThemeService.instance.removeListener(_onChange);
    TripCompletionService.instance.removeListener(_onChange);
    ChatService.instance.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _openRole() async {
    if (_profile.driverStatus == DriverStatus.none) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BecomeDriverIntroScreen()),
      );
      return;
    }
    if (_profile.driverStatus == DriverStatus.pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t('pending_application')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await showRoleSelectSheet(context);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    await _profile.setAvatarPath(file.path);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(AppStrings.t('logout_title'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy)),
        content: Text(
          AppStrings.t('logout_confirm'),
          style: GoogleFonts.montserrat(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t('cancel'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.t('menu_logout'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.destination)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _profile.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('logged_out')), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registered = AuthService.instance.registered;
    final driver = registered && _profile.isApprovedDriver && _profile.isDriverRole;

    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              AppStrings.t('profile'),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            if (!registered) ...[
              SoftCard(
                color: AppColors.mintSoft,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.card,
                      child: Icon(Icons.person_rounded, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppStrings.t('register_first'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.t('register_hint'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                          if (mounted) setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text(
                          AppStrings.t('register_btn'),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.mintSoft,
                        backgroundImage: _profile.avatarPath.isNotEmpty
                            ? FileImage(File(_profile.avatarPath))
                            : null,
                        child: _profile.avatarPath.isEmpty
                            ? Icon(Icons.person_rounded, size: 52, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _profile.fullName.isEmpty ? AppStrings.t('user_default') : _profile.fullName,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _profile.phone,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              if (driver) ...[
                Center(
                  child: Material(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _openRole,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_taxi_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.t('driver'),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                                fontSize: 13,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Row(
                    children: [
                      _Stat(value: '4.9', label: AppStrings.t('rating')),
                      _Stat(value: '${TripCompletionService.instance.driverCompletedCount}', label: AppStrings.t('trip')),
                      _Stat(value: '${_profile.experienceYears} ${AppStrings.t('years_suffix')}', label: AppStrings.t('experience')),
                    ],
                  ),
                ),
              ] else ...[
                Center(
                  child: Material(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _openRole,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.t('passenger'),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                                fontSize: 13,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Stat(
                        value: '${TripCompletionService.instance.passengerTripCount}',
                        label: AppStrings.t('trip'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (registered && driver) ...[
                    _MenuTile(
                      icon: Icons.inbox_outlined,
                      label: AppStrings.t('menu_orders'),
                      onTap: () => AppNavigation.goTrips(),
                    ),
                    _MenuTile(
                      icon: Icons.add_road_rounded,
                      label: AppStrings.t('menu_create_trip'),
                      onTap: () => AppNavigation.goTaxis(),
                    ),
                    _MenuTile(
                      icon: Icons.directions_car_outlined,
                      label: AppStrings.t('menu_my_car'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyCarScreen()),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: AppStrings.t('menu_messages'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DriverMessagesScreen()),
                        );
                      },
                      trailing: ChatService.instance.hasUnreadForDriver ? AppStrings.t('new_badge') : null,
                    ),
                    _MenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: AppStrings.t('menu_earnings'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DriverEarningsScreen()),
                        );
                      },
                    ),
                  ],
                  _MenuTile(
                    icon: Icons.dark_mode_outlined,
                    label: AppStrings.t('menu_appearance'),
                    trailing: switch (ThemeService.instance.preference) {
                      ThemePreference.dark => AppStrings.t('theme_dark'),
                      ThemePreference.auto => AppStrings.t('theme_auto'),
                      ThemePreference.light => AppStrings.t('theme_light'),
                    },
                    onTap: () => _showThemeSheet(),
                  ),
                  if (registered)
                    _MenuTile(
                      icon: Icons.settings_outlined,
                      label: AppStrings.t('menu_settings'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                      ),
                    ),
                  if (registered && (PlatformConfigService.instance.referral || PlatformConfigService.instance.bonus))
                    _MenuTile(
                      icon: Icons.card_giftcard_outlined,
                      label: AppStrings.t('menu_rewards'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardsScreen())),
                    ),
                  _MenuTile(
                    icon: Icons.language_rounded,
                    label: AppStrings.t('menu_language'),
                    trailing: _profile.languageLabel(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.help_outline_rounded,
                    label: AppStrings.t('menu_faq'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _FaqScreen()),
                    ),
                  ),
                  _MenuTile(
                    icon: Icons.support_agent_rounded,
                    label: AppStrings.t('menu_help'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _HelpScreen()),
                    ),
                  ),
                  _MenuTile(
                    icon: Icons.info_outline_rounded,
                    label: AppStrings.t('menu_about'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _AboutScreen()),
                    ),
                  ),
                  if (registered)
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      label: AppStrings.t('menu_logout'),
                      danger: true,
                      showChevron: false,
                      onTap: _confirmLogout,
                    ),
                ],
              ),
            ),
            if (registered && _profile.driverStatus == DriverStatus.none) ...[
              const SizedBox(height: 12),
              SoftCard(
                child: Row(
                  children: [
                    Icon(Icons.local_taxi_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.t('become_driver_prompt'),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BecomeDriverIntroScreen()),
                        );
                      },
                      child: Text(tr("Boshlash"), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.t('appearance'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy)),
                const SizedBox(height: 8),
                for (final e in [
                  (ThemePreference.light, Icons.wb_sunny_outlined, AppStrings.t('theme_light')),
                  (ThemePreference.dark, Icons.nightlight_round, AppStrings.t('theme_dark')),
                  (ThemePreference.auto, Icons.brightness_auto_rounded, AppStrings.t('theme_auto')),
                ])
                  ListTile(
                    leading: Icon(e.$2, color: AppColors.primary),
                    title: Text(e.$3, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    trailing: ThemeService.instance.preference == e.$1
                        ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      await ThemeService.instance.setPreference(e.$1);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openInfo(BuildContext context, String title, String body, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SimpleInfoScreen(title: title, body: body, icon: icon),
      ),
    );
  }
}

class _FaqScreen extends StatelessWidget {
  const _FaqScreen();

  static final _items = [
    (tr('Qanday taksi topaman?'), tr('Bosh sahifada manzillarni kiriting yoki «Taksi topish» bo‘limidan yo‘nalishni tanlang.')),
    (tr('Oldindan bron qilish mumkinmi?'), tr('Ha. «Oldindan bron qilish» orqali sana, vaqt va narxni belgilashingiz mumkin.')),
    (tr('To‘lov qanday amalga oshadi?'), tr('Safar oxirida haydovchi bilan kelishilgan narx bo‘yicha naqd yoki o‘tkazma orqali.')),
    (tr('Haydovchi bo‘lish uchun nima kerak?'), tr('Profildan «Haydovchi bo‘lish» → shaxsiy va avtomobil ma’lumotlarini yuboring. Admin tasdiqlaydi.')),
    (tr('Buyurtmani bekor qilsam bo‘ladimi?'), tr('Ha, faol bronni bekor qilish mumkin. Sabab so‘raladi.')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                const AppBackButton(),
                Expanded(
                  child: Text(
                    AppStrings.t('faq_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 12),
            for (final e in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(e.$1, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 14)),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(e.$2, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HelpScreen extends StatelessWidget {
  const _HelpScreen();

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                const AppBackButton(),
                Expanded(
                  child: Text(
                    AppStrings.t('help_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 16),
            SoftCard(
              child: Column(
                children: [
                  _ContactTile(
                    icon: Icons.phone_rounded,
                    title: tr('Aloqa raqami'),
                    value: SafaronContact.phoneDisplay,
                    onTap: () => _launch('tel:${SafaronContact.phoneTel}'),
                  ),
                  Divider(color: AppColors.cardBorder),
                  _ContactTile(
                    icon: Icons.email_outlined,
                    title: tr('Elektron manzil'),
                    value: SafaronContact.email,
                    onTap: () => _launch('mailto:${SafaronContact.email}'),
                  ),
                  Divider(color: AppColors.cardBorder),
                  _ContactTile(
                    icon: Icons.send_rounded,
                    title: tr('Telegram'),
                    value: SafaronContact.telegram,
                    onTap: () => _launch(SafaronContact.telegramUrl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  Text(value, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                const AppBackButton(),
                Expanded(
                  child: Text(
                    AppStrings.t('about_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 20),
            const Center(child: SafaronLogo(size: 100, borderRadius: 22)),
            const SizedBox(height: 12),
            Text(
              'SAFARON TAXI',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.navy),
            ),
            Text(
              tr('Bir yo‘lda birga'),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 16),
              SoftCard(
                child: Text(
                  'SAFARON — qishloq va shahar oralig‘ida ishonchli mini-taksi va yo‘lovchi tashish platformasi. '
                  'Tez, qulay va xavfsiz safarlar uchun yaratilgan.\n\nVersiya: 1.0.1',
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, height: 1.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy)),
          Text(label, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(badge!, style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.destination : AppColors.navy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? AppColors.destination : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: color),
              ),
            ),
            if (trailing != null)
              Text(trailing!, style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
