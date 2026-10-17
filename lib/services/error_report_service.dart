import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

/// Ilovada tutilmagan xatolarni backendga yuboradi — tashqi monitoring
/// xizmati (Sentry va h.k.) ulanmagan bo‘lsa ham xatolar yo‘qolib ketmasin.
class ErrorReportService {
  ErrorReportService._();

  static String? _version;

  static Future<void> report(Object error, StackTrace? stack, {String? path}) async {
    try {
      _version ??= (await PackageInfo.fromPlatform()).version;
      await ApiClient.instance.post('/api/client-error', body: {
        'message': error.toString(),
        if (stack != null) 'detail': stack.toString(),
        if (path != null) 'path': path,
        'app_version': _version,
      });
    } catch (_) {
      // Xato haqida xabar berishning o‘zi ilovani buzmasin.
    }
  }
}
