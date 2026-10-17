import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.refresh(full: true);
  }

  String _when(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([AuthService.instance, NotificationService.instance]),
          builder: (context, _) {
            final svc = NotificationService.instance;
            final registered = AuthService.instance.registered;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.t('notifications_title'),
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      if (registered && svc.hasUnread)
                        TextButton(
                          onPressed: svc.markAllRead,
                          child: Text(
                            AppStrings.t('notifications_read_all'),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: !registered
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              AppStrings.t('notifications_register_hint'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => svc.refresh(full: true),
                          child: svc.loading && svc.items.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : svc.items.isEmpty
                                  ? ListView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        const SizedBox(height: 80),
                                        Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.primary),
                                        const SizedBox(height: 14),
                                        Text(
                                          AppStrings.t('notifications_empty'),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.separated(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                      itemCount: svc.items.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                                      itemBuilder: (context, i) {
                                        final n = svc.items[i];
                                        return Material(
                                          color: n.isRead ? AppColors.surface : AppColors.mintSoft,
                                          borderRadius: BorderRadius.circular(16),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: n.isRead ? null : () => svc.markRead(n.id),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.notifications_rounded,
                                                    color: n.isRead ? AppColors.textMuted : AppColors.primary,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                n.title,
                                                                style: GoogleFonts.montserrat(
                                                                  fontWeight: FontWeight.w800,
                                                                  fontSize: 14,
                                                                  color: AppColors.navy,
                                                                ),
                                                              ),
                                                            ),
                                                            if (_when(n.createdAt).isNotEmpty)
                                                              Text(
                                                                _when(n.createdAt),
                                                                style: GoogleFonts.montserrat(
                                                                  fontSize: 11,
                                                                  color: AppColors.textMuted,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          n.body,
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w500,
                                                            color: AppColors.textMuted,
                                                            height: 1.35,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
