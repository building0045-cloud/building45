import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/sheet_import/data/import_item.dart';

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
}
