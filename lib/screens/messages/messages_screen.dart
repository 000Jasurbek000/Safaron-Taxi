import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../booking/driver_chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, ProfileService.instance]),
      builder: (context, _) {
        if (!AuthService.instance.registered) {
          return ColoredBox(
            color: AppColors.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.t('messages_title'),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.t('messages_register_hint'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.navy,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        }
        return const _MessagesBody();
      },
    );
  }
}

class _MessagesBody extends StatelessWidget {
  const _MessagesBody();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (context, _) {
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
                  AppStrings.t('messages_title'),
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
                  AppStrings.t('messages_subtitle'),
                  style: GoogleFonts.montserrat(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: ChatService.instance,
                builder: (context, _) {
                  final threads = ChatService.instance.threads;
                  if (threads.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      children: [
                        Image.asset(
                          'assets/images/messages_empty_hero.png',
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('Hali yozishmalar yo‘q'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('Haydovchi bilan Chat ochsangiz, suhbat shu yerda saqlanadi.'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: threads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = threads[index];
                      return Material(
                        color: t.hasUnread ? AppColors.mintSoft : AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            await ChatService.instance.markRead(t.taxiId);
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DriverChatScreen(taxi: t.toTaxi()),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    t.imageAsset,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                  ),
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
                                              t.driverName,
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
                                      const SizedBox(height: 2),
                                      Text(
                                        '${t.carModel} · ${t.plate}',
                                        style: GoogleFonts.montserrat(
                                          color: AppColors.primaryDark,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t.lastPreview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.montserrat(
                                          color: t.hasUnread ? AppColors.navy : AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: t.hasUnread ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (t.hasUnread)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(left: 6),
                                    decoration: const BoxDecoration(color: AppColors.destination, shape: BoxShape.circle),
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
      },
    );
  }
}
