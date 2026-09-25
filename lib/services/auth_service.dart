import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthUser {
  AuthUser({
    required this.id,
    required this.phone,
    required this.phoneDisplay,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.activeRole,
    required this.language,
    this.driverStatus,
    this.driverId,
    this.isOnline,
    this.ratingAvg = 5.0,
  });

  final int id;
  final String phone;
  final String phoneDisplay;
  final String firstName;
  final String lastName;
  final String fullName;
  final String activeRole;
  final String language;
  final String? driverStatus;
  final int? driverId;
  final bool? isOnline;
  final double ratingAvg;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        phone: j['phone'] as String? ?? '',
        phoneDisplay: j['phone_display'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        activeRole: j['active_role'] as String? ?? 'passenger',
        language: j['language'] as String? ?? 'uz',
        driverStatus: j['driver_status'] as String?,
        driverId: j['driver_id'] as int?,
        isOnline: j['is_online'] as bool?,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble() ?? 5.0,
      );
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kRegistered = 'safaron_registered';

  bool _loaded = false;
  bool registered = false;
  AuthUser? user;

  String get name => user?.firstName ?? '';
  String get surname => user?.lastName ?? '';
  String get phone => user?.phoneDisplay.isNotEmpty == true ? user!.phoneDisplay : (user?.phone ?? '');

  Future<void> load() async {
    if (_loaded) return;
    await ApiClient.instance.load();
    final prefs = await SharedPreferences.getInstance();
    registered = prefs.getBool(_kRegistered) ?? false;
    if (ApiClient.instance.token != null) {
      try {
        final data = await ApiClient.instance.get('/api/auth/me');
        user = AuthUser.fromJson(data as Map<String, dynamic>);
        registered = true;
        await prefs.setBool(_kRegistered, true);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          await logout();
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// SMSsiz kirish — telefon + ism + familiya.
  Future<void> signInWithProfile({
    required String phone,
    required String firstName,
    required String lastName,
    String? referralCode,
  }) async {
    try {
      final data = await ApiClient.instance.post('/api/auth/sign-in', body: {
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        if (referralCode != null && referralCode.trim().isNotEmpty) 'referral_code': referralCode.trim(),
      });
      final map = data as Map<String, dynamic>;
      await ApiClient.instance.setToken(map['access_token'] as String);
      user = AuthUser.fromJson(map['user'] as Map<String, dynamic>);
      registered = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRegistered, true);
      notifyListeners();
    } on ApiException catch (e) {
      if (_isConnectionError(e)) {
        await _signInOffline(phone: phone, firstName: firstName, lastName: lastName);
        return;
      }
      rethrow;
    } catch (_) {
      await _signInOffline(phone: phone, firstName: firstName, lastName: lastName);
    }
  }

  Future<void> _signInOffline({
    required String phone,
    required String firstName,
    required String lastName,
  }) async {
    final fn = firstName.trim();
    final ln = lastName.trim();
    if (fn.length < 2 || ln.length < 2) {
      throw ApiException('Ism va familiya kamida 2 harf bo‘lishi kerak.');
    }
    user = AuthUser(
      id: phone.hashCode.abs(),
      phone: phone,
      phoneDisplay: phone,
      firstName: fn,
      lastName: ln,
      fullName: '$fn $ln',
      activeRole: 'passenger',
      language: 'uz',
    );
    registered = true;
    await ApiClient.instance.setToken('offline_${phone.hashCode.abs()}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRegistered, true);
    notifyListeners();
  }

  Future<({String message, bool userExists})> sendOtp(String phone) async {
    try {
      final data = await ApiClient.instance.post('/api/auth/otp/send', body: {'phone': phone});
      final map = data as Map;
      return (
        message: map['message']?.toString() ?? 'SMS yuborildi',
        userExists: map['user_exists'] == true,
      );
    } on ApiException catch (e) {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  bool _isConnectionError(ApiException e) {
    final m = e.message.toLowerCase();
    return m.contains('ulanib bo‘lmadi') ||
        m.contains('vaqti tugadi') ||
        m.contains('internet') ||
        e.statusCode == null && m.contains('server');
  }

  Future<void> verifyOtp({
    required String phone,
    required String code,
    String? firstName,
    String? lastName,
  }) async {
    try {
      await _verifyOtpRemote(
        phone: phone,
        code: code,
        firstName: firstName,
        lastName: lastName,
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<void> _verifyOtpRemote({
    required String phone,
    required String code,
    String? firstName,
    String? lastName,
  }) async {
    final data = await ApiClient.instance.post('/api/auth/otp/verify', body: {
      'phone': phone,
      'code': code,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    });
    final map = data as Map<String, dynamic>;
    await ApiClient.instance.setToken(map['access_token'] as String);
    user = AuthUser.fromJson(map['user'] as Map<String, dynamic>);
    registered = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRegistered, true);
    notifyListeners();
  }

  /// Legacy shim used by older screens.
  Future<void> register({
    required String name,
    required String surname,
    required String phone,
  }) async {
    await signInWithProfile(phone: phone, firstName: name, lastName: surname);
  }

  Future<void> setRole(String role) async {
    final data = await ApiClient.instance.post('/api/users/me/role', body: {'role': role});
    user = AuthUser.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    final data = await ApiClient.instance.post('/api/users/me/language', body: {'language': language});
    user = AuthUser.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    int? experienceYears,
  }) async {
    final body = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
    };
    if (experienceYears != null) body['experience_years'] = experienceYears;
    final data = await ApiClient.instance.patch('/api/users/me', body: body);
    user = AuthUser.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> changePhone({required String phone, required String code}) async {
    final data = await ApiClient.instance.post('/api/users/me/phone', body: {
      'phone': phone,
      'code': code,
    });
    user = AuthUser.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> refreshMe() async {
    final data = await ApiClient.instance.get('/api/auth/me');
    user = AuthUser.fromJson(data as Map<String, dynamic>);
    registered = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.instance.setToken(null);
    user = null;
    registered = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRegistered, false);
    notifyListeners();
  }
}
