/// O‘zbekiston davlat raqami.
/// 00 A 000 AA (o‘rtada 1 harf → oxirida 2 harf)
/// 00 000 AAA (o‘rtada harf yo‘q → oxirida 3 harf)
class PlateUz {
  static const example = '00 A 000 AA yoki 00 000 AAA';

  /// Ruxsat etilgan viloyat kodlari (5 lik qadam).
  static const validRegions = {
    '01', '10', '20', '25', '30', '35', '40', '45', '50', '55',
    '60', '65', '70', '75', '80', '85', '90', '95',
  };

  static const snapMaxDiff = 5;

  static String digits2(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length > 2) d = d.substring(0, 2);
    return d;
  }

  /// 93 → 95, 12 → 10, 33 → 35. Farq 5 dan oshsa o‘zgarmaydi.
  static String snapRegion(String raw) {
    final d = digits2(raw);
    if (d.length != 2) return d;
    if (validRegions.contains(d)) return d;
    final n = int.tryParse(d);
    if (n == null) return d;
    String? best;
    var bestDiff = 99;
    for (final v in validRegions) {
      final vn = int.parse(v);
      final diff = (vn - n).abs();
      if (best == null || diff < bestDiff || (diff == bestDiff && vn < int.parse(best))) {
        best = v;
        bestDiff = diff;
      }
    }
    if (best != null && bestDiff <= snapMaxDiff) return best;
    return d;
  }

  static String normalize(String region, String midLetter, String digits, String endLetters) {
    final r = snapRegion(region).padLeft(2, '0');
    final m = midLetter.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final d = digits.replaceAll(RegExp(r'\D'), '');
    final e = endLetters.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    return '$r$m$d$e';
  }

  static bool isValidParts(String region, String midLetter, String digits, String endLetters) {
    return partsError(region, midLetter, digits, endLetters) == null;
  }

  static String? partsError(String region, String midLetter, String digits, String endLetters) {
    final snapped = snapRegion(region);
    if (snapped.length != 2 || !validRegions.contains(snapped)) {
      return 'Viloyat kodi noto‘g‘ri. Namuna: $example';
    }
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 3) {
      return 'O‘rtadagi 3 ta raqamni yozing. Namuna: $example';
    }
    final m = midLetter.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final e = endLetters.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (m.length > 1) {
      return 'O‘rtada faqat 1 ta harf yoki bo‘sh. Namuna: $example';
    }
    if (m.isEmpty) {
      if (e.length != 3) return 'Oxirida 3 ta harf kerak. Namuna: 00 000 AAA';
      return null;
    }
    if (e.length != 2) return 'Oxirida 2 ta harf kerak. Namuna: 00 A 000 AA';
    return null;
  }

  static bool isValid(String raw) {
    final p = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final m = RegExp(r'^(\d{2})([A-Z]?)(\d{3})([A-Z]{2,3})$').firstMatch(p);
    if (m == null) return false;
    return isValidParts(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!);
  }

  static int endLettersMax(String midLetter) {
    final m = midLetter.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return m.isEmpty ? 3 : 2;
  }

  static String display(String raw) {
    final p = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final m = RegExp(r'^(\d{2})([A-Z]?)(\d{3})([A-Z]{2,3})$').firstMatch(p);
    if (m == null) return raw.toUpperCase();
    final mid = m.group(2)!;
    if (mid.isEmpty) {
      return '${m.group(1)} ${m.group(3)} ${m.group(4)}';
    }
    return '${m.group(1)} $mid ${m.group(3)} ${m.group(4)}';
  }
}
