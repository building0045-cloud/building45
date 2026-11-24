import 'money.dart';

/// Monthly periods are `yyyy-MM` strings.
const arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// First month recorded in the old spreadsheet.
const firstPeriod = '2025-12';

String periodOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

int periodYear(String period) => int.parse(period.substring(0, 4));
int periodMonth(String period) => int.parse(period.substring(5, 7));

String periodLabel(String period) =>
    '${arabicMonths[periodMonth(period) - 1]} ${toArabicDigits('${periodYear(period)}')}';

String shiftPeriod(String period, int months) {
  final total = periodYear(period) * 12 + periodMonth(period) - 1 + months;
  return periodOf(DateTime(total ~/ 12, total % 12 + 1));
}

String currentPeriod([DateTime? now]) => periodOf(now ?? DateTime.now());

/// How many months ahead a subscription can be paid.
const prepayMonths = 12;

/// Latest month that can be recorded, so payments in advance work.
String lastOpenPeriod([DateTime? now]) =>
    shiftPeriod(currentPeriod(now), prepayMonths);

String formatDate(DateTime d) =>
    '${toArabicDigits('${d.day}')} ${arabicMonths[d.month - 1]} ${toArabicDigits('${d.year}')}';

/// Arabic label for a set of `yyyy-MM` months chosen in a filter.
/// Empty means no date filter.
String describeSelection(Set<String> periods) {
  if (periods.isEmpty) return 'كل الفترات';
  final sorted = periods.toList()..sort();
  if (sorted.length == 1) return periodLabel(sorted.first);
  final years = {for (final p in sorted) periodYear(p)};
  if (years.length == 1 && sorted.length == 12) {
    return 'سنة ${toArabicDigits('${years.first}')}';
  }
  final count = sorted.length == 2
      ? 'شهرين'
      : '${toArabicDigits('${sorted.length}')} شهور';
  return '$count (${periodLabel(sorted.first)} – ${periodLabel(sorted.last)})';
}
