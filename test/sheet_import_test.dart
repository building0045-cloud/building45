import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/apartments/data/apartment.dart';
import 'package:home_system/features/sheet_import/data/import_item.dart';
import 'package:home_system/features/subscriptions/view/subscriptions_page.dart';

ImportItem _item({
  String original = '',
  String? edited,
  String kind = 'note',
}) => ImportItem.fromMap('g_C5', {
  'sheetGid': 'g',
  'sheetName': 'يونيو ٢٠٢٦',
  'period': '2026-06',
  'cell': 'C5',
  'row': 5,
  'col': 3,
  'originalText': original,
  'editedText': ?edited,
  'apartmentNumber': 4,
  'proposedKind': kind,
});

void main() {
  test('classifies contribution text', () {
    expect(classifyContribution('500'), ImportKind.payment);
    expect(classifyContribution('٥٠٠'), ImportKind.payment);
    expect(classifyContribution('خالص'), ImportKind.settledNote);
    expect(
      classifyContribution('تم الدفع في مايو'),
      ImportKind.paymentReference,
    );
    expect(
      classifyContribution('لم يتسلم الوحده'),
      ImportKind.notHandedOverNote,
    );
    expect(classifyContribution('غير ذلك'), ImportKind.note);
  });

  test('an unedited record shows the sheet value', () {
    final item = _item(original: '500 ', kind: 'payment');

    expect(item.text, '500');
    expect(item.kind, ImportKind.payment);
    expect(item.amount, 500);
    expect(item.isEdited, isFalse);
  });

  test('an edit replaces the value but keeps the original', () {
    final item = _item(original: 'خالص', edited: '250', kind: 'settledNote');

    expect(item.text, '250');
    expect(item.kind, ImportKind.payment);
    expect(item.amount, 250);
    expect(item.originalText, 'خالص');
    expect(item.originalKind, ImportKind.settledNote);
  });

  test('a payment edited to text no longer counts as an amount', () {
    final item = _item(original: '100', edited: 'خالص', kind: 'payment');

    expect(item.kind, ImportKind.settledNote);
    expect(item.amount, isNull);
  });

  test('clearing a record leaves an empty value', () {
    final item = _item(original: '100', edited: '', kind: 'payment');

    expect(item.text, isEmpty);
    expect(item.amount, isNull);
  });

  group('paid in another month', () {
    test('text names the month and year', () {
      expect(paidInText('2026-11'), 'تم الدفع في نوفمبر ٢٠٢٦');
      expect(
        classifyContribution(paidInText('2026-11')),
        ImportKind.paymentReference,
      );
    });

    test('reads month and year, with Arabic or Latin digits', () {
      expect(parsePaidIn('تم الدفع في نوفمبر ٢٠٢٦'), (month: 11, year: 2026));
      expect(parsePaidIn('تم الدفع في مايو 2025'), (month: 5, year: 2025));
    });

    test('older texts have only the month', () {
      expect(parsePaidIn('تم الدفع في مايو'), (month: 5, year: null));
    });

    test('anything else is not a paid-in text', () {
      expect(parsePaidIn('خالص'), isNull);
      expect(parsePaidIn('تم الدفع في وقت ما'), isNull);
    });

    test('a month without a sheet can be marked paid in another month', () {
      final sheet = ImportItem.appSheet('2027-01');
      expect(sheet.isAppRecord, isTrue);
      expect(sheet.sheetName, 'يناير ٢٠٢٧');

      // What saveContribution stores for apartment 24.
      final record = ImportItem.fromMap('app_2027-01_C25', {
        'sheetGid': sheet.sheetGid,
        'sheetName': sheet.sheetName,
        'period': '2027-01',
        'cell': 'C25',
        'row': 25,
        'col': 3,
        'originalText': '',
        'editedText': paidInText('2026-11'),
        'apartmentNumber': 24,
        'proposedKind': 'note',
      });
      const apt = Apartment(
        id: '24',
        number: 24,
        status: ApartmentStatus.occupied,
        feeEligible: true,
        contacts: [],
      );

      final summary = summarizeMonth('2027-01', [apt], null, [record]);

      expect(record.isAppRecord, isTrue);
      expect(summary.statuses.single.isPaid, isTrue);
      expect(summary.collected, 0);
    });
  });
}
