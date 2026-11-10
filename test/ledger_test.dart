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
  String? period,
  int? apt,
}) => LedgerTx(
  id: id,
  type: type,
  amount: amount,
  date: date ?? DateTime(2026, 11, 10),
  voided: voided,
  period: period,
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

    test(
      'a month subscription has one fixed id and cancelled ones do not count',
      () {
        final id = subscriptionTxId('2027-01', 7);
        expect(id, 'sub_2027-01_7');

        final paid = LedgerLoaded([
          _tx(id, TxType.subscription, 10000, period: '2027-01', apt: 7),
        ]);
        final cancelled = LedgerLoaded([
          _tx(id, TxType.subscription, 10000, voided: true),
        ]);

        expect(paid.subscriptionFor('2027-01', 7)?.amount, 10000);
        expect(paid.subscriptionFor('2027-02', 7), isNull);
        expect(cancelled.subscriptionFor('2027-01', 7), isNull);
      },
    );
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
      expect(lastOpenPeriod(DateTime(2026, 12, 15)), '2027-01');
      expect(periodLabel('2027-01'), 'يناير ٢٠٢٧');
    });
  });

  test('WhatsApp numbers use the Egypt country code', () {
    expect(whatsappNumber('01012345678'), '201012345678');
    expect(whatsappNumber('+20 101 234 5678'), '201012345678');
    expect(whatsappNumber('00201012345678'), '201012345678');
  });
}
