import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../booking/driver_chat_screen.dart';

class DriverMessagesScreen extends StatelessWidget {
  const DriverMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Xabarlar',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('Yo‘lovchilar bilan yozishmalar'),
                  style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: ChatService.instance,
                builder: (context, _) {
                  final threads = [...ChatService.instance.threads]
                    ..sort((a, b) {
                      if (a.hasUnreadForDriver == b.hasUnreadForDriver) {
                        return b.updatedAt.compareTo(a.updatedAt);
                      }
                      return a.hasUnreadForDriver ? -1 : 1;
                    });
                  final unreadTotal = threads.fold<int>(0, (s, t) => s + t.unreadCountForDriver);
                  if (threads.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr('Hali yo‘lovchi xabarlari yo‘q'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: threads.length + (unreadTotal > 0 ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (unreadTotal > 0 && index == 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(color: AppColors.destination, shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    '$unreadTotal',
                                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '$unreadTotal ta o‘qilmagan xabar',
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final threadIndex = unreadTotal > 0 ? index - 1 : index;
                      final t = threads[threadIndex];
                      return Material(
                        color: t.hasUnreadForDriver ? AppColors.mintSoft : AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            await ChatService.instance.markReadForDriver(t.taxiId);
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DriverChatScreen(
                                  taxi: t.toTaxi(),
                                  asDriver: true,
                                  peerName: t.passengerName,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.mintSoft,
                                  child: Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.passengerName,
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: AppColors.navy,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            t.timeLabel,
                                            style: GoogleFonts.montserrat(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t.lastPreview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.montserrat(
                                          color: t.hasUnreadForDriver ? AppColors.navy : AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: t.hasUnreadForDriver ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (t.hasUnreadForDriver)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(left: 6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.destination,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
