import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_navigation.dart';
import '../../services/driver_trip_service.dart';
import '../../services/place_registry_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/money.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/place_picker_field.dart';
import '../../widgets/safaron_header.dart';

class DriverCreateTripScreen extends StatefulWidget {
  const DriverCreateTripScreen({super.key});

  @override
  State<DriverCreateTripScreen> createState() => _DriverCreateTripScreenState();
}

class _DriverCreateTripScreenState extends State<DriverCreateTripScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _extra = TextEditingController();
  final _price = TextEditingController();
  late int _seats;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _seats = ProfileService.instance.seats.clamp(1, 8);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _extra.dispose();
    _price.dispose();
    super.dispose();
  }

  String get _dateLabel {
    const months = [
      'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
      'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
    ];
    return '${_date.day}-${months[_date.month - 1]}, ${_date.year}';
  }

  String get _timeLabel =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _applyRoute(String from, String to) {
    setState(() {
      _from.text = from;
      _to.text = to;
    });
  }

  Future<void> _submit() async {
    final from = PlaceRegistryService.instance.canonicalName(_from.text.trim());
    final to = PlaceRegistryService.instance.canonicalName(_to.text.trim());
    final priceRaw = _price.text.trim();
    final price = priceRaw.isEmpty ? 0 : parseSomInput(priceRaw);
    if (price != null && price > 0 && price < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Narx kamida 1000 so‘m bo‘lishi kerak')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final extras = _extra.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      await DriverTripService.instance.publishTrip(
        from: from,
        to: to,
        toAliases: extras,
        timeLabel: _timeLabel,
        dateLabel: _dateLabel,
        seats: _seats,
        price: price ?? 0,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (!mounted) return;
    final msg = (price ?? 0) <= 0
        ? tr('Ochiq taksi e’lon qilindi — yo‘lovchi narx yuboradi')
        : 'Safar e’lon qilindi · ${formatSom(price!)}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
    AppNavigation.goMessages();
    _from.clear();
    _to.clear();
    _extra.clear();
    _price.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('Safar yaratish'),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: DriverTripService.instance,
                builder: (context, _) {
                  final top = DriverTripService.instance.topRoutes;
                  return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (top.isNotEmpty) ...[
                    Text(
                      tr('Tez-tez e’lon qilgan safarlaringiz'),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                    ),
                    const SizedBox(height: 8),
                    for (final r in top)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _applyRoute(r.from, r.to),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.from.isEmpty && r.to.isEmpty
                                          ? 'Taksi (${r.count} marta)'
                                          : '${r.from.isEmpty ? '—' : r.from} → ${r.to.isEmpty ? '—' : r.to}',
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${r.count}×',
                                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                  SoftCard(
                    child: Column(
                      children: [
                        PlacePickerField(
                          label: 'Qayerdan (ixtiyoriy)',
                          hint: tr('Manzilni tanlang'),
                          controller: _from,
                          accent: AppColors.primary,
                          mapOpen: false,
                          onMapTap: () {},
                        ),
                        const Divider(height: 1),
                        PlacePickerField(
                          label: 'Qayerga (ixtiyoriy)',
                          hint: tr('Manzilni tanlang'),
                          controller: _to,
                          accent: AppColors.destination,
                          mapOpen: false,
                          onMapTap: () {},
                        ),
                        const Divider(height: 1),
                        TextField(
                          controller: _extra,
                          decoration: InputDecoration(
                            labelText: 'Qo‘shimcha manzillar (vergul bilan)',
                            hintText: 'Algabas, Sadvin, Balnitsa',
                            hintStyle: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
                            labelStyle: GoogleFonts.montserrat(fontSize: 12),
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary, size: 18),
                          ),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sana', style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                                Text(_dateLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _pickTime,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vaqt', style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                                Text(_timeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Row(
                      children: [
                        Text(tr('Bo‘sh joylar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                          onPressed: _seats <= 1 ? null : () => setState(() => _seats--),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_seats', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18)),
                        IconButton(
                          onPressed: _seats >= 8 ? null : () => setState(() => _seats++),
                          icon: const Icon(Icons.add_circle, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    color: AppColors.mintSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Narx (ixtiyoriy)', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(
                          tr('Bo‘sh qoldirsangiz yo‘lovchi narx yuboradi. Yozsangiz — shu narx ko‘rinadi.'),
                          style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: tr('Masalan: 25000'),
                            hintStyle: GoogleFonts.montserrat(color: AppColors.textMuted),
                            suffixText: tr("so'm"),
                            suffixStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                          ),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: PrimaryPillButton(
                label: tr('Safarni e’lon qilish'),
                icon: Icons.publish_rounded,
                onTap: _submit,
              ),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }
}
