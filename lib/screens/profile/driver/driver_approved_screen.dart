import 'package:flutter/material.dart';
import '../../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_ui.dart';

class DriverApprovedScreen extends StatelessWidget {
  const DriverApprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Align(alignment: Alignment.centerLeft, child: AppBackButton()),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 72),
                  const SizedBox(height: 12),
                  Text(
                    'Tabriklaymiz!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Siz haydovchi sifatida tasdiqlandingiz.\nEndi ilovada safar qabul qilishingiz mumkin.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/driver_approved_car.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrimaryPillButton(
                label: tr('Boshlash'),
                icon: null,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
