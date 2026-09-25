import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_header.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _profile = ProfileService.instance;

  static const _langs = [
    ('uz', "O'zbekcha (Lotin)"),
    ('uz_cyrl', 'Ўзбекча (Кирилл)'),
    ('ru', 'Русский'),
    ('kk', 'Қазақша'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _profile,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            Row(
              children: [
                const AppBackButton(),
                Expanded(
                  child: Text(
                    AppStrings.t('language_settings'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _langs.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppColors.cardBorder),
                      _LangTile(
                        label: _langs[i].$2,
                        selected: _profile.languageUiCode == _langs[i].$1,
                        onTap: () async {
                          final ui = _langs[i].$1;
                          await _profile.setLanguageUi(ui);
                          final api = switch (ui) {
                            'uz_cyrl' => 'uz',
                            _ => ui,
                          };
                          await _profile.setLanguage(api);
                          setState(() {});
                        },
                      ),
                    ],
                  ],
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

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.language_rounded, color: selected ? AppColors.primary : AppColors.textMuted),
      title: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.navy)),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? AppColors.primary : AppColors.textMuted,
      ),
    );
  }
}
