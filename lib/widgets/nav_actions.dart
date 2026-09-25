import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_navigation.dart';
import '../theme/app_colors.dart';

void goToHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  AppNavigation.goHome();
}

class HomeNavButton extends StatelessWidget {
  const HomeNavButton({super.key, this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => goToHome(context),
          icon: const Icon(Icons.home_rounded, size: 20),
          label: Text(
            tr('Bosh sahifa'),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.mintSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => goToHome(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                tr('Bosh sahifa'),
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastki qismdagi doimiy «Bosh sahifa» tugmasi.
class BottomHomeBar extends StatelessWidget {
  const BottomHomeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: const HomeNavButton(expanded: true),
      ),
    );
  }
}

class CancelBookingButton extends StatelessWidget {
  const CancelBookingButton({
    super.key,
    required this.onPressed,
    this.label = 'Safarni bekor qilish',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded, size: 18),
        label: Text(tr(label), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: AppColors.destination,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
