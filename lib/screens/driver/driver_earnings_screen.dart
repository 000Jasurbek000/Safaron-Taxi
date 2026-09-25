import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/trip_completion_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/money.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_header.dart';

class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TripCompletionService.instance,
          builder: (context, _) {
            final summary = TripCompletionService.instance.earningsSummary;
            final now = DateTime.now();
            final weekStart = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: now.weekday - 1));
            final monthStart = DateTime(now.year, now.month, 1);
            final weekRecords = TripCompletionService.instance.recordsSince(weekStart);
            final monthRecords = TripCompletionService.instance.recordsSince(monthStart);
            final allRecords = TripCompletionService.instance.records;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daromadlarim',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SoftCard(
                  color: AppColors.mintSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Jami daromad'),
                        style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                      ),
                      Text(
                        formatSom(summary.total),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        '${summary.tripCount} ta tugallangan safar',
                        style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatCard(label: tr('Bugun'), value: formatSom(summary.today))),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(label: 'Hafta', value: formatSom(summary.week))),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(label: 'Oy', value: formatSom(summary.month))),
                  ],
                ),
                const SizedBox(height: 20),
                Text(tr('Haftalik batafsil'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (weekRecords.isEmpty)
                  SoftCard(
                    child: Text(tr('Bu hafta tugallangan safar yo‘q'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                  )
                else
                  ...weekRecords.map((r) => _TripEarningTile(record: r)),
                const SizedBox(height: 20),
                Text(tr('Oylik batafsil'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (monthRecords.isEmpty)
                  SoftCard(
                    child: Text(tr('Bu oy tugallangan safar yo‘q'), style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                  )
                else
                  ...monthRecords.map((r) => _TripEarningTile(record: r)),
                if (allRecords.length > monthRecords.length) ...[
                  const SizedBox(height: 20),
                  Text(tr('Barcha safarlar'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...allRecords.map((r) => _TripEarningTile(record: r)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _TripEarningTile extends StatelessWidget {
  const _TripEarningTile({required this.record});

  final CompletedTripRecord record;

  @override
  Widget build(BuildContext context) {
    final d = record.completedAt;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.routeLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(dateLabel, style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
                  Text(record.passengerName, style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.primaryDark)),
                ],
              ),
            ),
            Text(
              formatSom(record.price),
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
