import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../services/api_client.dart';
import '../../services/platform_config_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class ReferralScreen extends RewardsScreen {
  const ReferralScreen({super.key});
}

class BonusScreen extends RewardsScreen {
  const BonusScreen({super.key});
}

class _RewardsScreenState extends State<RewardsScreen> {
  Map<String, dynamic>? _referral;
  Map<String, dynamic>? _bonus;
  List<dynamic> _rules = [];
  List<dynamic> _withdrawals = [];
  String? _error;
  bool _loading = true;
  final _nick = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nick.text = PlatformConfigService.instance.telegramAdmin;
    _load();
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PlatformConfigService.instance.load();
      final results = await Future.wait([
        ApiClient.instance.get('/api/referral/me'),
        ApiClient.instance.get('/api/bonus/me'),
        ApiClient.instance.get('/api/bonus/withdrawals'),
        ApiClient.instance.get('/api/config'),
      ]);
      if (!mounted) return;
      final cfg = results[3] as Map<String, dynamic>;
      setState(() {
        _referral = results[0] as Map<String, dynamic>;
        _bonus = results[1] as Map<String, dynamic>;
        _withdrawals = results[2] as List<dynamic>;
        _rules = (cfg['bonus_rules'] as List?) ?? [];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = AppStrings.t('server_error'); _loading = false; });
    }
  }

  String _money(num? n) {
    final v = (n ?? 0).round();
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} ${AppStrings.t('som')}';
  }

  String _ruleText(Map rule) {
    final key = rule['key']?.toString() ?? '';
    final amount = _money(rule['amount'] as num?);
    final trips = '${rule['required_trips'] ?? 1}';
    final title = rule['title']?.toString() ?? key;
    final template = switch (key) {
      'passenger_first_trip' => AppStrings.t('rule_passenger_first_trip'),
      'passenger_referral' => AppStrings.t('rule_passenger_referral'),
      'driver_referral' => AppStrings.t('rule_driver_referral'),
      'driver_milestone' => AppStrings.t('rule_driver_milestone'),
      _ => AppStrings.t('rule_generic'),
    };
    return template.replaceAll('{amount}', amount).replaceAll('{trips}', trips).replaceAll('{title}', title);
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('copied')), behavior: SnackBarBehavior.floating));
  }

  Future<void> _withdraw() async {
    final available = (_bonus?['available'] as num?)?.toInt() ?? 0;
    if (available <= 0) {
      setState(() => _error = AppStrings.t('no_bonus_to_withdraw'));
      return;
    }
    try {
      final res = await ApiClient.instance.post('/api/bonus/withdraw', body: {
        'telegram_username': _nick.text.trim(),
        'amount': available,
      });
      if (!mounted) return;
      final msg = (res as Map)['message'] as String? ?? AppStrings.t('saved');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _referral?['code'] as String? ?? '';
    final bonusOn = _bonus?['enabled'] != false && PlatformConfigService.instance.bonus;
    final referralOn = _referral?['enabled'] != false && PlatformConfigService.instance.referral;
    final history = (_bonus?['history'] as List?) ?? [];

    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      Row(children: [
                        const AppBackButton(),
                        Expanded(
                          child: Text(AppStrings.t('rewards_title'), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                        ),
                        const SizedBox(width: 40),
                      ]),
                      const SizedBox(height: 6),
                      Text(AppStrings.t('rewards_subtitle'), textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: GoogleFonts.montserrat(color: AppColors.destination, fontWeight: FontWeight.w600)),
                      ],
                      if (referralOn && code.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CodeCard(code: code, onCopy: () => _copy(code), onShare: () => _copy('SAFARON: $code')),
                        const SizedBox(height: 12),
                        Row(children: [
                          _Stat(label: AppStrings.t('invited'), value: '${_referral?['invited'] ?? 0}'),
                          const SizedBox(width: 8),
                          _Stat(label: AppStrings.t('successful'), value: '${_referral?['successful'] ?? 0}'),
                          const SizedBox(width: 8),
                          _Stat(label: AppStrings.t('bonus_earned'), value: _money(_referral?['bonus_earned'] as num?)),
                        ]),
                      ] else if (!referralOn)
                        Padding(padding: const EdgeInsets.only(top: 12), child: Text(AppStrings.t('referral_off'), style: GoogleFonts.montserrat(color: AppColors.textMuted))),
                      const SizedBox(height: 16),
                      Text(AppStrings.t('bonus_rules_title'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Text(AppStrings.t('bonus_rules_note'), style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      for (final raw in _rules)
                        if (raw is Map)
                          _RuleTile(title: raw['title']?.toString() ?? '', amount: _money(raw['amount'] as num?), body: _ruleText(raw)),
                      if (bonusOn) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(AppStrings.t('bonus_balance'), style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_money(_bonus?['available'] as num?), style: GoogleFonts.montserrat(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            Text('${AppStrings.t('bonus_held')}: ${_money(_bonus?['held'] as num?)}', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nick,
                          decoration: InputDecoration(
                            labelText: AppStrings.t('telegram_username'),
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 10),
                        PrimaryPillButton(label: AppStrings.t('withdraw'), icon: Icons.account_balance_wallet_outlined, onTap: _withdraw),
                        const SizedBox(height: 18),
                        Text(AppStrings.t('bonus_history'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy)),
                        if (history.isEmpty) Text('—', style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                        for (final h in history)
                          if (h is Map)
                            _HistoryRow(title: '${_money(h['amount'] as num?)} · ${h['source'] ?? ''}', subtitle: '${h['status'] ?? ''} · ${h['description'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text(AppStrings.t('withdraw_history'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.navy)),
                        if (_withdrawals.isEmpty) Text('—', style: GoogleFonts.montserrat(color: AppColors.textMuted)),
                        for (final w in _withdrawals)
                          if (w is Map)
                            _HistoryRow(title: '${_money(w['amount'] as num?)} · ${w['status'] ?? ''}', subtitle: w['admin_note']?.toString() ?? ''),
                      ] else
                        Padding(padding: const EdgeInsets.only(top: 8), child: Text(AppStrings.t('bonus_off'), style: GoogleFonts.montserrat(color: AppColors.textMuted))),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.onCopy, required this.onShare});
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0E8F5B), Color(0xFF12B56E)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text(code, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _WhiteBtn(label: AppStrings.t('copy_code'), onTap: onCopy)),
          const SizedBox(width: 8),
          Expanded(child: _WhiteBtn(label: AppStrings.t('share'), onTap: onShare)),
        ]),
      ]),
    );
  }
}

class _WhiteBtn extends StatelessWidget {
  const _WhiteBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 13)),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.title, required this.amount, required this.body});
  final String title;
  final String amount;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.card_giftcard_rounded, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy))),
            Text(amount, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryDark)),
          ]),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
        ])),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
        if (subtitle.trim().isNotEmpty) Text(subtitle, style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}
