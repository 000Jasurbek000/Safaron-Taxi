import 'package:flutter/material.dart';
import '../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

List<String> get cancelReasons => <String>[
  tr('Maqsad o‘zgardi'),
  tr('Uzoq kutdim'),
  tr('Boshqa taksi topdim'),
  tr('Narxi mos kelmadi'),
  tr('Haydovchi kechikdi'),
  tr('Noto‘g‘ri manzil tanlangan'),
  tr('Shaxsiy sabab'),
];

Future<String?> showCancelReasonSheet(BuildContext context) async {
  String? selected;
  final otherCtrl = TextEditingController();

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModal) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  const SizedBox(height: 14),
                  Text(
                    tr('Bekor qilish sababi'),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('Nima uchun bekor qilmoqchisiz?'),
                    style: GoogleFonts.montserrat(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final reason in cancelReasons)
                    _ReasonTile(
                      label: reason,
                      selected: selected == reason,
                      onTap: () => setModal(() {
                        selected = reason;
                        otherCtrl.clear();
                      }),
                    ),
                  _ReasonTile(
                    label: 'Boshqa',
                    selected: selected == 'Boshqa',
                    onTap: () => setModal(() => selected = 'Boshqa'),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: selected != 'Boshqa'
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: TextField(
                              controller: otherCtrl,
                              maxLines: 3,
                              maxLength: 200,
                              onChanged: (_) => setModal(() {}),
                              decoration: InputDecoration(
                                hintText: tr('Sababni yozing...'),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Orqaga',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (selected == null) return;
                            if (selected == 'Boshqa') {
                              final text = otherCtrl.text.trim();
                              if (text.isEmpty) return;
                              Navigator.pop(context, text);
                              return;
                            }
                            Navigator.pop(context, selected);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: AppColors.destination,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            tr('Bekor qilish'),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  otherCtrl.dispose();
  return result;
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.selectedFill : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
