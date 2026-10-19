import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/notifications/notifications_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// Haydovchi bosh sahifasida yangi joy band qilinganini ko'rinarli
/// ko'rsatish uchun — shunchaki bildirishnomalar ro'yxatida yashirin
/// qolib ketmasligi uchun.
class BookingAlertBanner extends StatelessWidget {
  const BookingAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final latest = NotificationService.instance.items
            .where((n) => n.type == 'booking' && !n.isRead)
            .firstOrNull;
        if (latest == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                NotificationService.instance.markRead(latest.id);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Center(
                        child: Icon(Icons.event_seat_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Yangi joy band qilindi'),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                          ),
                          Text(
                            latest.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
