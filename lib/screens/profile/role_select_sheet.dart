import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';

Future<void> showRoleSelectSheet(BuildContext context) async {
  final profile = ProfileService.instance;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr('Rolni tanlang'),
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            _RoleOption(
              icon: Icons.person_outline_rounded,
              title: "Yo'lovchi",
              subtitle: tr('Taksi buyurtma qiling'),
              selected: profile.role == AppRole.passenger,
              onTap: () async {
                await profile.setRole(AppRole.passenger);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _RoleOption(
              icon: Icons.local_taxi_rounded,
              title: 'Haydovchi',
              subtitle: tr('Safarlarni qabul qiling'),
              selected: profile.role == AppRole.driver,
              onTap: () async {
                await profile.setRole(AppRole.driver);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mintSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(subtitle, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
