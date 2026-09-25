import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

/// Bir Wi‑Fi tarmog‘ida SAFARON backendni avtomatik topish.
class ServerDiscovery {
  ServerDiscovery._();

  static const _port = 8000;
  static const _healthPath = '/health';

  /// Telefon va kompyuter bir subnetda bo‘lsa serverni qidiradi.
  static Future<String?> discover({Duration hostTimeout = const Duration(milliseconds: 700)}) async {
    final candidates = await _candidateIps();
    for (var i = 0; i < candidates.length; i += 24) {
      final batch = candidates.skip(i).take(24);
      final results = await Future.wait(batch.map((ip) => _probe(ip, hostTimeout)));
      for (final url in results) {
        if (url != null) return url;
      }
    }
    return null;
  }

  static Future<List<String>> _candidateIps() async {
    final ips = <String>[];
    final seen = <String>{};

    void addIp(String ip) {
      if (seen.add(ip)) ips.add(ip);
    }

    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.contains('.')) {
        final parts = wifiIp.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          // Odatda router .1, kompyuter oxirgi oktetlar
          for (var i = 1; i <= 254; i++) {
            addIp('$subnet.$i');
          }
        }
      }
    } catch (_) {}

    return ips;
  }

  static Future<String?> _probe(String ip, Duration timeout) async {
    final url = 'http://$ip:$_port';
    try {
      final res = await http.get(Uri.parse('$url$_healthPath')).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = res.body;
      if (body.contains('SAFARON') || body.contains('"ok":true')) {
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          if (json['ok'] == true) return url;
        } catch (_) {
          return url;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> ping(String baseUrl) async {
    try {
      final url = baseUrl.replaceAll(RegExp(r'/$'), '');
      final res = await http.get(Uri.parse('$url$_healthPath')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
