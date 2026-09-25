import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/place_record.dart';
import '../../services/place_registry_service.dart';
import '../../theme/app_colors.dart';

class InlineMapPanel extends StatefulWidget {
  const InlineMapPanel({
    super.key,
    required this.accent,
    required this.onConfirm,
    required this.onClose,
  });

  final Color accent;
  final ValueChanged<MapPickResult> onConfirm;
  final VoidCallback onClose;

  @override
  State<InlineMapPanel> createState() => _InlineMapPanelState();
}

class _InlineMapPanelState extends State<InlineMapPanel> {
  static const _beruniy = LatLng(41.6911, 60.7525);

  final _mapController = MapController();
  LatLng _pin = _beruniy;
  LatLng? _myLocation;
  bool _locating = false;
  String? _status;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    setState(() {
      _locating = true;
      _status = null;
    });

    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        setState(() => _status = tr('Joylashuv xizmati o‘chirilgan'));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _status = tr('Joylashuvga ruxsat berilmadi'));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = point;
        _pin = point;
        _status = tr('Joylashuvingiz aniqlandi');
      });
      _mapController.move(point, 16);
    } catch (_) {
      setState(() => _status = tr('Joylashuvni aniqlab bo‘lmadi'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  MapPickResult _resolvePick() {
    return PlaceRegistryService.instance.resolveMapPick(_pin.latitude, _pin.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _beruniy,
                    initialZoom: 14,
                    minZoom: 5,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (tapPosition, point) {
                      setState(() {
                        _pin = point;
                        _status = null;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safaron.app',
                      maxNativeZoom: 19,
                    ),
                    if (_myLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _myLocation!,
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.blueAccent, width: 2.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pin,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: widget.accent,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _MapIconButton(
                    icon: Icons.close_rounded,
                    onTap: widget.onClose,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SoftPillButton(
                icon: _locating ? null : Icons.my_location_rounded,
                label: _locating ? 'Aniqlanmoqda...' : 'Joylashuvim',
                loading: _locating,
                filled: false,
                onTap: _locating ? null : _locateMe,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SoftPillButton(
                icon: Icons.check_rounded,
                label: 'Tanlash',
                filled: true,
                onTap: () => widget.onConfirm(_resolvePick()),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _status == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: AppColors.navy.withValues(alpha: 0.15),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.navy),
        ),
      ),
    );
  }
}

class _SoftPillButton extends StatelessWidget {
  const _SoftPillButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
    this.loading = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : AppColors.mintSoft,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: 18,
                  color: filled ? AppColors.white : AppColors.primary,
                ),
              if (icon != null || loading) const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: filled ? AppColors.white : AppColors.primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
