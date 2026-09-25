import 'package:flutter/foundation.dart';
import '../l10n/phrase.dart';

import 'api_client.dart';

class PlatformConfigService extends ChangeNotifier {
  PlatformConfigService._();
  static final PlatformConfigService instance = PlatformConfigService._();

  bool loaded = false;
  bool maintenance = false;
  bool bonus = true;
  bool referral = true;
  bool withdrawal = true;
  String maintenanceMessage = 'Safaron texnik xizmat ko‘rsatish rejimida.';
  String latestVersion = '1.1.0';
  String minimumVersion = '1.0.0';
  bool forceUpdate = false;
  String updateUrl = '';
  String telegramAdmin = 'Safaron_bot';
  String? error;

  Future<void> load() async {
    try {
      final data = await ApiClient.instance.get('/api/config');
      final map = data as Map<String, dynamic>;
      final flags = (map['flags'] as Map?)?.cast<String, dynamic>() ?? {};
      maintenance = map['maintenance'] == true || flags['maintenance'] == true;
      bonus = map['bonus_enabled'] != false && flags['bonus'] != false;
      referral = map['referral_enabled'] != false && flags['referral'] != false;
      withdrawal = map['withdrawal_enabled'] != false && flags['withdrawal'] != false;
      maintenanceMessage = map['maintenance_message'] as String? ?? maintenanceMessage;
      latestVersion = map['latest_version'] as String? ?? latestVersion;
      minimumVersion = map['minimum_version'] as String? ?? minimumVersion;
      forceUpdate = map['force_update'] == true;
      updateUrl = map['update_url'] as String? ?? '';
      telegramAdmin = map['telegram_admin'] as String? ?? telegramAdmin;
      error = null;
    } catch (e) {
      error = tr('Server bilan bog‘lanib bo‘lmadi. Keyinroq urinib ko‘ring.');
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> reportGps({
    required String bookingId,
    required String role,
    required String phase,
    double? lat,
    double? lng,
    double? accuracy,
  }) async {
    if (lat == null || lng == null) {
      throw ApiException(tr('Safarni boshlash uchun joylashuv xizmatini yoqing.'));
    }
    await ApiClient.instance.post('/api/trips/gps', body: {
      'local_booking_id': bookingId,
      'role': role,
      'phase': phase,
      'latitude': lat,
      'longitude': lng,
      if (accuracy != null) 'accuracy_m': accuracy,
    });
  }
}
