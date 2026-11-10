import 'package:intl/intl.dart';

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

String toArabicDigits(String s) =>
    s.replaceAllMapped(RegExp(r'\d'), (m) => _arabicDigits[int.parse(m[0]!)]);

/// Parses a plain number written with Western or Arabic-Indic digits.
num? parseAmount(String text) {
  var s = text.trim().replaceAll(',', '').replaceAll('٬', '');
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(_arabicDigits[i], '$i');
  }
  return RegExp(r'^\d+(\.\d+)?$').hasMatch(s) ? num.parse(s) : null;
}

/// Amount in whole piastres (1 EGP = 100 piastres), or null if invalid.
int? parsePiastres(String text) {
  final value = parseAmount(text);
  return value == null ? null : (value * 100).round();
}

final _grouped = NumberFormat('#,##0', 'en');

/// "2,850" or "2,850.50", without the currency.
String formatAmount(int piastres) {
  final sign = piastres < 0 ? '-' : '';
  final abs = piastres.abs();
  final rest = abs % 100;
  return '$sign${_grouped.format(abs ~/ 100)}'
      '${rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}'}';
}

String formatEgp(int piastres) => '${formatAmount(piastres)} ج.م';
