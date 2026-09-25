import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.build,
    required this.apkAvailable,
    this.apkSizeMb,
  });

  final String version;
  final int build;
  final bool apkAvailable;
  final double? apkSizeMb;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> j) => AppReleaseInfo(
        version: j['version']?.toString() ?? '0.0.0',
        build: j['build'] as int? ?? 0,
        apkAvailable: j['apk_available'] == true,
        apkSizeMb: (j['apk_size_mb'] as num?)?.toDouble(),
      );
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  Future<AppReleaseInfo?> fetchInfo() async {
    try {
      final data = await ApiClient.instance.get('/api/app/info');
      if (data is! Map<String, dynamic>) return null;
      return AppReleaseInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  bool needsUpdate(AppReleaseInfo remote, String localVersion, int localBuild) {
    if (remote.build > localBuild) return true;
    return remote.version != localVersion;
  }

  Future<String> downloadApk(void Function(int received, int? total) onProgress) async {
    await ApiClient.instance.load();
    final streamed = await ApiClient.instance.getStream('/api/app/apk');
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException('Yangilanishni yuklab bo‘lmadi. Qayta urinib ko‘ring.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SAFARON_update.apk');
    final sink = file.openWrite();
    var received = 0;
    final total = streamed.contentLength;

    await for (final chunk in streamed.stream) {
      received += chunk.length;
      sink.add(chunk);
      onProgress(received, (total != null && total > 0) ? total : null);
    }
    await sink.close();
    return file.path;
  }

  Future<OpenResult> installApk(String path) async {
    if (!Platform.isAndroid) {
      throw ApiException('Faqat Android qurilmada o‘rnatish mumkin.');
    }
    return OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }
}
