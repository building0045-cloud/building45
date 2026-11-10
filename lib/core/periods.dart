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

/// Latest month that can be recorded: next month, so early payments work.
String lastOpenPeriod([DateTime? now]) => shiftPeriod(currentPeriod(now), 1);

String formatDate(DateTime d) =>
    '${toArabicDigits('${d.day}')} ${arabicMonths[d.month - 1]} ${toArabicDigits('${d.year}')}';
