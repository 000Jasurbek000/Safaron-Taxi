import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/phrase.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/plate_uz.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/plate_input_row.dart';
import 'driver_application_sent_screen.dart';
import 'driver_step_header.dart';

class DriverVehicleInfoScreen extends StatefulWidget {
  const DriverVehicleInfoScreen({super.key});

  @override
  State<DriverVehicleInfoScreen> createState() => _DriverVehicleInfoScreenState();
}

class _DriverVehicleInfoScreenState extends State<DriverVehicleInfoScreen> {
  final _profile = ProfileService.instance;
  final _region = TextEditingController();
  final _midLetter = TextEditingController();
  final _digits = TextEditingController();
  final _endLetters = TextEditingController();
  late String _carName;
  late int _seats;
  String? _carPhotoPath;
  bool _submitting = false;

  static const _cars = [
    'Chevrolet Cobalt',
    'Chevrolet Nexia',
    'Chevrolet Spark',
    'Chevrolet Tracker',
    'BYD Chazor',
  ];

  @override
  void initState() {
    super.initState();
    _carName = _cars.contains(_profile.carName) ? _profile.carName : _cars.first;
    _seats = _profile.seats.clamp(1, 10);
    _region.addListener(_refresh);
    _midLetter.addListener(_refresh);
    _digits.addListener(_refresh);
    _endLetters.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _region.dispose();
    _midLetter.dispose();
    _digits.dispose();
    _endLetters.dispose();
    super.dispose();
  }

  Future<void> _pickCarPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _carPhotoPath = file.path);
  }

  Future<void> _continue() async {
    if (_carPhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("Mashina rasmini qo'shing")), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!PlateUz.isValidParts(_region.text, _midLetter.text, _digits.text, _endLetters.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Raqam: 80 A 567 DB yoki 80 567 DBB')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final plate = PlateUz.display(
      PlateUz.normalize(_region.text, _midLetter.text, _digits.text, _endLetters.text),
    );
    setState(() => _submitting = true);
    await _profile.saveVehicle(
      carName: _carName,
      plate: plate,
      seats: _seats,
      hasCarPhoto: true,
      carPhotoPath: _carPhotoPath,
    );

    // Backendga ariza (admin panelda chiqishi uchun)
    try {
      if (AuthService.instance.registered && AuthService.instance.user != null) {
        await ApiClient.instance.postMultipart(
          '/api/drivers/apply',
          fields: {
            'experience_years': '${_profile.experienceYears}',
            'model_name': _carName,
            'plate': PlateUz.normalize(_region.text, _midLetter.text, _digits.text, _endLetters.text),
            'seats': '$_seats',
          },
          files: {
            'selfie': _profile.selfiePath.isNotEmpty ? _profile.selfiePath : _carPhotoPath!,
            'vehicle_photo': _carPhotoPath!,
          },
        );
        await AuthService.instance.refreshMe();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Ariza yuborilmadi. Qayta urinib ko‘ring.')), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    await _profile.submitApplication();
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverApplicationSentScreen()),
      (route) => route.isFirst,
    );
  }

  Widget _plateBox({
    required TextEditingController controller,
    required String hint,
    required int maxLen,
    bool letters = false,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        keyboardType: letters ? TextInputType.text : TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxLen),
          if (letters)
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]'))
          else
            FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((old, neu) {
            return neu.copyWith(text: neu.text.toUpperCase());
          }),
        ],
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 1),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            DriverStepHeader(current: 2, total: 2, title: tr("Avtomobil ma'lumotlari")),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(tr("Mashina rasmi *"), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickCarPhoto,
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1.8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _carPhotoPath != null
                            ? Image.file(File(_carPhotoPath!), fit: BoxFit.cover)
                            : Container(
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 36),
                                    const SizedBox(height: 6),
                                    Text(tr('Galereyadan tanlash'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(tr("Moshina nomi *"), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _carName,
                        isExpanded: true,
                        items: [
                          for (final c in _cars)
                            DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppColors.navy))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _carName = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('Davlat raqami *'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(tr('Masalan: 80 A 567 DB yoki 80 567 DBB'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  PlateInputRow(
                    region: _region,
                    midLetter: _midLetter,
                    digits: _digits,
                    endLetters: _endLetters,
                  ),
                  const SizedBox(height: 12),
                  Text(tr("Yo'lovchilar sig'imi *"), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
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
                        value: _seats,
                        isExpanded: true,
                        items: [
                          for (var s = 1; s <= 10; s++)
                            DropdownMenuItem(value: s, child: Text('$s kishi', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppColors.navy))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _seats = v);
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
                label: _submitting ? 'Yuborilmoqda...' : tr('Davom etish'),
                icon: null,
                enabled: !_submitting,
                onTap: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
