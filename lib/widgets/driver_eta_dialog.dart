import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/eta_util.dart';

/// Instant + jo‘nash vaqti yo‘q bo‘lsa daqiqa so‘raydi; aks holda null (vaqtdan ETA).
Future<int?> askDriverEtaMinutes(
  BuildContext context, {
  required String timeLabel,
  required bool isPrebook,
}) async {
  if (isPrebook) return null;
  final until = EtaUtil.untilDeparture(timeLabel);
  if (until != null && until.inMinutes > 0) {
    // E’londa vaqt bor — daqiqa so‘ralmaydi
    return until.inMinutes;
  }

  final ctrl = TextEditingController(text: '15');
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          tr('Taxminan qancha vaqtda yetib borasiz?'),
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Daqiqa',
            suffixText: 'daq',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Bekor', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim()) ?? 0;
              if (n < 1 || n > 300) return;
              Navigator.pop(ctx, n);
            },
            child: Text('Tasdiqlash', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ],
      );
    },
  );
  return result;
}
