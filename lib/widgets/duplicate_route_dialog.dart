import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Bir xil yo‘nalishda faol so‘rov borligini ogohlantirish.
Future<bool> showDuplicateRouteDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        tr('Faol so‘rov bor'),
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy),
      ),
      content: Text(
        tr('Bu manzilga allaqachon taksi chaqirgansiz. Avvalgi so‘rov uchun haydovchi javobini kutishingiz mumkin.'),
        style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textMuted, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Bekor qilish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            tr('Yangi haydovchiga yuborish'),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
