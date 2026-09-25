import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/plate_uz.dart';

/// Davlat raqami: o‘rtada 1 harf → oxirida 2; bo‘lmasa oxirida 3.
class PlateInputRow extends StatefulWidget {
  const PlateInputRow({
    super.key,
    required this.region,
    required this.midLetter,
    required this.digits,
    required this.endLetters,
  });

  final TextEditingController region;
  final TextEditingController midLetter;
  final TextEditingController digits;
  final TextEditingController endLetters;

  @override
  State<PlateInputRow> createState() => _PlateInputRowState();
}

class _PlateInputRowState extends State<PlateInputRow> {
  @override
  void initState() {
    super.initState();
    widget.midLetter.addListener(_syncEndLetters);
  }

  @override
  void dispose() {
    widget.midLetter.removeListener(_syncEndLetters);
    super.dispose();
  }

  void _syncEndLetters() {
    final max = PlateUz.endLettersMax(widget.midLetter.text);
    final t = widget.endLetters.text.toUpperCase();
    if (t.length > max) {
      widget.endLetters.text = t.substring(0, max);
      widget.endLetters.selection = TextSelection.collapsed(offset: max);
    }
    if (mounted) setState(() {});
  }

  int get _endMax => PlateUz.endLettersMax(widget.midLetter.text);

  Widget _box(TextEditingController c, String hint, int maxLen, {bool letters = false}) {
    return Expanded(
      flex: letters && maxLen > 2 ? 2 : 1,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        textCapitalization: letters ? TextCapitalization.characters : TextCapitalization.none,
        keyboardType: letters ? TextInputType.text : TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxLen),
          if (letters)
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]'))
          else
            FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((old, neu) => neu.copyWith(text: neu.text.toUpperCase())),
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
    return Row(
      children: [
        _box(widget.region, '01', 2),
        const SizedBox(width: 6),
        _box(widget.midLetter, 'A', 1, letters: true),
        const SizedBox(width: 6),
        _box(widget.digits, '123', 3),
        const SizedBox(width: 6),
        _box(widget.endLetters, _endMax == 2 ? 'BC' : 'ABC', _endMax, letters: true),
      ],
    );
  }
}
