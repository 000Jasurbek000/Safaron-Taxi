import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone_uz.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_header.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _profile = ProfileService.instance;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late int _experience;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: _profile.firstName);
    _last = TextEditingController(text: _profile.lastName);
    _experience = _profile.experienceYears;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        experienceYears: _profile.isApprovedDriver ? _experience : null,
      );
      await _profile.savePersonal(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        phone: _profile.phone,
        hasSelfie: _profile.hasSelfie,
        experienceYears: _experience,
      );
      await ProfileService.instance.syncFromAuth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('saved')), behavior: SnackBarBehavior.floating),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  const AppBackButton(),
                  Expanded(
                    child: Text(
                      AppStrings.t('settings_title'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.t('personal_info'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 12),
                        SoftField(controller: _first, hint: AppStrings.t('first_name_short'), icon: Icons.person_outline_rounded),
                        const SizedBox(height: 10),
                        SoftField(controller: _last, hint: AppStrings.t('last_name_short'), icon: Icons.badge_outlined),
                        if (_profile.isApprovedDriver) ...[
                          const SizedBox(height: 14),
                          Text(AppStrings.t('experience_years'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13)),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _experience <= 0 ? null : () => setState(() => _experience--),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$_experience', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20)),
                              IconButton(
                                onPressed: _experience >= 60 ? null : () => setState(() => _experience++),
                                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        PrimaryPillButton(
                          label: _saving ? AppStrings.t('saving') : AppStrings.t('save'),
                          icon: Icons.save_outlined,
                          enabled: !_saving,
                          onTap: _saveProfile,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.t('phone_number'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(PhoneUz.display(_profile.phone), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.t('phone_change_hint'),
                          style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
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
