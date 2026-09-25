import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/driver/driver_messages_screen.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';

/// Haydovchi uchun xabar bildirishnomasi (yuqori qism).
class DriverInboxBanner extends StatelessWidget {
  const DriverInboxBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChatService.instance,
      builder: (context, _) {
        final unread = ChatService.instance.threads.fold<int>(
          0,
          (sum, t) => sum + t.unreadCountForDriver,
        );
        if (unread <= 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DriverMessagesScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppColors.destination, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Yangi xabar'),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                          ),
                          Text(
                            '$unread ta o‘qilmagan xabar',
                            style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.destination),
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
