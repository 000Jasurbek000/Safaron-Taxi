import 'dart:convert';
import '../l10n/phrase.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/taxi_offer.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'safaron_api.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.mine,
    required this.at,
    this.read = true,
  });

  final String text;
  final bool mine;
  final DateTime at;
  final bool read;

  Map<String, dynamic> toJson() => {
        'text': text,
        'mine': mine,
        'at': at.toIso8601String(),
        'read': read,
      };

  static ChatMessage fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        mine: j['mine'] as bool,
        at: DateTime.parse(j['at'] as String),
        read: j['read'] as bool? ?? true,
      );
}

class ChatThread {
  ChatThread({
    required this.taxiId,
    required this.driverName,
    required this.carModel,
    required this.plate,
    required this.phone,
    required this.imageAsset,
    required this.messages,
    required this.updatedAt,
    this.passengerName = 'Yo‘lovchi',
    this.driverPhoto = '',
    this.passengerPhoto = '',
    this.remoteTripId,
    this.driverUserId,
    this.passengerUserId,
  });

  final String taxiId;
  final String driverName;
  final String carModel;
  final String plate;
  final String phone;
  final String imageAsset;
  final List<ChatMessage> messages;
  final DateTime updatedAt;
  final String passengerName;
  final String driverPhoto;
  final String passengerPhoto;

  /// Server haqiqiy Trip id'si — mavjud bo'lsa, bu suhbat serverga ulangan
  /// bo'ladi (xabar yuborish/sinxronlash backendga boradi).
  final int? remoteTripId;
  final int? driverUserId;
  final int? passengerUserId;

  int get unreadCount => messages.where((m) => !m.mine && !m.read).length;
  int get unreadCountForDriver => messages.where((m) => m.mine && !m.read).length;
  bool get hasUnread => unreadCount > 0;
  bool get hasUnreadForDriver => unreadCountForDriver > 0;

  String get lastPreview {
    if (messages.isEmpty) return 'Yangi suhbat';
    return messages.last.text;
  }

