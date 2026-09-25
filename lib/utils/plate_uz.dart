/// O‘zbekiston davlat raqami.
/// 01 A 123 BC (o‘rtada 1 harf → oxirida 2 harf)
/// 01 123 ABC (o‘rtada harf yo‘q → oxirida 3 harf)
class PlateUz {
  /// Ruxsat etilgan viloyat kodlari (13 yo‘q).
  static const validRegions = {
    '01', '10', '20', '25', '30', '35', '40', '45', '50', '55',
    '60', '65', '70', '75', '80', '85', '90', '95',
  };

  static String normalize(String region, String midLetter, String digits, String endLetters) {
    final r = region.replaceAll(RegExp(r'\D'), '').padLeft(2, '0').substring(0, 2);
    final m = midLetter.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final d = digits.replaceAll(RegExp(r'\D'), '');
    final e = endLetters.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    return '$r$m$d$e';
  }

  static bool isValidParts(String region, String midLetter, String digits, String endLetters) {
    final r = region.replaceAll(RegExp(r'\D'), '');
    if (r.length != 2 || !validRegions.contains(r)) return false;

    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 3) return false;

    final m = midLetter.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final e = endLetters.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();

    if (m.length > 1) return false;
    if (m.isEmpty) {
      return e.length == 3;
    }
    return e.length == 2;
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
