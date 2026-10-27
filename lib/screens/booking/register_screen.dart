import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/phrase.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/platform_config_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone_uz.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_logo.dart';

/// Telefon raqami kiritiladi: mavjud bo'lsa faqat parol so'raladi
/// (kirish), mavjud bo'lmasa ism/familiya + parol bilan ro'yxatdan
/// o'tiladi.
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
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  bool _lookingUp = false;
  bool _existingUser = false;
  bool _obscurePassword = true;
  String? _error;
  Timer? _lookupTimer;

  /// SMS sozlamasi yoqilgan bo'lsa, 1-qadamdan (telefon+ism) keyin kod
  /// kiritish bosqichiga o'tamiz. O'chirilgan bo'lsa (hozirgi standart),
  /// bu bosqich umuman ko'rinmaydi — to'g'ridan-to'g'ri kiriladi.
  bool _otpStep = false;

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
    _code.addListener(onFieldChange);
    _password.addListener(onFieldChange);
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _name.dispose();
    _surname.dispose();
    _phone.dispose();
    _referral.dispose();
    _code.dispose();
    _password.dispose();
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
    // Faqat bor/yo'qligini so'raymiz — mavjud hisobning ismi/roli kabi
    // ma'lumotlarini bu bosqichda ko'rsatish shart emas (parol hali
    // tasdiqlanmagan).
    final exists = await AuthService.instance.lookupPhone(phone);
    if (!mounted) return;
    setState(() {
      _lookingUp = false;
      _existingUser = exists;
    });
  }

  bool get _phoneOk => PhoneUz.isValidInput9(_phone.text);

  bool get _namesOk {
    final nameOk =
        _name.text.trim().length >= 2 && !RegExp(r'\d').hasMatch(_name.text);
    final surOk =
        _surname.text.trim().length >= 2 &&
        !RegExp(r'\d').hasMatch(_surname.text);
    return nameOk && surOk;
  }

  bool get _passwordOk => _password.text.isNotEmpty;

  bool get _canSubmit {
    if (_submitting || !_phoneOk) return false;
    if (_otpStep) return _code.text.trim().length >= 4;
    if (!_passwordOk) return false;
    if (_existingUser) return true;
    return _namesOk;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final phone = PhoneUz.normalize(_phone.text);
    if (phone == null) return;

    if (PlatformConfigService.instance.smsOtpEnabled && !_otpStep) {
      await _sendCode(phone);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_otpStep) {
        await AuthService.instance.verifyOtp(
          phone: phone,
          code: _code.text.trim(),
          firstName: _name.text.trim(),
          lastName: _surname.text.trim(),
          referralCode: _referral.text.trim(),
        );
      } else if (_existingUser) {
        await AuthService.instance.login(
          phone: phone,
          password: _password.text,
        );
      } else {
        await AuthService.instance.register(
          phone: phone,
          firstName: _name.text.trim(),
          lastName: _surname.text.trim(),
          password: _password.text,
          referralCode: _referral.text.trim(),
        );
      }
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

  Future<void> _sendCode(String phone) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await AuthService.instance.sendOtp(phone);
      // Hozircha haqiqiy SMS provayder ulanmagani uchun, server test kodini
      // xabar matnida qaytaradi (masalan "(dev: 1234)") — shuni avtomatik
      // o'qib, maydonga to'ldiramiz, aks holda foydalanuvchi kodni qayerdan
      // olishini bilmay qolardi.
      final match = RegExp(r'(\d{4,6})\)?\s*$').firstMatch(message);
      if (match != null) _code.text = match.group(1) ?? '';
      if (!mounted) return;
      setState(() {
        _otpStep = true;
        _submitting = false;
      });
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

  void _backToPhoneStep() {
    setState(() {
      _otpStep = false;
      _code.clear();
      _error = null;
    });
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackButton(),
                ),
                const SizedBox(height: 8),
                const Center(child: SafaronLogo(size: 110, borderRadius: 24)),
                const SizedBox(height: 18),
                Text(
                  _existingUser
                      ? AppStrings.t('login_existing_title')
                      : AppStrings.t('register_title'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: AppColors.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _existingUser
                      ? AppStrings.t('existing_user_banner')
                      : AppStrings.t('register_subtitle'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_lookingUp) ...[
                  const SizedBox(height: 10),
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (!_otpStep) ...[
                  SoftField(
                    controller: _phone,
                    hint: '90 123 45 67',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    prefix: Text(
                      '+998 ',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (_existingUser) ...[
                    const SizedBox(height: 10),
                    SoftField(
                      controller: _password,
                      hint: AppStrings.t('password_field'),
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    SoftField(
                      controller: _name,
                      hint: AppStrings.t('first_name'),
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    SoftField(
                      controller: _surname,
                      hint: AppStrings.t('last_name'),
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 10),
                    SoftField(
                      controller: _password,
                      hint: AppStrings.t('password_field'),
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SoftField(
                      controller: _referral,
                      hint: AppStrings.t('referral_code_optional'),
                      icon: Icons.card_giftcard_outlined,
                    ),
                  ],
                ] else ...[
                  Text(
                    tr('+998 {phone} raqamiga tasdiqlash kodi yuborildi').replaceAll('{phone}', _phone.text),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftField(
                    controller: _code,
                    hint: tr('Tasdiqlash kodi'),
                    icon: Icons.sms_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _submitting ? null : _backToPhoneStep,
                        child: Text(tr('Raqamni o‘zgartirish')),
                      ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                final phone = PhoneUz.normalize(_phone.text);
                                if (phone != null) _sendCode(phone);
                              },
                        child: Text(tr('Qayta yuborish')),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                PrimaryPillButton(
                  label: _submitting
                      ? AppStrings.t('waiting')
                      : (_otpStep
                            ? tr('Tasdiqlash')
                            : (_existingUser
                                  ? AppStrings.t('login_existing_btn')
                                  : AppStrings.t('continue_btn'))),
                  icon: Icons.arrow_forward_rounded,
                  enabled: _canSubmit,
                  onTap: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: GoogleFonts.montserrat(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