  String get timeLabel {
    final now = DateTime.now();
    final d = updatedAt.toLocal();
    if (now.year == d.year && now.month == d.month && now.day == d.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  TaxiOffer toTaxi() => TaxiOffer(
        id: taxiId,
        from: '',
        to: '',
        time: '',
        seats: 1,
        price: 0,
        driverName: driverName,
        rating: 4.8,
        reviews: 0,
        carModel: carModel,
        plate: plate,
        phone: phone,
        imageAsset: imageAsset,
        driverPhoto: driverPhoto,
        driverUserId: driverUserId,
        remoteTripId: remoteTripId,
        period: TimeOfDayFilter.all,
      );

  Map<String, dynamic> toJson() => {
        'taxiId': taxiId,
        'driverName': driverName,
        'carModel': carModel,
        'plate': plate,
        'phone': phone,
        'imageAsset': imageAsset,
        'updatedAt': updatedAt.toIso8601String(),
        'passengerName': passengerName,
        'driverPhoto': driverPhoto,
        'passengerPhoto': passengerPhoto,
        if (remoteTripId != null) 'remoteTripId': remoteTripId,
        if (driverUserId != null) 'driverUserId': driverUserId,
        if (passengerUserId != null) 'passengerUserId': passengerUserId,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  static ChatThread fromJson(Map<String, dynamic> j) => ChatThread(
        taxiId: j['taxiId'] as String,
        driverName: j['driverName'] as String,
        carModel: j['carModel'] as String,
        plate: j['plate'] as String,
        phone: j['phone'] as String? ?? '',
        imageAsset: j['imageAsset'] as String? ?? 'assets/images/car_cobalt.png',
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        passengerName: j['passengerName'] as String? ?? tr('Yo‘lovchi'),
        driverPhoto: j['driverPhoto'] as String? ?? '',
        passengerPhoto: j['passengerPhoto'] as String? ?? '',
        remoteTripId: j['remoteTripId'] as int?,
        driverUserId: j['driverUserId'] as int?,
        passengerUserId: j['passengerUserId'] as int?,
        messages: (j['messages'] as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const _kKey = 'safaron_chats_v2';

  final Map<String, ChatThread> _threads = {};
  bool _loaded = false;

  List<ChatThread> get threads {
    final list = _threads.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  bool get hasChats => _threads.isNotEmpty;
  bool get hasUnread => _threads.values.any((t) => t.hasUnread);
  bool get hasUnreadForDriver => _threads.values.any((t) => t.hasUnreadForDriver);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey) ?? prefs.getString('safaron_chats_v1');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          final t = ChatThread.fromJson(item as Map<String, dynamic>);
          _threads[t.taxiId] = t;
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  /// Hisobdan chiqishda — bu qurilmadagi keyingi foydalanuvchi oldingisining
  /// yozishmalarini (telefon raqamlari bilan) ko‘rmasligi uchun.
  Future<void> clearForLogout() async {
    _threads.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _threads.values.map((t) => t.toJson()).toList();
    await prefs.setString(_kKey, jsonEncode(data));
  }

  String _passengerLabel() {
    final name = ProfileService.instance.fullName.trim();
    return name.isEmpty ? tr('Yo‘lovchi') : name;
  }

  /// Suhbatni (mavjud bo'lmasa) yaratadi. Odatda passenger o'z qurilmasida
  /// o'zini-o'zi "yo'lovchi" sifatida belgilaydi (override'siz chaqiriladi).
  /// Haydovchi tomonidan, so'rovni qabul qilgach, yo'lovchi ma'lumotlarini
  /// bilib proaktiv urug'lash uchun override'lar beriladi — aks holda
  /// haydovchi hali Xabarlar bo'limini ochmagan bo'lsa, bu suhbat u yerda
  /// umuman ko'rinmas edi.
  ChatThread ensureThread(
    TaxiOffer taxi, {
    String? passengerNameOverride,
    int? passengerUserIdOverride,
    String? passengerPhotoOverride,
  }) {
    final existing = _threads[taxi.id];
    if (existing != null) return existing;

    final thread = ChatThread(
      taxiId: taxi.id,
      driverName: taxi.driverName,
      carModel: taxi.carModel,
      plate: taxi.plate,
      phone: taxi.phone,
      imageAsset: taxi.imageAsset,
      updatedAt: DateTime.now(),
      passengerName: passengerNameOverride ?? _passengerLabel(),
      driverPhoto: taxi.driverPhoto,
      passengerPhoto: passengerPhotoOverride ?? ProfileService.instance.avatarPath,
      remoteTripId: taxi.remoteTripId,
      driverUserId: taxi.driverUserId,
      passengerUserId: passengerUserIdOverride ?? AuthService.instance.user?.id,
      messages: const [],
    );
    _threads[taxi.id] = thread;
    _persist();
    notifyListeners();
    return thread;
  }

  void _storeThread(ChatThread thread, DateTime updatedAt) {
    _threads[thread.taxiId] = ChatThread(
      taxiId: thread.taxiId,
      driverName: thread.driverName,
      carModel: thread.carModel,
      plate: thread.plate,
      phone: thread.phone,
      imageAsset: thread.imageAsset,
      messages: thread.messages,
      updatedAt: updatedAt,
      passengerName: thread.passengerName,
      driverPhoto: thread.driverPhoto,
      passengerPhoto: thread.passengerPhoto,
      remoteTripId: thread.remoteTripId,
      driverUserId: thread.driverUserId,
      passengerUserId: thread.passengerUserId,
    );
  }

  Future<void> markRead(String taxiId) async {
    final thread = _threads[taxiId];
    if (thread == null) return;
    var changed = false;
    for (var i = 0; i < thread.messages.length; i++) {
      final m = thread.messages[i];
      if (!m.mine && !m.read) {
        thread.messages[i] = ChatMessage(text: m.text, mine: m.mine, at: m.at, read: true);
        changed = true;
      }
    }
    if (changed) {
      _storeThread(thread, DateTime.now());
      await _persist();
      notifyListeners();
    }
    if (thread.remoteTripId != null) {
      try {
        await MessageApi.instance.markRead(tripId: thread.remoteTripId);
      } catch (_) {
        // Internet yo'q — mahalliy holat baribir yangilandi, keyingi
        // muvaffaqiyatli chaqiriqda serverga yetib boradi.
      }
    }
  }

  Future<void> markReadForDriver(String taxiId) async {
    final thread = _threads[taxiId];
    if (thread == null) return;
    var changed = false;
    for (var i = 0; i < thread.messages.length; i++) {
      final m = thread.messages[i];
      if (m.mine && !m.read) {
        thread.messages[i] = ChatMessage(text: m.text, mine: m.mine, at: m.at, read: true);
        changed = true;
      }
    }
    if (changed) {
      _storeThread(thread, DateTime.now());
      await _persist();
      notifyListeners();
    }
    if (thread.remoteTripId != null) {
      try {
        await MessageApi.instance.markRead(tripId: thread.remoteTripId);
      } catch (_) {}
    }
  }

  List<ChatMessage> messagesFor(String taxiId, {bool asDriver = false}) {
    final raw = _threads[taxiId]?.messages ?? const [];
    if (!asDriver) return List.unmodifiable(raw);
    return raw
        .map((m) => ChatMessage(text: m.text, mine: !m.mine, at: m.at, read: m.read))
        .toList();
  }

  Future<void> sendUserMessage(TaxiOffer taxi, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ensureThread(taxi);
    final thread = _threads[taxi.id]!;
    if (thread.remoteTripId != null && thread.driverUserId != null) {
      try {
        await MessageApi.instance.send(
          body: trimmed,
          receiverId: thread.driverUserId!,
          tripId: thread.remoteTripId,
        );
      } catch (_) {
        // Internet yo'q — mahalliy xabar baribir saqlanadi, keyingi
        // sinxronlashda server holati bilan almashtiriladi.
      }
    }
    final now = DateTime.now();
    thread.messages.add(ChatMessage(text: trimmed, mine: true, at: now, read: false));
    _storeThread(thread, now);
    await _persist();
    notifyListeners();
  }

  Future<void> sendDriverMessage(String taxiId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final thread = _threads[taxiId];
    if (thread == null) return;
    if (thread.remoteTripId != null && thread.passengerUserId != null) {
      try {
        await MessageApi.instance.send(
          body: trimmed,
          receiverId: thread.passengerUserId!,
          tripId: thread.remoteTripId,
        );
      } catch (_) {}
    }
    final now = DateTime.now();
    thread.messages.add(ChatMessage(text: trimmed, mine: false, at: now, read: false));
    _storeThread(thread, now);
    await _persist();
    notifyListeners();
  }

  /// Boshqa qurilmadan kelgan xabarlarni serverdan tortib, mahalliy
  /// ro'yxatni almashtiradi. Faqat server-backed (remoteTripId bor) suhbatlar
  /// uchun ishlaydi — demo/mock suhbatlar mahalliyligicha qoladi.
  Future<void> syncFromServer(String taxiId) async {
    final thread = _threads[taxiId];
    if (thread == null || thread.remoteTripId == null) return;
    try {
      final rows = await MessageApi.instance.list(tripId: thread.remoteTripId);
      final mapped = rows
          .map((r) => ChatMessage(
                text: r['body'] as String? ?? '',
                mine: r['sender_id'] == thread.passengerUserId,
                at: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
                read: r['is_read'] as bool? ?? false,
              ))
          .toList();
      _threads[taxiId] = ChatThread(
        taxiId: thread.taxiId,
        driverName: thread.driverName,
        carModel: thread.carModel,
        plate: thread.plate,
        phone: thread.phone,
        imageAsset: thread.imageAsset,
        driverPhoto: thread.driverPhoto,
        passengerPhoto: thread.passengerPhoto,
        remoteTripId: thread.remoteTripId,
        driverUserId: thread.driverUserId,
        passengerUserId: thread.passengerUserId,
        messages: mapped,
        updatedAt: mapped.isEmpty ? thread.updatedAt : mapped.last.at,
        passengerName: thread.passengerName,
      );
      await _persist();
      notifyListeners();
    } catch (_) {
      // Internet yo'q yoki server javob bermadi — mahalliy ro'yxat o'zgarishsiz qoladi.
    }
  }

  /// Barcha server-backed suhbatlarni yangilaydi — pastga tortib yangilashda
  /// har bir threadni alohida ochmasdan preview/unread-belgi yangilanishi uchun.
  Future<void> syncAllFromServer() async {
    final targets = _threads.values.where((t) => t.remoteTripId != null).map((t) => t.taxiId).toList();
    for (final taxiId in targets) {
      await syncFromServer(taxiId);
    }
  }
}
