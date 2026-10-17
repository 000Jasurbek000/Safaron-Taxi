import 'package:flutter/material.dart';
import '../../l10n/phrase.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_client.dart';
import '../../services/server_discovery.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_header.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _host;
  bool _busy = false;
  String? _status;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    await ApiClient.instance.load();
    _host.text = ApiClient.instance.baseUrl;
    await _test(silent: true);
  }

  String _normalizeUrl(String raw) {
    var host = raw.trim();
    if (host.isEmpty) return ApiClient.defaultHost;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host.replaceAll(RegExp(r'/$'), '');
    }
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
      return 'http://$host:8000';
    }
    return 'https://$host';
  }

  Future<void> _useProduction() async {
    _host.text = ApiClient.defaultHost;
    await _save();
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _test({bool silent = false}) async {
    setState(() {
      _busy = true;
      if (!silent) _status = null;
    });
    final url = _normalizeUrl(_host.text);
    final ok = await ServerDiscovery.ping(url);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _connected = ok;
      _status = ok ? tr('Ulandi ✓') : tr('Ulanmadi — manzilni tekshiring');
    });
  }

  Future<void> _save() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;
    final url = _normalizeUrl(host);
    await ApiClient.instance.setBaseUrl(url);
    await _test();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Server manzili saqlandi')), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _autoFind() async {
    setState(() {
      _busy = true;
      _status = tr('Qidirilmoqda... (10–20 soniya)');
    });
    final found = await ServerDiscovery.discover();
    if (!mounted) return;
    if (found == null) {
      setState(() {
        _busy = false;
        _connected = false;
        _status = tr('Topilmadi. Kompyuter va telefon bir Wi‑Fi da bo‘lsin, backend ishlayaptimi?');
      });
      return;
    }
    await ApiClient.instance.setBaseUrl(found);
    _host.text = found;
    setState(() {
      _busy = false;
      _connected = true;
      _status = tr('Topildi va saqlandi ✓');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                const AppBackButton(),
                Expanded(
                  child: Text(
                    tr('Server sozlamalari'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 16),
            SoftCard(
              color: AppColors.mintSoft,
              child: Text(
                tr('Odatiy server: https://safaron.uz. Lokal test uchun IP yoki «Avtomatik topish» ishlating.'),
                style: GoogleFonts.montserrat(fontSize: 12, height: 1.4, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 16),
            SoftField(
              controller: _host,
              hint: 'https://safaron.uz',
              icon: Icons.dns_outlined,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Text(
              tr('Hozir: {url}').replaceAll('{url}', ApiClient.instance.baseUrl),
              style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textMuted),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(
                _status!,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: _connected ? AppColors.primaryDark : Colors.orange.shade800,
                ),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryPillButton(
              label: _busy ? tr('Kutilmoqda...') : tr('Avtomatik topish'),
              icon: Icons.radar_rounded,
              enabled: !_busy,
              onTap: _autoFind,
            ),
            const SizedBox(height: 10),
            PrimaryPillButton(
              label: tr('Saqlash va tekshirish'),
              icon: Icons.save_outlined,
              enabled: !_busy,
              onTap: _save,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : () => _test(),
              child: Text(tr('Ulanishni tekshirish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _useProduction,
              child: Text(tr('safaron.uz ga qaytish'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
