import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/ledger/cubit/ledger_cubit.dart';
import 'package:home_system/features/ledger/data/ledger_tx.dart';
import 'package:home_system/features/projects/data/project.dart';

void main() {
  group('splitEqually', () {
    test('divides the total in whole pounds and keeps the sum exact', () {
      final shares = splitEqually(100000, [4, 5, 6]);

      expect(shares, {4: 33400, 5: 33300, 6: 33300});
      expect(shares.values.fold(0, (s, v) => s + v), 100000);
    });

    test('puts leftover piastres on the first apartment', () {
      final shares = splitEqually(100050, [1, 2]);

      expect(shares, {1: 50050, 2: 50000});
    });

    test('returns nothing without apartments or a total', () {
      expect(splitEqually(1000, const []), isEmpty);
      expect(splitEqually(0, [1, 2]), isEmpty);
    });
  });

  test('a project round-trips through its stored form', () {
    const project = Project(
      id: 'p1',
      name: 'دهان السلم',
      icon: 'paint',
      total: 60000,
      shares: {4: 30000, 7: 30000},
    );

    expect(Project.fromMap('p1', project.toMap()), project);
    expect(projectIcon('paint'), projectIcons['paint']);
    expect(projectIcon('missing'), projectIcons['savings']);
  });

  test('project contributions count once and cancelled ones do not', () {
    LedgerTx pay(
      int apt,
      int amount, {
      bool voided = false,
      String project = 'p1',
    }) => LedgerTx(
      id: 'prj_${project}_$apt',
      type: TxType.project,
      amount: amount,
      date: DateTime(2026, 11, 10),
      apartmentNumber: apt,
      projectId: project,
      voided: voided,
    );
    final state = LedgerLoaded([
      pay(4, 30000),
      pay(7, 30000, voided: true),
      pay(4, 5000, project: 'p2'),
    ]);

    expect(state.projectCollected('p1'), 30000);
    expect(state.projectPayment('p1', 4)?.amount, 30000);
    expect(state.projectPayment('p1', 7), isNull);
    expect(state.balance, 35000);
  });
}
