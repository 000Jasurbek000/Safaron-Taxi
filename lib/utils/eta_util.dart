import '../l10n/phrase.dart';

/// Jo‘nash vaqtidan ETA matni.

class EtaUtil {
  /// "09:00", "9:00", "09:00 · ertalab" kabi formatlardan soat:daqiqa.
  static (int, int)? parseHm(String raw) {
    final m = RegExp(r'(\d{1,2})\s*:\s*(\d{2})').firstMatch(raw);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null || h > 23 || min > 59) return null;
    return (h, min);
  }

  /// Agar jo‘nash vaqti yo‘q bo‘lsa — null.
  static Duration? untilDeparture(String timeLabel, {DateTime? now}) {
    final hm = parseHm(timeLabel);
    if (hm == null) return null;
    final n = now ?? DateTime.now();
    var target = DateTime(n.year, n.month, n.day, hm.$1, hm.$2);
    if (target.isBefore(n.subtract(const Duration(minutes: 1)))) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(n);
  }

  static String formatDuration(Duration d) {
    final total = d.inMinutes.abs();
    final h = total ~/ 60;
    final m = total % 60;
    if (h > 0 && m > 0) return '$h ${tr('soat')} $m ${tr('daqiqa')}';
    if (h > 0) return '$h ${tr('soat')}';
    return '$m ${tr('daqiqa')}';
  }

  /// Kartochka uchun: vaqt bor → qancha keyin; yo‘q → haydovchi javobi.
  static String arrivalHint(String timeLabel) {
    final d = untilDeparture(timeLabel);
    if (d == null) {
      return tr('Qancha daqiqada kelishi haydovchi javobiga bog‘liq');
    }
    if (d.isNegative || d.inMinutes <= 0) {
      return tr('Jo‘nash vaqti yetib keldi / kechikishi mumkin');
    }
    return '${tr('Taxminan')} ${formatDuration(d)} ${tr('dan keyin keladi')}';
  }

  /// Teskari sanoq / kechikish matni.
  static String countdownLabel(DateTime arriveAt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = arriveAt.difference(n);
    if (diff.inSeconds >= 0) {
      return '${tr('Yetib kelish')}: ${formatDuration(diff)}';
    }
    return '${tr('Kechikish')}: ${formatDuration(diff)}';
  }
}
