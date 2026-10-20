import '../../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/smart_photo.dart';
import 'driver_step_header.dart';
import 'driver_vehicle_info_screen.dart';

class DriverPersonalInfoScreen extends StatefulWidget {
  const DriverPersonalInfoScreen({super.key});

  @override
  State<DriverPersonalInfoScreen> createState() => _DriverPersonalInfoScreenState();
}

class _DriverPersonalInfoScreenState extends State<DriverPersonalInfoScreen> {
  final _profile = ProfileService.instance;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late int _experience;
  bool _hasPhoto = false;
  String _selfiePath = '';

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: _profile.firstName);
    _last = TextEditingController(text: _profile.lastName);
    _phone = TextEditingController(text: _profile.phone);
    _experience = _profile.experienceYears;
    _selfiePath = _bestPhoto();
    _hasPhoto = _selfiePath.isNotEmpty;
  }

  String _bestPhoto() {
    if (_profile.selfiePath.isNotEmpty) return _profile.selfiePath;
    if (_profile.avatarPath.isNotEmpty) return _profile.avatarPath;
    final remote = AuthService.instance.user?.avatarPath;
    if (remote != null && remote.isNotEmpty) return remote;
    return '';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("Ism va familiyani to'ldiring")), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    // Ism/familiya tuzatilgan bo'lsa serverga ham yozamiz — aks holda bu
    // yerdagi tuzatish faqat shu qurilmada qolib, keyingi syncFromAuth()
    // chaqirilganda (masalan arizani yuborgandan keyin "Yangilash" bosilganda)
    // eski server qiymati bilan almashtirilib ketardi.
    if (AuthService.instance.registered &&
        (_first.text.trim() != AuthService.instance.user?.firstName ||
            _last.text.trim() != AuthService.instance.user?.lastName)) {
      try {
        await AuthService.instance.updateProfile(
          firstName: _first.text,
          lastName: _last.text,
        );
      } catch (_) {
        // Best-effort — tarmoq xatosi ariza bosqichini to'xtatmasin.
      }
    }
    await _profile.savePersonal(
      firstName: _first.text,
      lastName: _last.text,
      phone: _phone.text,
      experienceYears: _experience,
      hasSelfie: _hasPhoto,
      selfiePath: _selfiePath,
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverVehicleInfoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            DriverStepHeader(current: 1, total: 2, title: tr("Shaxsiy ma'lumotlar")),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.mintSoft,
                          child: ClipOval(
                            child: SizedBox(
                              width: 104,
                              height: 104,
                              child: _selfiePath.isEmpty
                                  ? const Icon(Icons.person_rounded, size: 48, color: AppColors.primary)
                                  : SmartPhoto(src: _selfiePath, width: 104, height: 104, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: AppColors.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () async {
                                final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
                                if (file == null) return;
                                setState(() {
                                  _hasPhoto = true;
                                  _selfiePath = file.path;
                                });
                              },
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr("O'zingizning rasmingiz (ixtiyoriy)"),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  _Field(label: tr('Ism *'), controller: _first),
                  const SizedBox(height: 12),
                  _Field(label: tr('Familiya *'), controller: _last),
                  const SizedBox(height: 12),
                  _Field(label: tr('Telefon raqam'), controller: _phone, keyboard: TextInputType.phone),
                  const SizedBox(height: 12),
                  Text(
                    tr('Tajriba yili *'),
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _experience,
                        isExpanded: true,
                        items: [
                          for (var y = 1; y <= 20; y++)
                            DropdownMenuItem(
                              value: y,
                              child: Text('$y yil', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _experience = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrimaryPillButton(
                label: tr('Davom etish'),
                icon: null,
                onTap: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboard,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
