/// Money is stored as integer minor units (cents) to avoid floating-point errors.
int? parseMinor(String input) {
  final s = input.trim().replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final whole = int.parse(parts[0]);
  final frac = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final v = whole * 100 + frac;
  return v > 0 ? v : null;
}

String formatMinor(int minor) {
  final neg = minor < 0;
  final a = minor.abs();
  final whole = (a ~/ 100).toString();
  final frac = (a % 100).toString().padLeft(2, '0');
  final b = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) b.write('\u00A0');
    b.write(whole[i]);
  }
  return '${neg ? '-' : ''}$b.$frac';
}

/// Plain text for editing fields: 1234.50
String minorToInput(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
