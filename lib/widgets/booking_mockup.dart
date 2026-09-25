import 'dart:math' as math;
import '../l10n/phrase.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/taxi_offer.dart';
import '../theme/app_colors.dart';
import 'contact_actions.dart';
import 'nav_actions.dart';
import 'safaron_header.dart';

/// Confetti bilan yashil check — bounce animatsiya.
class SuccessCheckHero extends StatefulWidget {
  const SuccessCheckHero({
    super.key,
    this.title,
    this.subtitle,
    this.size = 72,
  });

  final String? title;
  final String? subtitle;
  final double size;

  @override
  State<SuccessCheckHero> createState() => _SuccessCheckHeroState();
}

class _SuccessCheckHeroState extends State<SuccessCheckHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    return Column(
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ...List.generate(12, (i) {
                  final a = (i / 12) * math.pi * 2;
                  final r = 38 + 8 * math.sin(_c.value * math.pi * 2 + i);
                  final colors = [
                    AppColors.primary,
                    const Color(0xFFF5B301),
                    AppColors.primaryLight,
                    const Color(0xFFFF8A65),
                  ];
                  return Positioned(
                    left: widget.size / 2 + math.cos(a) * r * _c.value - 3,
                    top: widget.size / 2 + math.sin(a) * r * _c.value - 3,
                    child: Opacity(
                      opacity: (1 - _c.value * 0.3).clamp(0.4, 1),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
                ScaleTransition(
                  scale: scale,
                  child: child,
                ),
              ],
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: Colors.white, size: widget.size * 0.5),
          ),
        ),
        if (widget.title != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.title!,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: AppColors.navy,
            ),
          ),
        ],
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class HelpPill extends StatelessWidget {
  const HelpPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Yordam: +998 91 449 02 19')), behavior: SnackBarBehavior.floating),
              );
            },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.headset_mic_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Yordam',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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

class MessagesPill extends StatelessWidget {
  const MessagesPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mintSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Xabarlar',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.destination, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haydovchi + mashina kartasi (mockupdagi).
class DriverVehicleCard extends StatelessWidget {
  const DriverVehicleCard({
    super.key,
    required this.taxi,
    this.showTelegram = true,
    this.experienceLabel = '3 yillik tajriba',
  });

  final TaxiOffer taxi;
  final bool showTelegram;
  final String experienceLabel;

  Future<void> _openTelegram(BuildContext context) async {
    final uri = Uri.parse('https://t.me/share/url?url=&text=SAFARON');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Telegram ochilmadi')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/driver_avatar.png',
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        left: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Online',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taxi.driverName,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5B301)),
                        Text(
                          ' ${taxi.rating} (${taxi.reviews} ta baho)',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      tr(experienceLabel),
                      style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      taxi.phone,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      taxi.imageAsset,
                      width: 96,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    taxi.carModel,
                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.mintSoft,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      taxi.plate,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ContactPill(
                  icon: Icons.phone_rounded,
                  label: tr('Aloqa'),
                  onTap: () => showDriverCallSheet(context, taxi),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ContactPill(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  onTap: () => openDriverChat(context, taxi),
                ),
              ),
              if (showTelegram) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ContactPill(
                    icon: Icons.send_rounded,
                    label: tr('Telegram'),
                    onTap: () => _openTelegram(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactPill extends StatelessWidget {
  const _ContactPill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mintSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniRouteMap extends StatelessWidget {
  const MiniRouteMap({
    super.key,
    this.height = 120,
    this.fromLabel = 'Qizil qala',
    this.fromSub = '',
    this.toLabel = 'Beruniy',
    this.toSub = '',
  });

  final double height;
  final String fromLabel;
  final String fromSub;
  final String toLabel;
  final String toSub;

  static const _from = LatLng(41.6911, 60.7525);
  static const _to = LatLng(41.6985, 60.7602);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(41.6945, 60.756),
                initialZoom: 13.2,
                interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safaron.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: const [_from, _to], color: AppColors.primary, strokeWidth: 4),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _from,
                      width: 120,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: _PinLabel(color: AppColors.primary, title: tr(fromLabel), sub: fromSub),
                    ),
                    Marker(
                      point: _to,
                      width: 120,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: _PinLabel(color: AppColors.destination, title: toLabel, sub: toSub),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.my_location_rounded, size: 18, color: AppColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinLabel extends StatelessWidget {
  const _PinLabel({required this.color, required this.title, required this.sub});
  final Color color;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, color: color, size: 26),
        Text(
          title,
          style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        if (sub.isNotEmpty)
          Text(sub, style: GoogleFonts.montserrat(fontSize: 8, color: AppColors.textMuted)),
      ],
    );
  }
}

class TripMetaRow extends StatelessWidget {
  const TripMetaRow({
    super.key,
    required this.dateTime,
    required this.passengers,
    required this.luggage,
  });

  final String dateTime;
  final String passengers;
  final String luggage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Meta(Icons.calendar_month_outlined, dateTime)),
        Expanded(child: _Meta(Icons.person_outline_rounded, passengers)),
        Expanded(child: _Meta(Icons.shopping_bag_outlined, luggage)),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class PricePaymentRow extends StatelessWidget {
  const PricePaymentRow({super.key, required this.price});
  final String price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Kelishilgan narx'), style: GoogleFonts.montserrat(fontSize: 10, color: AppColors.textMuted)),
                    Text(price, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("To'lov turi", style: GoogleFonts.montserrat(fontSize: 9, color: AppColors.textMuted)),
                  Text("Naqd / Yo'lda", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.mintSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(fontSize: 12, height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class TripTimelineBar extends StatelessWidget {
  const TripTimelineBar({
    super.key,
    required this.steps,
    required this.activeIndex,
  });

  final List<({String label, String time, IconData icon})> steps;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 28),
                  color: i <= activeIndex ? AppColors.primary : const Color(0xFFD8E5DC),
                ),
              ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: i <= activeIndex ? AppColors.primary : AppColors.mintSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i < activeIndex ? Icons.check_rounded : steps[i].icon,
                      size: 14,
                      color: i <= activeIndex ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i].label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    steps[i].time,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontSize: 8, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, this.child});
  final Widget? child;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 70 + (i + 1) * 28 * (0.35 + _c.value * 0.65),
                  height: 70 + (i + 1) * 28 * (0.35 + _c.value * 0.65),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(
                      alpha: ((0.2 - i * 0.05) * (1 - _c.value)).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: widget.child ??
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 36),
          ),
    );
  }
}

class SafaronBookingHeader extends StatelessWidget {
  const SafaronBookingHeader({
    super.key,
    this.onBack,
    this.trailing,
  });

  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafaronHeader(
      onBack: onBack ?? () => goToHome(context),
      trailing: trailing ?? const HelpPill(),
    );
  }
}
