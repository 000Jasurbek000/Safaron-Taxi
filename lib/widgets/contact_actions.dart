import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/taxi_offer.dart';
import '../theme/app_colors.dart';
import '../screens/booking/driver_chat_screen.dart';

Future<void> showDriverCallSheet(BuildContext context, TaxiOffer taxi) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
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
            const SizedBox(height: 16),
            Text(
              tr('Haydovchiga qo‘ng‘iroq'),
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              taxi.driverName,
              style: GoogleFonts.montserrat(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                taxi.phone,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.navy,
                      side: BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Bekor',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: taxi.phone);
                      Navigator.pop(context);
                      await launchUrl(uri);
                    },
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: Text(
                      tr('Qo‘ng‘iroq'),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void openDriverChat(BuildContext context, TaxiOffer taxi) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DriverChatScreen(taxi: taxi),
    ),
  );
}

class BookedTaxiCard extends StatelessWidget {
  const BookedTaxiCard({
    super.key,
    required this.taxi,
    this.etaText,
    this.pickupText,
    this.showCallChat = true,
  });

  final TaxiOffer taxi;
  final String? etaText;
  final String? pickupText;
  final bool showCallChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  taxi.imageAsset,
                  width: 84,
                  height: 68,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.35),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taxi.plate,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.navy,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      taxi.driverName,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (etaText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        etaText!,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/images/driver_avatar.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          if (pickupText != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickupText!,
                      style: GoogleFonts.montserrat(
                        color: AppColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showCallChat) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => showDriverCallSheet(context, taxi),
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              tr('Aloqa'),
                              style: GoogleFonts.montserrat(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => openDriverChat(context, taxi),
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Chat',
                              style: GoogleFonts.montserrat(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TaxiInfoRows extends StatelessWidget {
  const TaxiInfoRows({
    super.key,
    required this.taxi,
    required this.seats,
    this.showRoute = true,
    this.showPrice = true,
  });

  final TaxiOffer taxi;
  final int seats;
  final bool showRoute;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(
          icon: Icons.directions_car_rounded,
          label: 'Mashina',
          value: '${taxi.carModel} · ${taxi.plate}',
        ),
        const Divider(height: 1),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefon',
          value: taxi.phone,
        ),
        const Divider(height: 1),
        _InfoRow(
          icon: Icons.person_outline_rounded,
          label: 'Haydovchi',
          value: '${taxi.driverName} · ${taxi.rating}★',
        ),
        if (showRoute) ...[
          const Divider(height: 1),
          _InfoRow(
            icon: Icons.route_rounded,
            label: 'Marshrut',
            value: '${_short(taxi.from)} → ${_short(taxi.to)}',
          ),
        ],
        const Divider(height: 1),
        _InfoRow(
          icon: Icons.schedule_rounded,
          label: 'Vaqt',
          value: taxi.time,
        ),
        const Divider(height: 1),
        _InfoRow(
          icon: Icons.event_seat_outlined,
          label: 'Joylar',
          value: '$seats ta joy',
        ),
        if (showPrice) ...[
          const Divider(height: 1),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Narx',
            value: taxi.priceLabel,
            valueColor: AppColors.primary,
          ),
        ],
      ],
    );
  }

  String _short(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length <= 2) return value;
    return parts.take(2).join(' ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.mintSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                color: valueColor ?? AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
