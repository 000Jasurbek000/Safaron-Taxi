import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// 1–5 yulduz baho dialogi.
Future<int?> showTripRatingDialog(BuildContext context, {String title = 'Safarni baholang'}) async {
  var stars = 5;
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: Text(tr(title), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 17)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('1 dan 5 gacha yulduz tanlang'),
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => stars = i),
                        icon: Icon(
                          i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFF5B301),
                          size: 36,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, stars),
                child: Text('Yuborish', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ],
          );
        },
      );
    },
  );
}
