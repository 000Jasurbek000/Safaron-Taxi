import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../utils/money.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/nav_actions.dart';
import '../../widgets/safaron_header.dart';
import '../../services/active_booking_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/safaron_api.dart';
import 'prebook_waiting_screen.dart';
import 'register_screen.dart';

class PrebookRequest {
  const PrebookRequest({
    required this.from,
    required this.to,
    required this.exactPlace,
    required this.date,
    required this.time,
    required this.passengers,
    required this.hasLuggage,
    required this.note,
    required this.offeredPrice,
  });

  final String from;
  final String to;
  final String exactPlace;
  final DateTime date;
  final TimeOfDay time;
  final int passengers;
  final bool hasLuggage;
  final String note;

  /// Yo‘lovchi taklif qilgan narx (so‘m).
  final int offeredPrice;

  String get dateLabel {
    const months = [
      'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
      'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
    ];
    return '${date.day}-${months[date.month - 1]}, ${date.year}';
  }

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class PrebookScreen extends StatefulWidget {
  const PrebookScreen({
    super.key,
    this.initialFrom = '',
    this.initialTo = '',
    this.initialPassengers = 1,
  });

  final String initialFrom;
  final String initialTo;
  final int initialPassengers;

  @override
  State<PrebookScreen> createState() => _PrebookScreenState();
}

class _PrebookScreenState extends State<PrebookScreen> {
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _exact;
  late final TextEditingController _note;
  late final TextEditingController _price;
  late DateTime _date;
  late TimeOfDay _time;
  late int _passengers;
  bool _luggage = false;

  @override
  void initState() {
    super.initState();
    _from = TextEditingController(text: widget.initialFrom);
    _to = TextEditingController(text: widget.initialTo);
    _exact = TextEditingController();
    _note = TextEditingController();
    _price = TextEditingController();
    _date = DateTime.now().add(const Duration(days: 1));
    _time = const TimeOfDay(hour: 8, minute: 0);
    _passengers = widget.initialPassengers.clamp(1, 15);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _exact.dispose();
    _note.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() async {
    final from = _from.text.trim();
    final to = _to.text.trim();
    final offered = parseSomInput(_price.text);
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Qayerdan va Qayerga manzillarini yozing"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (from.toLowerCase() == to.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Qayerdan va qayerga bir xil bo‘lishi mumkin emas.')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (offered == null || offered < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Taklif narxingizni kiriting (masalan: 100000)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final scheduled = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (scheduled.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Vaqt o‘tib ketgan.')), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final request = PrebookRequest(
      from: from,
      to: to,
      exactPlace: _exact.text.trim(),
      date: _date,
      time: _time,
      passengers: _passengers,
      hasLuggage: _luggage,
      note: _note.text.trim(),
      offeredPrice: offered,
    );

    try {
      await AuthService.instance.load();
      if (!AuthService.instance.registered) {
        if (!mounted) return;
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
        if (ok != true || !mounted) return;
      }
      final remote = await RequestApi.instance.create(
        fromText: from,
        toText: to,
        scheduledAt: scheduled,
        passengersCount: _passengers,
        offeredPrice: offered,
        exactPlace: _exact.text.trim(),
        hasLuggage: _luggage,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      final err = await ActiveBookingService.instance.startPrebook(request: request, remoteRequestId: remote.id);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrebookWaitingScreen(request: request, remoteRequestId: remote.id),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SafaronHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.mintSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_available_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Oldindan bron qilish'),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              tr('Istalgan sana va vaqtda, istalgan manzilga'),
                              style: GoogleFonts.montserrat(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PlaceBlock(
                    label: 'Qayerdan?',
                    controller: _from,
                    pinColor: AppColors.primary,
                    hint: tr('Masalan: uy manzili, mahalla, bozor...'),
                  ),
                  const SizedBox(height: 10),
                  _PlaceBlock(
                    label: 'Qayerga?',
                    controller: _to,
                    pinColor: AppColors.destination,
                    hint: 'Istalgan manzilni yozing (ro‘yxatda bo‘lmasa ham)',
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aniq joy (ixtiyoriy)', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        TextField(
                          controller: _exact,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: tr('Masalan: 44-maktab oldi, maktab oldida...'),
                            hintStyle: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                          ),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SoftCard(
                          child: InkWell(
                            onTap: _pickDate,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sana', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${_date.day}-${_month(_date.month)}, ${_date.year}',
                                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SoftCard(
                          child: InkWell(
                            onTap: _pickTime,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vaqt', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Row(
                      children: [
                        const Icon(Icons.groups_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Yo'lovchilar soni", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
                        _RoundBtn(icon: Icons.remove_rounded, onTap: _passengers <= 1 ? null : () => setState(() => _passengers--)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$_passengers', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                        _RoundBtn(icon: Icons.add_rounded, filled: true, onTap: _passengers >= 15 ? null : () => setState(() => _passengers++)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Row(
                      children: [
                        const Icon(Icons.luggage_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Bagaj (ixtiyoriy)', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
                        _Toggle(label: "Yo'q", selected: !_luggage, onTap: () => setState(() => _luggage = false)),
                        const SizedBox(width: 8),
                        _Toggle(label: 'Bor', selected: _luggage, onTap: () => setState(() => _luggage = true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    color: const Color(0xFFF3F6FA),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: Color(0xFF2C4A6E), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr('Taklif narxingiz'),
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF2C4A6E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Ro‘yxatda yo‘q manzilga ham o‘z narxingizni yozing. Haydovchilar shu narxni qabul qilishi yoki o‘z narxini taklif qilishi mumkin.'),
                          style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted, height: 1.35),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: tr('Masalan: 100000'),
                            hintStyle: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 14),
                            suffixText: tr("so'm"),
                            suffixStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: const Color(0xFF2C4A6E)),
                          ),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 22, color: const Color(0xFF2C4A6E)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Qo'shimcha ma'lumot (ixtiyoriy)", style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        TextField(
                          controller: _note,
                          maxLength: 200,
                          maxLines: 3,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Masalan: Katta yo'l bo'yidan olib ketish, bolalar bor...",
                            hintStyle: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                          ),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    color: AppColors.mintSoft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.groups_2_rounded, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "So‘rov barcha haydovchilarga boradi. Ular sizning narxingizni qabul qilishi yoki o‘z narxini yozib javob berishi mumkin.",
                            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: PrimaryPillButton(
                label: "Taksi so'rash",
                icon: Icons.send_rounded,
                onTap: _submit,
              ),
            ),
            const BottomHomeBar(),
          ],
        ),
      ),
    );
  }

  String _month(int m) {
    const months = [
      'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
      'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
    ];
    return months[m - 1];
  }
}

class _PlaceBlock extends StatelessWidget {
  const _PlaceBlock({
    required this.label,
    required this.controller,
    required this.pinColor,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final Color pinColor;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt_rounded, color: pinColor, size: 18),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: GoogleFonts.montserrat(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              color: selected ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.filled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: filled ? AppColors.primary : AppColors.mintSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: filled ? Colors.white : AppColors.primary)),
        ),
      ),
    );
  }
}
