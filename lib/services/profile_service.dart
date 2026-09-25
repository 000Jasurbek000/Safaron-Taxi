import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

enum AppRole { passenger, driver }

enum DriverStatus { none, pending, approved }

class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const _kRole = 'safaron_role';
  static const _kLang = 'safaron_lang';
  static const _kLangUi = 'safaron_lang_ui';
  static const _kDriverStatus = 'safaron_driver_status';
  static const _kFirst = 'safaron_driver_first';
  static const _kLast = 'safaron_driver_last';
  static const _kPhone = 'safaron_driver_phone';
  static const _kExp = 'safaron_driver_exp';
  static const _kCar = 'safaron_driver_car';
  static const _kPlate = 'safaron_driver_plate';
  static const _kSeats = 'safaron_driver_seats';
  static const _kHasSelfie = 'safaron_driver_selfie';
  static const _kSelfiePath = 'safaron_driver_selfie_path';
  static const _kHasCarPhoto = 'safaron_driver_car_photo';
  static const _kCarPhotoPath = 'safaron_driver_car_photo_path';
  static const _kAvatarPath = 'safaron_avatar_path';

  bool _loaded = false;
  AppRole role = AppRole.passenger;
  String languageCode = 'uz';
  String languageUiCode = 'uz'; // uz | uz_cyrl | ru | en
  DriverStatus driverStatus = DriverStatus.none;

  String firstName = '';
  String lastName = '';
  String phone = '';
  int experienceYears = 0;
  String carName = '';
  String plate = '';
  int seats = 4;
  bool hasSelfie = false;
  String selfiePath = '';
  bool hasCarPhoto = false;
  String carPhotoPath = '';
  /// Lokal fayl yo‘li; bo‘sh bo‘lsa — odam ikonkasi.
  String avatarPath = '';

  String get fullName => '$firstName $lastName'.trim();
  bool get isDriverRole => role == AppRole.driver;
  bool get isApprovedDriver => driverStatus == DriverStatus.approved;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString(_kRole) == 'driver' ? AppRole.driver : AppRole.passenger;
    languageCode = prefs.getString(_kLang) ?? 'uz';
    languageUiCode = prefs.getString(_kLangUi) ?? languageCode;
    final status = prefs.getString(_kDriverStatus) ?? 'none';
    driverStatus = switch (status) {
      'pending' => DriverStatus.pending,
      'approved' => DriverStatus.approved,
      _ => DriverStatus.none,
    };
    firstName = prefs.getString(_kFirst) ?? firstName;
    lastName = prefs.getString(_kLast) ?? lastName;
    phone = prefs.getString(_kPhone) ?? phone;
    experienceYears = prefs.getInt(_kExp) ?? experienceYears;
    carName = prefs.getString(_kCar) ?? carName;
    plate = prefs.getString(_kPlate) ?? plate;
    seats = prefs.getInt(_kSeats) ?? seats;
    hasSelfie = prefs.getBool(_kHasSelfie) ?? false;
    selfiePath = prefs.getString(_kSelfiePath) ?? '';
    hasCarPhoto = prefs.getBool(_kHasCarPhoto) ?? false;
    carPhotoPath = prefs.getString(_kCarPhotoPath) ?? '';
    avatarPath = prefs.getString(_kAvatarPath) ?? '';
    _loaded = true;
    await syncFromAuth();
    notifyListeners();
  }

  Future<void> setRole(AppRole value) async {
    if (value == AppRole.driver && driverStatus != DriverStatus.approved) {
      role = AppRole.passenger;
      notifyListeners();
      return;
    }
    try {
      await AuthService.instance.setRole(value == AppRole.driver ? 'driver' : 'passenger');
      role = value;
    } catch (_) {
      role = value;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role == AppRole.driver ? 'driver' : 'passenger');
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    languageCode = code == 'uz_cyrl' ? 'uz' : code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, languageCode);
    try {
      if (AuthService.instance.registered) {
        await AuthService.instance.setLanguage(languageCode);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLanguageUi(String code) async {
    languageUiCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangUi, code);
    notifyListeners();
  }

  String languageLabel() {
    return switch (languageUiCode) {
      'uz_cyrl' => 'Ўзбекча',
      'kk' => 'Қазақша',
      'ru' => 'Русский',
      _ => "O'zbekcha",
    };
  }

  Future<void> savePersonal({
    required String firstName,
    required String lastName,
    required String phone,
    required bool hasSelfie,
    int experienceYears = 0,
    String? selfiePath,
  }) async {
    this.firstName = firstName.trim();
    this.lastName = lastName.trim();
    this.phone = phone.trim();
    this.experienceYears = experienceYears;
    this.hasSelfie = hasSelfie;
    if (selfiePath != null) this.selfiePath = selfiePath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFirst, this.firstName);
    await prefs.setString(_kLast, this.lastName);
    await prefs.setString(_kPhone, this.phone);
    await prefs.setInt(_kExp, experienceYears);
    await prefs.setBool(_kHasSelfie, hasSelfie);
    await prefs.setString(_kSelfiePath, this.selfiePath);
    notifyListeners();
  }

  Future<void> saveVehicle({
    required String carName,
    required String plate,
    required int seats,
    required bool hasCarPhoto,
    String? carPhotoPath,
  }) async {
    this.carName = carName.trim();
    this.plate = plate.trim();
    this.seats = seats;
    this.hasCarPhoto = hasCarPhoto;
    if (carPhotoPath != null) {
      this.carPhotoPath = carPhotoPath;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCar, this.carName);
    await prefs.setString(_kPlate, this.plate);
    await prefs.setInt(_kSeats, seats);
    await prefs.setBool(_kHasCarPhoto, hasCarPhoto);
    if (this.carPhotoPath.isNotEmpty) {
      await prefs.setString(_kCarPhotoPath, this.carPhotoPath);
    }
    notifyListeners();
  }

  Future<void> submitApplication() async {
    driverStatus = DriverStatus.pending;
    role = AppRole.passenger;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDriverStatus, 'pending');
    await prefs.setString(_kRole, 'passenger');
    notifyListeners();
  }

  Future<void> approveDriver() async {
    driverStatus = DriverStatus.approved;
    role = AppRole.driver;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDriverStatus, 'approved');
    await prefs.setString(_kRole, 'driver');
    notifyListeners();
  }

  Future<void> setAvatarPath(String path) async {
    avatarPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path.isEmpty) {
      await prefs.remove(_kAvatarPath);
    } else {
      await prefs.setString(_kAvatarPath, path);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    role = AppRole.passenger;
    firstName = '';
    lastName = '';
    phone = '';
    hasSelfie = false;
    selfiePath = '';
    avatarPath = '';
    driverStatus = DriverStatus.none;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, 'passenger');
    await prefs.setString(_kDriverStatus, 'none');
    await prefs.remove(_kSelfiePath);
    await prefs.remove(_kFirst);
    await prefs.remove(_kLast);
    await prefs.remove(_kPhone);
    await prefs.remove(_kAvatarPath);
    notifyListeners();
  }

  Future<void> syncFromAuth() async {
    final u = AuthService.instance.user;
    if (u == null) return;
    firstName = u.firstName;
    lastName = u.lastName;
    phone = u.phoneDisplay.isNotEmpty ? u.phoneDisplay : u.phone;
    languageCode = u.language;
    driverStatus = switch (u.driverStatus) {
      'APPROVED' => DriverStatus.approved,
      'PENDING' => DriverStatus.pending,
      'REJECTED' || 'SUSPENDED' => DriverStatus.none,
      _ => driverStatus,
    };
    role = u.activeRole == 'driver' && driverStatus == DriverStatus.approved
        ? AppRole.driver
        : AppRole.passenger;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role == AppRole.driver ? 'driver' : 'passenger');
    await prefs.setString(
      _kDriverStatus,
      switch (driverStatus) {
        DriverStatus.approved => 'approved',
        DriverStatus.pending => 'pending',
        _ => 'none',
      },
    );
    await prefs.setString(_kLang, languageCode);
    await prefs.setString(_kFirst, firstName);
    await prefs.setString(_kLast, lastName);
    await prefs.setString(_kPhone, phone);
    notifyListeners();
  }
}
