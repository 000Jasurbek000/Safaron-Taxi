import 'package:flutter/material.dart';
import '../../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_ui.dart';
import 'driver_personal_info_screen.dart';

class BecomeDriverIntroScreen extends StatelessWidget {
  const BecomeDriverIntroScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(
                    tr("Haydovchi bo'lish"),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr("Bir necha qadamda haydovchi sifatida ro'yxatdan o'ting"),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  _Step(
                    n: 1,
                    title: tr("Profil rasmi"),
                    subtitle: tr("O'zingizning rasmi va ism-familiya"),
                    last: false,
                  ),
                  _Step(
                    n: 2,
                    title: tr("Mashina rasmi"),
                    subtitle: tr("Avtomobil rasmi va raqami"),
                    last: true,
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    'assets/images/become_driver_hero.png',
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.local_taxi_rounded, size: 96, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrimaryPillButton(
                label: tr('Boshlash'),
                icon: null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.subtitle,
    required this.last,
  });

  final int n;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.mintSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
                  Text(subtitle, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
