import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../../core/phone.dart';
import '../../apartments/data/apartment.dart';
import 'arrears.dart';

/// Editable text around the apartment list of the monthly collection
/// message. `{month}` is replaced by the month name (أغسطس) and
/// `{monthNumber}` by its number (٨).
class CollectionTemplate {
  const CollectionTemplate({required this.header, required this.footer});

  factory CollectionTemplate.fromMap(Map<String, dynamic>? map) =>
      CollectionTemplate(
        header: map?['header'] as String? ?? defaults.header,
        footer: map?['footer'] as String? ?? defaults.footer,
      );

  final String header;
  final String footer;

  Map<String, dynamic> toMap() => {'header': header, 'footer': footer};

  static const defaults = CollectionTemplate(
    header:
        'مساء الخير .. هستأذنكو في تحويل مصاريف الصيانة لشهر {monthNumber} 🙏',
    footer: '''مصاريف صيانة الشهرية:
١٠٠ جنيه لو حضرتك ساكن/ة
٥٠ جنيه لو حضرتك استلمت/ي الشقة بس مش مقيم/ة

تقدر تحول عن طريق انستاباي
حساب بنكي علي رقم ...

محفظة فودافون كاش علي رقم ...


المنشن عبارة عن تسهيل وتنظيم عملية جمع مصروف الصيانة شهريا .. ياريت محدش يحس انه في اي نية اخري من المنشن دا هيبقي تنبيه شهري يفكر حضرتك بفلوس الصيانة مش اكتر وان شاء الله نبقي جيرة في الخير باذن الله 🙏''',
  );
}

/// "شهر", "شهرين", "٣ شهور", "١١ شهر".
String monthsCount(int n) => switch (n) {
  1 => 'شهر',
  2 => 'شهرين',
  >= 3 && <= 10 => '${toArabicDigits('$n')} شهور',
  _ => '${toArabicDigits('$n')} شهر',
};

/// "متأخر ٣ شهور من يونيو", counting the unpaid months up to [current]
/// (inclusive). Null when nothing before [current] is unpaid, i.e. only
/// this month's subscription is due.
String? delayPhrase(List<UnpaidMonth> months, String current) {
  final due = [
    for (final m in months)
      if (m.period.compareTo(current) <= 0) m.period,
  ];
  if (due.isEmpty || (due.length == 1 && due.first == current)) return null;
  final first = due.first;
  final from = periodYear(first) == periodYear(current)
      ? arabicMonths[periodMonth(first) - 1]
      : periodLabel(first);
  return 'متأخر ${monthsCount(due.length)} من $from';
}

/// The person addressed for the apartment's subscription: the tenant of a
/// rented apartment, otherwise the owner.
Contact? payerOf(Apartment a) {
  final named = a.contacts.where((c) => c.name.trim().isNotEmpty);
  final kind = a.isRented ? ContactKind.tenant : ContactKind.owner;
  return named.where((c) => c.kind == kind).firstOrNull ?? named.firstOrNull;
}

/// "+20 102 087 4288" for Egyptian mobiles, otherwise `+` and the digits.
String formatPhone(String phone) {
  final d = whatsappNumber(phone);
  if (d.isEmpty) return '';
  if (d.length == 12 && d.startsWith('20')) {
    return '+20 ${d.substring(2, 5)} ${d.substring(5, 8)} ${d.substring(8)}';
  }
  return '+$d';
}

/// "@+20 102 087 4288", or empty when no phone is registered.
String mentionFor(Apartment a) {
  final payer = payerOf(a);
  final phone = (payer != null && payer.phone.trim().isNotEmpty)
      ? payer.phone
      : a.callableContacts.firstOrNull?.phone ?? '';
  final formatted = formatPhone(phone);
  return formatted.isEmpty ? '' : '@$formatted';
}

String _fill(String text, String period) => text
    .replaceAll('{month}', arabicMonths[periodMonth(period) - 1])
    .replaceAll('{monthNumber}', toArabicDigits('${periodMonth(period)}'));

/// The message sent to the building group at the start of [period]: every
/// apartment that owes anything up to [period], with how late it is.
String buildCollectionMessage({
  required Arrears arrears,
  required List<Apartment> apartments,
  required CollectionTemplate template,
  required String period,
}) {
  final blocks = <String>[];
  final sorted = [...apartments]..sort((a, b) => a.number.compareTo(b.number));
  for (final a in sorted) {
    final months = [
      for (final m in arrears.monthsFor(a.number))
        if (m.period.compareTo(period) <= 0) m,
    ];
    if (months.isEmpty) continue;
    final owed = months.fold(0, (s, m) => s + m.owed);
    final delay = delayPhrase(months, period);
    final name = payerOf(a)?.name.trim() ?? 'غير معروف';
    final mention = mentionFor(a);
    blocks.add(
      [
        'شقه ${a.number} .. ا/ $name',
        '${delay ?? 'المطلوب'} (${toArabicDigits(formatAmount(owed))} جنيه)',
        if (mention.isNotEmpty) mention,
      ].join('\n'),
    );
  }
  return [
    _fill(template.header, period).trim(),
    ...blocks,
    _fill(template.footer, period).trim(),
  ].where((s) => s.isNotEmpty).join('\n\n');
}
