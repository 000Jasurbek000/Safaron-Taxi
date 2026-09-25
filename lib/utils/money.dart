import '../l10n/phrase.dart';

String formatSom(int value) {
  final raw = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buf.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
  }
  return "${buf.toString()} ${tr("so'm")}";
}

/// Faqat raqamlarni qoldiradi.
int? parseSomInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}
