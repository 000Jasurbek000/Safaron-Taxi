import 'dart:convert';
import '../l10n/phrase.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/taxi_offer.dart';
import 'profile_service.dart';

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
    final d = updatedAt;
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _threads.values.map((t) => t.toJson()).toList();
    await prefs.setString(_kKey, jsonEncode(data));
  }

  String _passengerLabel() {
    final name = ProfileService.instance.fullName.trim();
    return name.isEmpty ? tr('Yo‘lovchi') : name;
  }

  ChatThread ensureThread(TaxiOffer taxi) {
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
      passengerName: _passengerLabel(),
      messages: [
        ChatMessage(
          text: 'Assalomu alaykum! Qayerdan olasiz?',
          mine: false,
          at: DateTime.now(),
          read: false,
        ),
      ],
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
    if (!changed) return;
    _storeThread(thread, DateTime.now());
    await _persist();
    notifyListeners();
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
    if (!changed) return;
    _storeThread(thread, DateTime.now());
    await _persist();
    notifyListeners();
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
    final now = DateTime.now();
    thread.messages.add(ChatMessage(text: trimmed, mine: false, at: now, read: false));
    _storeThread(thread, now);
    await _persist();
    notifyListeners();
  }
}
