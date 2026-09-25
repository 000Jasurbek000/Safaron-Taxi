import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/phrase.dart';
import '../../services/api_client.dart';
import '../../services/app_update_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/safaron_header.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  AppReleaseInfo? _remote;
  bool _loading = true;
  bool _downloading = false;
  double _progress = 0;
  String? _message;

  static const _localVersion = '1.0.2';
  static const _localBuild = 3;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    await ApiClient.instance.ensureConnected();
    final info = await AppUpdateService.instance.fetchInfo();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _remote = info;
      if (info == null) {
        _message = 'Serverdan versiya olinmadi. Avval serverga ulaning.';
      }
    });
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _message = null;
    });
    try {
      final path = await AppUpdateService.instance.downloadApk((received, total) {
        if (!mounted) return;
        setState(() {
          _progress = total == null || total == 0 ? 0 : received / total;
        });
      });
      final result = await AppUpdateService.instance.installApk(path);
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _message = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _message = tr('Yangilab bo‘lmadi. Qayta urinib ko‘ring.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = _remote;
    final hasUpdate = remote != null &&
        AppUpdateService.instance.needsUpdate(remote, _localVersion, _localBuild) &&
        remote.apkAvailable;

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
                    'Ilovani yangilash',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 20),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Telefoningizdagi versiya', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
                  Text('$_localVersion (build $_localBuild)', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text('Serverdagi versiya', style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
                  Text(
                    _loading
                        ? 'Tekshirilmoqda...'
                        : remote == null
                            ? '—'
                            : '${remote.version} (build ${remote.build})',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  if (remote?.apkSizeMb != null) ...[
                    const SizedBox(height: 6),
                    Text('Hajmi: ~${remote!.apkSizeMb} MB', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              color: AppColors.mintSoft,
              child: Text(
                'Telegram kerak emas: kompyuterda APK yangilang → telefondan shu yerda «Yuklab o‘rnatish» bosing. '
                'Telefon va kompyuter bir Wi‑Fi da bo‘lishi shart.',
                style: GoogleFonts.montserrat(fontSize: 12, height: 1.4, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 16),
            if (_downloading) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
              Text(
                _progress > 0 ? '${(_progress * 100).toStringAsFixed(0)}%' : 'Yuklanmoqda...',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
            ] else ...[
              PrimaryPillButton(
                label: hasUpdate ? 'Yangi versiyani yuklab o‘rnatish' : tr('Qayta tekshirish'),
                icon: hasUpdate ? Icons.system_update_alt_rounded : Icons.refresh_rounded,
                enabled: !_loading,
                onTap: hasUpdate ? _downloadAndInstall : _check,
              ),
              if (!hasUpdate && remote != null && remote.apkAvailable) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _downloadAndInstall,
                  child: Text('Baribir qayta o‘rnatish', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: GoogleFonts.montserrat(color: AppColors.textMuted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
