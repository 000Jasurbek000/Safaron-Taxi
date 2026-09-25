import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_strings.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../widgets/safaron_logo.dart';
import 'home/main_shell.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = 'uz';

  static const _langs = [
    ('uz', '🇺🇿', "O‘zbekcha (Lotin)"),
    ('uz_cyrl', '🇺🇿', 'Ўзбекча (Кирилл)'),
    ('ru', '🇷🇺', 'Русский'),
    ('kk', '🇰🇿', 'Қазақша'),
  ];

  Future<void> _continue() async {
    final code = switch (_selected) {
      'uz_cyrl' => 'uz',
      'kk' => 'kk',
      _ => _selected,
    };
    await ProfileService.instance.setLanguage(code);
    await ProfileService.instance.setLanguageUi(_selected);
    await ThemeService.instance.setOnboarded();
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _selected = ProfileService.instance.languageUiCode;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (context, _) {
    final size = MediaQuery.sizeOf(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, size.height * 0.02, 24, 0),
          child: Column(
            children: [
              SafaronLogo(size: size.height * 0.18, borderRadius: 24),
              const SizedBox(height: 12),
              Text(
                AppStrings.t('language_pick_title'),
                style: GoogleFonts.montserrat(color: AppColors.navy, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t('language_pick_subtitle'),
                style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ..._langs.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LanguageTile(
                      flag: e.$2,
                      label: e.$3,
                      selected: _selected == e.$1,
                      onTap: () => setState(() => _selected = e.$1),
                    ),
                  )),
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: bottomPad + 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(AppStrings.t('continue_btn'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.flag, required this.label, required this.selected, required this.onTap});
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.selectedFill : AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: GoogleFonts.montserrat(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Icon(Icons.chevron_right_rounded, color: selected ? AppColors.primary : AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
