import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/phrase.dart';
import '../../../services/app_navigation.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../home/main_shell.dart';

/// Ariza yuborilgandan keyin — admin tasdiqini kutish + yangilash.
class DriverApplicationSentScreen extends StatefulWidget {
  const DriverApplicationSentScreen({super.key});

  @override
  State<DriverApplicationSentScreen> createState() => _DriverApplicationSentScreenState();
}

class _DriverApplicationSentScreenState extends State<DriverApplicationSentScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await AuthService.instance.refreshMe();
      await ProfileService.instance.syncFromAuth();
      if (!mounted) return;
      if (ProfileService.instance.isApprovedDriver) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Tabriklaymiz! Haydovchi sifatida tasdiqlandingiz.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        AppNavigation.goHome();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      } else if (ProfileService.instance.driverStatus == DriverStatus.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Hali ko‘rib chiqilmoqda')), behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Ariza holati yangilandi')), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Yangilab bo‘lmadi. Qayta urinib ko‘ring.')), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ProfileService.instance.driverStatus;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  status == DriverStatus.approved ? Icons.check_rounded : Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                status == DriverStatus.approved ? 'Tasdiqlandingiz!' : tr('Arizangiz qabul qilindi!'),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.navy),
              ),
              const SizedBox(height: 10),
              Text(
                status == DriverStatus.approved
                    ? tr('Endi haydovchi rejimiga o‘tishingiz mumkin.')
                    : tr('Arizangiz admin tomonidan tekshirilmoqda.\n«Yangilash» tugmasini bosib holatni tekshiring.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                label: Text('Yangilash', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    AppNavigation.goHome();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(tr('Bosh sahifaga'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
