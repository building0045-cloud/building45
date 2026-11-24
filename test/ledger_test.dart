import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/core/money.dart';
import 'package:home_system/core/periods.dart';
import 'package:home_system/core/phone.dart';
import 'package:home_system/features/ledger/cubit/ledger_cubit.dart';
import 'package:home_system/features/ledger/data/ledger_repository.dart';
import 'package:home_system/features/ledger/data/ledger_tx.dart';

LedgerTx _tx(
  String id,
  TxType type,
  int amount, {
  bool voided = false,
  DateTime? date,
  List<Allocation> allocations = const [],
  int? apt,
}) => LedgerTx(
  id: id,
  type: type,
  amount: amount,
  date: date ?? DateTime(2026, 11, 10),
  voided: voided,
  allocations: allocations,
  apartmentNumber: apt,
);

void main() {
  group('balance', () {
    test('opening plus income minus expenses, ignoring cancelled entries', () {
      final txs = [
        _tx('o', TxType.opening, 285000),
        _tx('s', TxType.subscription, 10000),
        _tx('e', TxType.expense, 25000),
        _tx('x', TxType.expense, 99900, voided: true),
      ];

      expect(balanceOf(txs), 285000 + 10000 - 25000);
    });

    test('month totals exclude the opening balance and other months', () {
      final state = LedgerLoaded([
        _tx('o', TxType.opening, 285000),
        _tx('s', TxType.subscription, 10000),
        _tx('e', TxType.expense, 25000),
        _tx('old', TxType.expense, 5000, date: DateTime(2026, 10, 30)),
      ]);

      expect(state.incomeIn('2026-11'), 10000);
      expect(state.expensesIn('2026-11'), 25000);
      expect(state.expensesIn('2026-10'), 5000);
    });

    test('a single month payment has one fixed id', () {
      expect(subscriptionTxId('2027-01', 7), 'sub_2027-01_7');
    });
  });

  group('multi-month payments', () {
    final sixMonths = [for (var i = 0; i < 6; i++) shiftPeriod('2027-01', i)];

    test('600 for six months counts once in the balance and 100 per month', () {
      final payment = _tx(
        'r1',
        TxType.subscription,
        60000,
        apt: 4,
        allocations: splitPayment(60000, sixMonths, 10000)!,
      );
      final state = LedgerLoaded([_tx('o', TxType.opening, 285000), payment]);

      expect(state.balance, 285000 + 60000);
      expect(state.incomeIn('2026-11'), 60000);
      for (final p in sixMonths) {
        expect(state.subscriptionFor(p, 4)?.amount, 10000);
      }
      expect(state.subscriptionFor('2027-07', 4), isNull);
      expect(state.subscriptionFor('2027-01', 5), isNull);
      expect(state.paidPeriods(4), sixMonths.toSet());
      expect(state.paidPeriods(4, exceptTxId: 'r1'), isEmpty);
    });

    test('cancelling the payment reopens all its months', () {
      final state = LedgerLoaded([
        _tx(
          'r1',
          TxType.subscription,
          60000,
          apt: 4,
          voided: true,
          allocations: splitPayment(60000, sixMonths, 10000)!,
        ),
      ]);

      expect(state.balance, 0);
      expect(state.paidPeriods(4), isEmpty);
      expect(state.subscriptionFor('2027-03', 4), isNull);
    });

    test('a partial amount leaves the last month partial', () {
      final split = splitPayment(55000, sixMonths, 10000)!;

      expect(
        [for (final a in split) a.amount],
        [10000, 10000, 10000, 10000, 10000, 5000],
      );
    });

    test('amounts that do not fit the months are rejected', () {
      expect(splitPayment(70000, sixMonths, 10000), isNull);
      expect(splitPayment(50000, sixMonths, 10000), isNull);
      expect(splitPayment(0, sixMonths, 10000), isNull);
      expect(splitPayment(10000, const [], 10000), isNull);
    });

    test('old single-month entries without allocations still count', () {
      final tx = LedgerTx.fromMap('sub_2026-11_7', {
        'type': 'subscription',
        'amount': 10000,
        'period': '2026-11',
        'apartmentNumber': 7,
      });

      expect(tx.allocations, [const Allocation('2026-11', 10000)]);
      expect(LedgerLoaded([tx]).subscriptionFor('2026-11', 7)?.amount, 10000);
    });

    test('describes the months covered', () {
      expect(describeMonths(['2027-01']), 'يناير ٢٠٢٧');
      expect(
        describeMonths(['2027-01', '2027-02']),
        'شهرين (يناير ٢٠٢٧ – فبراير ٢٠٢٧)',
      );
      expect(describeMonths(sixMonths), '٦ شهور (يناير ٢٠٢٧ – يونيو ٢٠٢٧)');
    });
  });

  group('money', () {
    test('parses and formats Egyptian pounds as piastres', () {
      expect(parsePiastres('100'), 10000);
      expect(parsePiastres('٢٥٠'), 25000);
      expect(parsePiastres('12.5'), 1250);
      expect(parsePiastres('2,850'), 285000);
      expect(parsePiastres('abc'), isNull);
      expect(formatAmount(285000), '2,850');
      expect(formatAmount(1250), '12.50');
      expect(formatEgp(-5000), '-50 ج.م');
    });
  });

  group('periods', () {
    test('cross year boundaries', () {
      expect(shiftPeriod('2026-12', 1), '2027-01');
      expect(shiftPeriod('2027-01', -1), '2026-12');
      expect(lastOpenPeriod(DateTime(2026, 12, 15)), '2027-12');
      expect(periodLabel('2027-01'), 'يناير ٢٠٢٧');
    });
  });

  test('WhatsApp numbers use the Egypt country code', () {
    expect(whatsappNumber('01012345678'), '201012345678');
    expect(whatsappNumber('+20 101 234 5678'), '201012345678');
    expect(whatsappNumber('00201012345678'), '201012345678');
  });

  test('an entry keeps who recorded it', () {
    final tx = LedgerTx(
      id: 'e1',
      type: TxType.expense,
      amount: 25000,
      date: DateTime(2026, 11, 10),
      createdBy: 'u1',
      createdByName: 'وائل',
    );

    final back = LedgerTx.fromMap('e1', {...tx.toMap(), 'date': null});

    expect(back.createdBy, 'u1');
    expect(back.createdByName, 'وائل');
  });

  group('period filter', () {
    final state = LedgerLoaded([
      _tx('o', TxType.opening, 850000),
      _tx('nov', TxType.subscription, 10000),
      _tx('novE', TxType.expense, 25000),
      _tx('oct', TxType.subscription, 20000, date: DateTime(2026, 10, 5)),
      _tx('dec25', TxType.expense, 7000, date: DateTime(2025, 12, 20)),
      _tx('void', TxType.subscription, 99900, voided: true),
    ]);

    test('totals cover the chosen months across years, without opening', () {
      expect(state.incomeInPeriods({'2026-11', '2026-10'}), 30000);
      expect(state.expensesInPeriods({'2026-11', '2025-12'}), 32000);
      expect(state.incomeInPeriods({'2026-09'}), 0);
    });

    test('an empty selection covers every month', () {
      expect(state.incomeInPeriods({}), 30000);
      expect(state.expensesInPeriods({}), 32000);
    });

    test('selection labels', () {
      expect(describeSelection({}), 'كل الفترات');
      expect(describeSelection({'2026-11'}), periodLabel('2026-11'));
      expect(
        describeSelection({
          for (var m = 1; m <= 12; m++) shiftPeriod('2026-01', m - 1),
        }),
        'سنة ٢٠٢٦',
      );
      expect(
        describeSelection({'2026-11', '2026-09', '2026-10'}),
        '٣ شهور (${periodLabel('2026-09')} – ${periodLabel('2026-11')})',
      );
      expect(describeSelection({'2026-01', '2025-12'}), startsWith('شهرين'));
    });
  });

  test('balance by holder splits the balance by who holds the money', () {
    LedgerTx by(
      String id,
      TxType type,
      int amount,
      String uid, {
      bool voided = false,
    }) => LedgerTx(
      id: id,
      type: type,
      amount: amount,
      date: DateTime(2026, 11, 10),
      createdBy: uid,
      voided: voided,
    );
    final txs = [
      by('o1', TxType.opening, 180000, 'm'),
      by('o2', TxType.opening, 670000, 'w'),
      by('s1', TxType.subscription, 30000, 'm'),
      by('s2', TxType.subscription, 70000, 'w'),
      by('e1', TxType.expense, 25000, 'w'),
      by('x', TxType.expense, 99900, 'm', voided: true),
    ];

    final held = balanceByHolder(txs);

    expect(held, {'m': 210000, 'w': 715000});
    expect(held.values.fold(0, (s, v) => s + v), balanceOf(txs));
  });
}
