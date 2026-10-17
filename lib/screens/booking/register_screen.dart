import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone_uz.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_logo.dart';

/// Telefon + ism + familiya. Mavjud raqam — eski profil yuklanadi.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _phone = TextEditingController();
  final _referral = TextEditingController();

  bool _submitting = false;
  bool _lookingUp = false;
  bool _existingUser = false;
  String? _error;
  Timer? _lookupTimer;

  @override
  void initState() {
    super.initState();
    void onFieldChange() {
      if (mounted) setState(() {});
    }

    _name.addListener(onFieldChange);
    _surname.addListener(onFieldChange);
    _phone.addListener(_onPhoneChanged);
    _referral.addListener(onFieldChange);
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _name.dispose();
    _surname.dispose();
    _phone.dispose();
    _referral.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    if (mounted) setState(() {});
    _lookupTimer?.cancel();
    if (!_phoneOk) {
      if (_existingUser) {
        setState(() => _existingUser = false);
      }
      return;
    }
    _lookupTimer = Timer(const Duration(milliseconds: 450), _lookupExisting);
  }

  Future<void> _lookupExisting() async {
    final phone = PhoneUz.normalize(_phone.text);
    if (phone == null || !mounted) return;
    setState(() => _lookingUp = true);
    final found = await AuthService.instance.lookupPhone(phone);
    if (!mounted) return;
    setState(() {
      _lookingUp = false;
      _existingUser = found.exists;
      if (found.exists) {
        if (found.firstName.isNotEmpty) _name.text = found.firstName;
        if (found.lastName.isNotEmpty) _surname.text = found.lastName;
      }
    });
  }

  bool get _phoneOk => PhoneUz.isValidInput9(_phone.text);

  bool get _namesOk {
    final nameOk = _name.text.trim().length >= 2 && !RegExp(r'\d').hasMatch(_name.text);
    final surOk = _surname.text.trim().length >= 2 && !RegExp(r'\d').hasMatch(_surname.text);
    return nameOk && surOk;
  }

  bool get _canSubmit {
    if (_submitting || !_phoneOk) return false;
    if (_existingUser) return true;
    return _namesOk;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final phone = PhoneUz.normalize(_phone.text);
    if (phone == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AuthService.instance.signInWithProfile(
        phone: phone,
        firstName: _name.text.trim(),
        lastName: _surname.text.trim(),
        referralCode: _referral.text.trim(),
      );
      await ProfileService.instance.syncFromAuth();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = AppStrings.t('server_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
                const SizedBox(height: 8),
                const Center(child: SafaronLogo(size: 110, borderRadius: 24)),
                const SizedBox(height: 18),
                Text(
                  _existingUser ? AppStrings.t('login_existing_title') : AppStrings.t('register_title'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _existingUser ? AppStrings.t('existing_user_banner') : AppStrings.t('register_subtitle'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (_lookingUp) ...[
                  const SizedBox(height: 10),
                  const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                ],
                const SizedBox(height: 22),
                SoftField(controller: _name, hint: AppStrings.t('first_name'), icon: Icons.person_outline_rounded),
                const SizedBox(height: 10),
                SoftField(controller: _surname, hint: AppStrings.t('last_name'), icon: Icons.badge_outlined),
                const SizedBox(height: 10),
                SoftField(
                  controller: _phone,
                  hint: '90 123 45 67',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                  prefix: Text('+998 ', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.navy)),
                ),
                if (!_existingUser) ...[
                  const SizedBox(height: 10),
                  SoftField(controller: _referral, hint: AppStrings.t('referral_code_optional'), icon: Icons.card_giftcard_outlined),
                ],
                const SizedBox(height: 16),
                PrimaryPillButton(
                  label: _submitting
                      ? AppStrings.t('waiting')
                      : (_existingUser ? AppStrings.t('login_existing_btn') : AppStrings.t('continue_btn')),
                  icon: Icons.arrow_forward_rounded,
                  enabled: _canSubmit,
                  onTap: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: GoogleFonts.montserrat(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
