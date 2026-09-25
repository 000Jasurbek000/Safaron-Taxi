import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/place_record.dart';
import '../services/place_registry_service.dart';
import '../theme/app_colors.dart';

/// Admin joylari ro‘yxatidan tanlash + «Boshqa manzil».
class PlacePickerField extends StatefulWidget {
  const PlacePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.accent,
    required this.mapOpen,
    required this.onMapTap,
    this.onSelectionChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color accent;
  final bool mapOpen;
  final VoidCallback onMapTap;
  final ValueChanged<PlaceSelection>? onSelectionChanged;

  @override
  State<PlacePickerField> createState() => _PlacePickerFieldState();
}

class _PlacePickerFieldState extends State<PlacePickerField> {
  final _focus = FocusNode();
  List<PlaceRecord> _suggestions = [];
  bool _customMode = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focus.addListener(() {
      if (_focus.hasFocus) _refreshSuggestions();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_customMode) _refreshSuggestions();
    _emitSelection();
  }

  void _refreshSuggestions() {
    setState(() {
      _suggestions = PlaceRegistryService.instance.search(widget.controller.text);
    });
  }

  void _emitSelection() {
    widget.onSelectionChanged?.call(
      PlaceRegistryService.instance.selectionFromText(widget.controller.text),
    );
  }

  void _pick(PlaceRecord place) {
    widget.controller.text = place.name;
    _customMode = false;
    _suggestions = [];
    _focus.unfocus();
    widget.onSelectionChanged?.call(
      PlaceSelection(
        displayName: place.name,
        locationId: place.id,
        latitude: place.latitude,
        longitude: place.longitude,
      ),
    );
    setState(() {});
  }

  void _pickOther() {
    _customMode = true;
    widget.controller.clear();
    _suggestions = [];
    widget.onSelectionChanged?.call(
      const PlaceSelection(displayName: PlaceSelection.otherLabel, isCustom: true),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showList = _focus.hasFocus && !_customMode && (_suggestions.isNotEmpty || widget.controller.text.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    style: GoogleFonts.montserrat(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _customMode ? tr('Manzil nomini yozing') : widget.hint,
                      hintStyle: GoogleFonts.montserrat(
                        color: AppColors.textMuted.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 2, bottom: 2),
                    ),
                    onTap: () {
                      if (!_customMode) _refreshSuggestions();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MapBtn(accent: widget.accent, active: widget.mapOpen, onTap: widget.onMapTap),
          ],
        ),
        if (showList)
          Container(
            margin: const EdgeInsets.only(left: 24, top: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final p in _suggestions)
                  ListTile(
                    dense: true,
                    title: Text(p.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: p.aliases.isEmpty
                        ? null
                        : Text(
                            p.aliases.take(3).join(', '),
                            style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted),
                          ),
                    onTap: () => _pick(p),
                  ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_location_alt_outlined, color: widget.accent, size: 20),
                  title: Text(
                    PlaceSelection.otherLabel,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: widget.accent),
                  ),
                  onTap: _pickOther,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.accent, required this.active, required this.onTap});
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? accent : AppColors.mintSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            active ? Icons.map_rounded : Icons.map_outlined,
            size: 18,
            color: active ? Colors.white : accent,
          ),
        ),
      ),
    );
  }
}
