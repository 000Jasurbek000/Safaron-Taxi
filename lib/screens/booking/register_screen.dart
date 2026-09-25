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



/// Telefon + ism + familiya — SMS keyingi bosqichda.

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

  String? _error;



  @override

  void initState() {

    super.initState();

    void onFieldChange() {

      if (mounted) setState(() {});

    }

    _name.addListener(onFieldChange);

    _surname.addListener(onFieldChange);

    _phone.addListener(onFieldChange);
    _referral.addListener(onFieldChange);

  }



  @override

  void dispose() {

    _name.dispose();

    _surname.dispose();

    _phone.dispose();
    _referral.dispose();

    super.dispose();

  }



  bool get _phoneOk => PhoneUz.isValidInput9(_phone.text);



  bool get _namesOk {

    final nameOk = _name.text.trim().length >= 2 && !RegExp(r'\d').hasMatch(_name.text);

    final surOk = _surname.text.trim().length >= 2 && !RegExp(r'\d').hasMatch(_surname.text);

    return nameOk && surOk;

  }



  bool get _canSubmit => _phoneOk && _namesOk && !_submitting;



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

                  AppStrings.t('register_title'),

                  textAlign: TextAlign.center,

                  style: GoogleFonts.montserrat(color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w800),

                ),

                const SizedBox(height: 6),

                Text(

                  AppStrings.t('register_subtitle'),

                  textAlign: TextAlign.center,

                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),

                ),

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

                const SizedBox(height: 10),

                SoftField(controller: _referral, hint: AppStrings.t('referral_code_optional'), icon: Icons.card_giftcard_outlined),

                const SizedBox(height: 16),

                PrimaryPillButton(

                  label: _submitting ? AppStrings.t('waiting') : AppStrings.t('continue_btn'),

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

