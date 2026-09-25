import 'dart:io';
import '../../../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/plate_uz.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/plate_input_row.dart';
import '../../../widgets/safaron_header.dart';

class MyCarScreen extends StatefulWidget {
  const MyCarScreen({super.key});

  @override
  State<MyCarScreen> createState() => _MyCarScreenState();
}

class _MyCarScreenState extends State<MyCarScreen> {
  final _profile = ProfileService.instance;
  bool _editing = false;
  late String _carName;
  late int _seats;
  String? _photoPath;
  final _region = TextEditingController();
  final _midLetter = TextEditingController();
  final _digits = TextEditingController();
  final _endLetters = TextEditingController();

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
    _carName = _profile.carName.isEmpty ? _cars.first : _profile.carName;
    _seats = _profile.seats.clamp(1, 10);
    _photoPath = _profile.carPhotoPath.isEmpty ? null : _profile.carPhotoPath;
    _parsePlate(_profile.plate);
  }

  void _parsePlate(String plate) {
    final p = plate.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final m = RegExp(r'^(\d{2})([A-Z]?)(\d{3})([A-Z]{2,3})$').firstMatch(p);
    if (m == null) return;
    _region.text = m.group(1)!;
    _midLetter.text = m.group(2)!;
    _digits.text = m.group(3)!;
    _endLetters.text = m.group(4)!;
  }

  @override
  void dispose() {
    _region.dispose();
    _midLetter.dispose();
    _digits.dispose();
    _endLetters.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    if (!PlateUz.isValidParts(_region.text, _midLetter.text, _digits.text, _endLetters.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Raqam: 01 A 123 BC yoki 01 123 ABC')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final plate = PlateUz.display(
      PlateUz.normalize(_region.text, _midLetter.text, _digits.text, _endLetters.text),
    );
    await _profile.saveVehicle(
      carName: _carName,
      plate: plate,
      seats: _seats,
      hasCarPhoto: _photoPath != null,
      carPhotoPath: _photoPath,
    );
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saqlangan'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _photo() {
    final path = _photoPath ?? _profile.carPhotoPath;
    if (path.isNotEmpty && !path.startsWith('assets/')) {
      return Image.file(File(path), height: 150, width: double.infinity, fit: BoxFit.cover);
    }
    return Image.asset('assets/images/car_cobalt.png', height: 150, width: double.infinity, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      tr('Mening avtomobilim'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_editing) {
                        _save();
                      } else {
                        setState(() => _editing = true);
                      }
                    },
                    child: Text(
                      _editing ? tr('Saqlash') : 'Tahrirlash',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SoftCard(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _photo(),
                            ),
                            if (_editing)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: FloatingActionButton.small(
                                  onPressed: _pickPhoto,
                                  backgroundColor: AppColors.primary,
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_editing) ...[
                          DropdownButtonFormField<String>(
                            value: _cars.contains(_carName) ? _carName : _cars.first,
                            decoration: InputDecoration(labelText: 'Moshina', labelStyle: GoogleFonts.montserrat()),
                            items: _cars.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _carName = v ?? _carName),
                          ),
                          const SizedBox(height: 10),
                          Text(tr('Davlat raqami'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 8),
                          PlateInputRow(
                            region: _region,
                            midLetter: _midLetter,
                            digits: _digits,
                            endLetters: _endLetters,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(tr('O‘rindiqlar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                              const Spacer(),
                              IconButton(
                                onPressed: _seats <= 1 ? null : () => setState(() => _seats--),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$_seats', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18)),
                              IconButton(
                                onPressed: _seats >= 10 ? null : () => setState(() => _seats++),
                                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ] else ...[
                          _Row(label: 'Moshina nomi', value: _profile.carName),
                          _Row(label: tr('Davlat raqami'), value: _profile.plate),
                          _Row(label: "Yo'lovchi sig'imi", value: '${_profile.seats} kishi'),
                          _Row(label: 'Tajriba', value: '${_profile.experienceYears} yil'),
                        ],
                      ],
                    ),
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13)),
          ),
          Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
        ],
      ),
    );
  }
}
