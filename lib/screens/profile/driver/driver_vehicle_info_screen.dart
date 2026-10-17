import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/phrase.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/plate_uz.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/car_model_picker.dart';
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
  String? _regionHint;
  final _customCar = TextEditingController();

  @override
  void initState() {
    super.initState();
    final models = CarModelPicker.models();
    _carName = models.contains(_profile.carName) ? _profile.carName : (models.first);
    if (!models.contains(_profile.carName) && _profile.carName.isNotEmpty) {
      _carName = kOtherCarModel;
      _customCar.text = _profile.carName;
    }
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
    _customCar.dispose();
    super.dispose();
  }

  String? _localSelfie() {
    for (final p in [_profile.selfiePath, _profile.avatarPath]) {
      if (p.isNotEmpty && File(p).existsSync()) return p;
    }
    return null;
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
    final modelName = CarModelPicker.resolve(_carName, _customCar.text);
    if (modelName.isEmpty || modelName == kOtherCarModel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Moshina modelini yozing')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final snapped = PlateUz.snapRegion(_region.text);
    if (snapped.length == 2 && snapped != _region.text && PlateUz.validRegions.contains(snapped)) {
      _region.text = snapped;
    }
    final plateErr = PlateUz.partsError(_region.text, _midLetter.text, _digits.text, _endLetters.text);
    if (plateErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(plateErr), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final plate = PlateUz.display(
      PlateUz.normalize(_region.text, _midLetter.text, _digits.text, _endLetters.text),
    );
    setState(() => _submitting = true);
    await _profile.saveVehicle(
      carName: modelName,
      plate: plate,
      seats: _seats,
      hasCarPhoto: true,
      carPhotoPath: _carPhotoPath,
    );

    // Backendga ariza (admin panelda chiqishi uchun)
    try {
      if (AuthService.instance.registered && AuthService.instance.user != null) {
        final selfie = _localSelfie();
        await ApiClient.instance.postMultipart(
          '/api/drivers/apply',
          fields: {
            'experience_years': '${_profile.experienceYears}',
            'model_name': modelName,
            'plate': PlateUz.normalize(_region.text, _midLetter.text, _digits.text, _endLetters.text),
            'seats': '$_seats',
          },
          files: {
            'selfie': ?selfie,
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
                  CarModelPicker(
                    value: _carName,
                    customController: _customCar,
                    onChanged: (v) => setState(() => _carName = v),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('Davlat raqami *'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(tr('Namuna: 00 A 000 AA yoki 00 000 AAA'), style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  PlateInputRow(
                    region: _region,
                    midLetter: _midLetter,
                    digits: _digits,
                    endLetters: _endLetters,
                    onRegionCorrected: (msg) {
                      if (!mounted) return;
                      setState(() => _regionHint = msg);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                  if (_regionHint != null) ...[
                    const SizedBox(height: 6),
                    Text(_regionHint!, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                  ],
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
                label: _submitting ? tr('Yuborilmoqda...') : tr('Davom etish'),
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
