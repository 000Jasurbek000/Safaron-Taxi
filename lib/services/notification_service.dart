import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'safaron_api.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.type = 'system',
  });

  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final String type;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    DateTime? at;
    final raw = j['created_at'];
    if (raw is String) at = DateTime.tryParse(raw);
    return AppNotification(
      id: j['id'] as int,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      isRead: j['is_read'] == true,
      createdAt: at,
      type: j['type'] as String? ?? 'system',
    );
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  List<AppNotification> items = [];
  int unread = 0;
  bool loading = false;
  Timer? _pollTimer;

  bool get hasUnread => unread > 0;

  /// Ilova ochiq turganda admin bildirishnomalari (broadcast) o‘z-o‘zidan
  /// ko‘rinishi uchun — ekran qayta ochilishini kutmaydi.
  void startPolling({Duration interval = const Duration(seconds: 45)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => refresh());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh({bool full = false}) async {
    if (!AuthService.instance.registered) {
      items = [];
      unread = 0;
      notifyListeners();
      return;
    }
    try {
      unread = await NotificationApi.instance.unreadCount();
      if (full) {
        loading = true;
        notifyListeners();
        final raw = await NotificationApi.instance.list();
        items = raw.map(AppNotification.fromJson).toList();
        unread = items.where((e) => !e.isRead).length;
      }
    } catch (_) {
      // Vaqtinchalik tarmoq xatosi — eski ro‘yxatni bo‘sh qilib tashlamaymiz.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    try {
      await NotificationApi.instance.markRead(id);
    } catch (_) {}
    items = [
      for (final n in items)
        if (n.id == id)
          AppNotification(id: n.id, title: n.title, body: n.body, isRead: true, createdAt: n.createdAt, type: n.type)
        else
          n,
    ];
    unread = items.where((e) => !e.isRead).length;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await NotificationApi.instance.markAllRead();
    } catch (_) {}
    items = [
      for (final n in items)
        AppNotification(id: n.id, title: n.title, body: n.body, isRead: true, createdAt: n.createdAt, type: n.type),
    ];
    unread = 0;
    notifyListeners();
  }
}
