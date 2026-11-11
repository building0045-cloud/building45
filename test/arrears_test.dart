import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/apartments/data/apartment.dart';
import 'package:home_system/features/ledger/cubit/ledger_cubit.dart';
import 'package:home_system/features/ledger/data/ledger_tx.dart';
import 'package:home_system/features/sheet_import/data/import_item.dart';
import 'package:home_system/features/subscriptions/data/arrears.dart';

Apartment _apt(
  int n, {
  bool feeEligible = true,
  String name = 'ساكن',
  int? monthlyFee,
}) => Apartment(
  id: '$n',
  number: n,
  status: ApartmentStatus.occupied,
  feeEligible: feeEligible,
  monthlyFee: monthlyFee,
  contacts: [if (name.isNotEmpty) Contact(name: name, kind: ContactKind.owner)],
);

ImportItem _cell(String period, int apt, String text) => ImportItem(
  id: '${period}_$apt',
  sheetGid: '1',
  sheetName: period,
  period: period,
  cell: 'C$apt',
  row: apt,
  col: 3,
  originalText: text,
  editedText: null,
  apartmentNumber: apt,
  originalKind: classifyContribution(text),
  status: 'pending',
);

LedgerTx _paid(int apt, List<Allocation> allocations) => LedgerTx(
  id: 'p$apt',
  type: TxType.subscription,
  amount: allocations.fold(0, (s, a) => s + a.amount),
  date: DateTime(2026, 11, 1),
  apartmentNumber: apt,
  allocations: allocations,
);

void main() {
  Arrears compute(
    List<Apartment> apartments, {
    List<LedgerTx> txs = const [],
    List<ImportItem> sheet = const [],
    String from = duesStartPeriod,
    String to = '2026-11',
  }) => computeArrears(
    from: from,
    apartments: apartments,
    ledger: LedgerLoaded(txs),
    sheetItems: sheet,
    buildingFee: 10000,
    to: to,
  );

  test('every month from January without any record is unpaid', () {
    final a = compute([_apt(1)]);

    expect(a.byApartment[1]!.first.period, '2026-01');
    expect(a.byApartment[1]!.last.period, '2026-11');
    expect(a.byApartment[1]!.length, 11);
    expect(a.totalFor(1), 110000);
    expect(a.total, 110000);
    expect(a.apartmentsOwing, 1);
    expect(a.carriedTotalFor(1), 0);
  });

  test('each apartment owes its own monthly fee', () {
    final a = compute(
      [_apt(1, monthlyFee: 5000), _apt(2)],
      to: '2026-01',
      txs: [
        _paid(1, const [Allocation('2026-01', 3000)]),
      ],
    );

    expect(a.totalFor(1), 2000);
    expect(a.totalFor(2), 10000);
  });

  test('unpaid months of an earlier year are carried over', () {
    final settledUntilOct = [
      for (var m = 1; m <= 10; m++)
        _cell('2026-${m.toString().padLeft(2, '0')}', 1, 'خالص'),
    ];
    final before = compute([_apt(1)], sheet: settledUntilOct, to: '2027-02');

    expect(before.currentYear, 2027);
    expect(
      [for (final m in before.carriedFor(1)) m.period],
      ['2026-11', '2026-12'],
    );
    expect(before.carriedTotalFor(1), 20000);
    expect(before.carriedByYear(1), {2026: 20000});
    expect(before.thisYearTotalFor(1), 20000);
    expect(before.carriedTotal, 20000);

    final after = compute(
      [_apt(1)],
      sheet: settledUntilOct,
      to: '2027-02',
      txs: [
        _paid(1, const [Allocation('2026-12', 10000)]),
      ],
    );
    expect(after.carriedTotalFor(1), 10000);
    expect(after.totalFor(1), 30000);
  });

  test(
    'a written state in the sheet or a payment in the app covers a month',
    () {
      final a = compute(
        [_apt(1)],
        from: '2026-06',
        sheet: [
          _cell('2026-06', 1, 'خالص'),
          _cell('2026-07', 1, '100'),
          _cell('2026-08', 1, 'تم الدفع في يونيو'),
          _cell('2026-09', 1, ''),
        ],
        txs: [
          _paid(1, const [
            Allocation('2026-10', 10000),
            Allocation('2026-11', 4000),
          ]),
        ],
      );

      expect(
        [for (final m in a.byApartment[1]!) (m.period, m.owed)],
        [('2026-09', 10000), ('2026-11', 6000)],
      );
      expect(a.total, 16000);
    },
  );

  test('apartments out of service or exempt owe nothing', () {
    final a = compute([_apt(1, name: ''), _apt(2, feeEligible: false)]);

    expect(a.total, 0);
    expect(a.apartmentsOwing, 0);
  });

  test('a cancelled payment leaves the month unpaid', () {
    final tx = _paid(1, const [Allocation('2026-11', 10000)]);
    final a = computeArrears(
      apartments: [_apt(1)],
      ledger: LedgerLoaded([
        LedgerTx.fromMap(tx.id, {...tx.toMap(), 'voided': true, 'date': null}),
      ]),
      sheetItems: const [],
      buildingFee: 10000,
      from: '2026-11',
      to: '2026-11',
    );

    expect(a.totalFor(1), 10000);
  });
}
