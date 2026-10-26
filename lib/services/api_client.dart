import 'dart:async';

import 'dart:convert';

import 'dart:io';



import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:shared_preferences/shared_preferences.dart';



import 'server_discovery.dart';



class ApiException implements Exception {

  ApiException(this.message, {this.statusCode});

  final String message;

  final int? statusCode;



  @override

  String toString() => message;

}



/// SAFARON REST client.

class ApiClient extends ChangeNotifier {

  ApiClient._();

  static final ApiClient instance = ApiClient._();



  static const _kToken = 'safaron_api_token';

  static const _kBase = 'safaron_api_base';



  /// Production API. Lokal testda Profil → Server sozlamalaridan o‘zgartiriladi.
  static const String defaultHost = 'https://safaron.uz';



  String? token;

  String baseUrl = defaultHost;

  bool _loaded = false;

  bool _discovering = false;



  Future<void> load() async {

    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString(_kToken);

    final saved = prefs.getString(_kBase);

    if (saved != null && saved.isNotEmpty && !_isLegacyLanUrl(saved)) {
      baseUrl = saved;
    } else {
      baseUrl = defaultHost;
    }

    _loaded = true;

  }



  Future<void> reload() async {

    _loaded = false;

    await load();

    notifyListeners();

  }



  static bool _isLegacyLanUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('127.0.0.1') ||
        u.contains('localhost') ||
        u.contains('10.0.2.2') ||
        u.contains('10.65.224.88') ||
        RegExp(r'https?://(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)').hasMatch(u);
  }

  /// Production ishlamasa, faqat saqlangan LAN manzil bo‘lsa qidiradi.

  Future<bool> ensureConnected({bool autoDiscover = true}) async {

    await load();

    if (await ServerDiscovery.ping(baseUrl)) return true;

    if (!autoDiscover || _discovering || !_isLegacyLanUrl(baseUrl)) return false;



    _discovering = true;

    try {

      final found = await ServerDiscovery.discover();

      if (found != null) {

        await setBaseUrl(found);

        return true;

      }

    } finally {

      _discovering = false;

    }

    return false;

  }



  Future<void> setToken(String? value) async {

    token = value;

    final prefs = await SharedPreferences.getInstance();

    if (value == null || value.isEmpty) {

      await prefs.remove(_kToken);

    } else {

      await prefs.setString(_kToken, value);

    }

  }



  Future<void> setBaseUrl(String url) async {

    baseUrl = url.replaceAll(RegExp(r'/$'), '');

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kBase, baseUrl);

    notifyListeners();

  }



  /// Relativ yo‘lni to‘liq media URL ga aylantiradi (`/uploads/...`).
  String mediaUrl(String? path) {
    final raw = (path ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$baseUrl$raw';
    return '$baseUrl/uploads/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Uri _uri(String path, [Map<String, String>? query]) {

    final p = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$baseUrl$p').replace(queryParameters: query);

  }



  Map<String, String> _headers({bool json = true}) {

    final h = <String, String>{};

    if (json) h['Content-Type'] = 'application/json';

    if (token != null && token!.isNotEmpty) {

      h['Authorization'] = 'Bearer $token';

    }

    return h;

  }



  Future<dynamic> get(String path, {Map<String, String>? query}) async {

    await load();

    try {

      final res = await http.get(_uri(path, query), headers: _headers()).timeout(const Duration(seconds: 20));

      return _decode(res);

    } on TimeoutException {

      throw ApiException('Ulanish vaqti tugadi. Qayta urinib ko‘ring.');

    } on http.ClientException {

      throw ApiException(

        'Serverga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',

      );

    }

  }



  Future<dynamic> post(String path, {Object? body}) async {

    await load();

    try {

      final res = await http

          .post(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body))

          .timeout(const Duration(seconds: 25));

      return _decode(res);

    } on TimeoutException {

      throw ApiException('Ulanish vaqti tugadi. Qayta urinib ko‘ring.');

    } on http.ClientException {

      throw ApiException(

        'Serverga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',

      );

    }

  }



  Future<dynamic> patch(String path, {Object? body}) async {

    await load();

    try {

      final res = await http

          .patch(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body))

          .timeout(const Duration(seconds: 20));

      return _decode(res);

    } on TimeoutException {

      throw ApiException('Ulanish vaqti tugadi. Qayta urinib ko‘ring.');

    } on http.ClientException {

      throw ApiException(

        'Serverga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',

      );

    }

  }



  Future<http.StreamedResponse> getStream(String path) async {

    await load();

    final req = http.Request('GET', _uri(path));

    if (token != null && token!.isNotEmpty) {

      req.headers['Authorization'] = 'Bearer $token';

    }

    final client = http.Client();

    return client.send(req).timeout(const Duration(minutes: 5));

  }



  Future<dynamic> postMultipart(

    String path, {

    required Map<String, String> fields,

    required Map<String, String> files,

  }) async {

    await load();

    try {

      final req = http.MultipartRequest('POST', _uri(path));

      if (token != null && token!.isNotEmpty) {

        req.headers['Authorization'] = 'Bearer $token';

      }

      req.fields.addAll(fields);

      for (final e in files.entries) {
        final x = XFile(e.value);
        final bytes = await x.readAsBytes();
        var name = x.name.trim().isEmpty ? '${e.key}.jpg' : x.name.trim();
        final lower = name.toLowerCase();
        if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png') && !lower.endsWith('.webp')) {
          name = '$name.jpg';
        }
        req.files.add(http.MultipartFile.fromBytes(
          e.key,
          bytes,
          filename: name,
          contentType: MediaType('image', lower.endsWith('.png') ? 'png' : lower.endsWith('.webp') ? 'webp' : 'jpeg'),
        ));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 60));

      final res = await http.Response.fromStream(streamed);

      return _decode(res);

    } on FileSystemException {

      throw ApiException('Fayl topilmadi yoki o‘qib bo‘lmadi.');

    } on TimeoutException {

      throw ApiException('Ulanish vaqti tugadi. Qayta urinib ko‘ring.');

    } on http.ClientException {

      throw ApiException(

        'Serverga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',

      );

    }

  }



  dynamic _decode(http.Response res) {

    dynamic data;

    try {

      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));

    } catch (_) {

      data = null;

    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final detail = data is Map ? (data['detail']?.toString() ?? 'Xatolik') : 'Xatolik';

    if (res.statusCode == 401) {

      // Agar joriy token internetga ulanib bo'lmagan paytda yaratilgan
      // mahalliy-soxta "oflayn" hisobga tegishli bo'lsa (haqiqiy JWT emas),
      // "sessiya tugadi" xabari chalg'ituvchi — foydalanuvchi aslida hech
      // qachon haqiqiy hisobga kirmagan edi. Buni aniq tushuntiramiz.
      if (token != null && token!.startsWith('offline_')) {
        throw ApiException(
          'Ro‘yxatdan o‘tishda internet aloqasi yo‘q edi, shuning uchun hisobingiz vaqtincha mahalliy (oflayn) rejimda yaratilgan. Bu amal uchun internetga ulanib, ilovadan chiqib qaytadan kiring.',
          statusCode: 401,
        );
      }

      throw ApiException(detail.isEmpty ? 'Sessiya muddati tugagan. Qayta kiring.' : detail, statusCode: 401);

    }

    if (res.statusCode == 403) {

      throw ApiException(detail.isEmpty ? 'Bu amalni bajarish huquqingiz yo‘q.' : detail, statusCode: 403);

    }

    if (res.statusCode == 404) {

      throw ApiException(detail.isEmpty ? 'Ma\'lumot topilmadi.' : detail, statusCode: 404);

    }

    if (res.statusCode >= 500) {

      throw ApiException('Server bilan bog‘lanishda xatolik yuz berdi.', statusCode: res.statusCode);

    }

    throw ApiException(detail, statusCode: res.statusCode);

  }

}



/// Eski kod bilan moslik

extension ApiClientCompat on ApiClient {

  static String get lanHost => ApiClient.defaultHost;

}

