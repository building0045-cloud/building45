import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/apartments/data/apartment.dart';
import 'package:home_system/features/subscriptions/data/arrears.dart';
import 'package:home_system/features/subscriptions/data/collection_message.dart';

List<UnpaidMonth> _months(List<String> periods, [int owed = 10000]) => [
  for (final p in periods) UnpaidMonth(p, owed),
];

Apartment _apt(
  int n,
  String name, {
  String phone = '',
  List<Contact> extra = const [],
}) => Apartment(
  id: '$n',
  number: n,
  status: ApartmentStatus.occupied,
  contacts: [
    Contact(name: name, kind: ContactKind.owner, phone: phone),
    ...extra,
  ],
);

void main() {
  group('delayPhrase', () {
    test('is empty when only this month is due', () {
      expect(delayPhrase(_months(['2026-08']), '2026-08'), isNull);
      expect(delayPhrase(const [], '2026-08'), isNull);
    });

    test('counts months from the first unpaid one, this month included', () {
      expect(
        delayPhrase(_months(['2026-07']), '2026-08'),
        'متأخر شهر من يوليو',
      );
      expect(
        delayPhrase(_months(['2026-07', '2026-08']), '2026-08'),
        'متأخر شهرين من يوليو',
      );
      expect(
        delayPhrase(_months(['2026-06', '2026-07', '2026-08']), '2026-08'),
        'متأخر ٣ شهور من يونيو',
      );
      expect(
        delayPhrase(
          _months([for (var m = 2; m <= 8; m++) '2026-0$m']),
          '2026-08',
        ),
        'متأخر ٧ شهور من فبراير',
      );
      expect(
        delayPhrase(
          _months([
            for (var m = 1; m <= 11; m++)
              '2026-${m.toString().padLeft(2, '0')}',
          ]),
          '2026-11',
        ),
        'متأخر ١١ شهر من يناير',
      );
    });

    test('names the year when the delay started in an earlier one', () {
      expect(
        delayPhrase(_months(['2026-12', '2027-01']), '2027-01'),
        'متأخر شهرين من ديسمبر ٢٠٢٦',
      );
    });
  });

  test('mentions the payer by phone number', () {
    expect(
      mentionFor(_apt(10, 'يوسف', phone: '01020874288')),
      '@+20 102 087 4288',
    );
    expect(mentionFor(_apt(10, 'يوسف')), '');
  });

  test('addresses the tenant of a rented apartment', () {
    final a = _apt(
      3,
      'المالك',
      phone: '01000000000',
      extra: const [
        Contact(
          name: 'المستأجر',
          kind: ContactKind.tenant,
          phone: '01111111111',
        ),
      ],
    );
    expect(payerOf(a)?.name, 'المستأجر');
    expect(mentionFor(a), '@+20 111 111 1111');
  });

  test('lists every owing apartment between the header and footer', () {
    final arrears = Arrears(
      {
        8: _months(['2026-07', '2026-08']),
        14: _months(['2026-08']),
        15: const [],
        22: _months(['2026-08'], 5000),
      },
      from: duesStartPeriod,
      to: '2026-08',
    );
    final message = buildCollectionMessage(
      arrears: arrears,
      apartments: [
        _apt(22, 'روان'),
        _apt(8, 'محمود ابراهيم', phone: '+20 155 820 6881'),
        _apt(14, 'عبدالرحمن', phone: '01020874288'),
        _apt(15, 'احمد'),
      ],
      template: const CollectionTemplate(
        header: 'تحويل مصاريف الصيانة لشهر {monthNumber} ({month})',
        footer: 'شكرًا',
      ),
      period: '2026-08',
    );

    expect(
      message,
      'تحويل مصاريف الصيانة لشهر ٨ (أغسطس)\n'
      '\n'
      'شقه 8 .. ا/ محمود ابراهيم\n'
      'متأخر شهرين من يوليو (٢٠٠ جنيه)\n'
      '@+20 155 820 6881\n'
      '\n'
      'شقه 14 .. ا/ عبدالرحمن\n'
      'المطلوب (١٠٠ جنيه)\n'
      '@+20 102 087 4288\n'
      '\n'
      'شقه 22 .. ا/ روان\n'
      'المطلوب (٥٠ جنيه)\n'
      '\n'
      'شكرًا',
    );
  });
}
