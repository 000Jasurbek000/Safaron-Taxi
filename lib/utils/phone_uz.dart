/// O‘zbekiston telefon: faqat +998XXXXXXXXX (9 ta raqam operator+abonent).
class PhoneUz {
  static final _re = RegExp(r'^\+998[0-9]{9}$');

  /// Faqat 9 ta raqam (90xxxxxxx).
  static String digitsOnly9(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('998') && d.length >= 12) d = d.substring(3);
    if (d.startsWith('0') && d.length >= 10) d = d.substring(1);
    if (d.length > 9) d = d.substring(0, 9);
    return d;
  }

  static String? normalize(String raw) {
    final nine = digitsOnly9(raw);
    if (nine.length != 9) return null;
    final full = '+998$nine';
    return _re.hasMatch(full) ? full : null;
  }

  static bool isValidInput9(String raw) => digitsOnly9(raw).length == 9;

  static String display(String e164) {
    final n = normalize(e164) ?? e164;
    if (!_re.hasMatch(n)) return e164;
    return '+998 ${n.substring(4, 6)} ${n.substring(6, 9)} ${n.substring(9, 11)} ${n.substring(11)}';
  }
}
