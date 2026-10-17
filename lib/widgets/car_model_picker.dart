import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/phrase.dart';
import '../services/platform_config_service.dart';
import '../theme/app_colors.dart';

const kOtherCarModel = 'Boshqa';

class CarModelPicker extends StatelessWidget {
  const CarModelPicker({
    super.key,
    required this.value,
    required this.customController,
    required this.onChanged,
  });

  final String value;
  final TextEditingController customController;
  final ValueChanged<String> onChanged;

  static List<String> models() {
    final fromApi = PlatformConfigService.instance.vehicleModels;
    final base = fromApi.isNotEmpty
        ? fromApi
        : const [
            'Chevrolet Cobalt',
            'Chevrolet Nexia',
            'Chevrolet Spark',
            'Chevrolet Tracker',
            'BYD Chazor',
            'Chevrolet Lacetti',
          ];
    return [...base, kOtherCarModel];
  }

  static String resolve(String selected, String custom) {
    if (selected == kOtherCarModel) {
      final t = custom.trim();
      return t.isEmpty ? kOtherCarModel : t;
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final items = models();
    final selected = items.contains(value) ? value : kOtherCarModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              items: [
                for (final c in items)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppColors.navy)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
        if (selected == kOtherCarModel) ...[
          const SizedBox(height: 8),
          TextField(
            controller: customController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: tr('Moshina modelini yozing'),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.cardBorder)),
            ),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
