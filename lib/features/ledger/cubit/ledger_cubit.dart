import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ledger_repository.dart';
import '../data/ledger_tx.dart';

sealed class LedgerState extends Equatable {
  const LedgerState();
  @override
  List<Object?> get props => [];
}

final class LedgerLoading extends LedgerState {
  const LedgerLoading();
}

final class LedgerFailure extends LedgerState {
  const LedgerFailure();
}

final class LedgerLoaded extends LedgerState {
  LedgerLoaded(this.txs) : balance = balanceOf(txs);

  /// Newest first.
  final List<LedgerTx> txs;
  final int balance;

  Iterable<LedgerTx> _inPeriod(String period) => txs.where(
    (t) =>
        !t.voided &&
        t.type != TxType.opening &&
        '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}' == period,
  );

  int incomeIn(String period) =>
      _inPeriod(period)
          .where((t) => !t.isOutgoing)
          .fold(0, (s, t) => s + t.amount);
  int expensesIn(String period) =>
      _inPeriod(period)
          .where((t) => t.isOutgoing)
          .fold(0, (s, t) => s + t.amount);

  /// The counted payment covering [apartmentNumber]'s [period], and the
  /// share of it for that month.
  ({LedgerTx tx, int amount})? subscriptionFor(
    String period,
    int apartmentNumber,
  ) {
    for (final t in txs) {
      if (t.voided ||
          t.type != TxType.subscription ||
          t.apartmentNumber != apartmentNumber) {
        continue;
      }
      for (final a in t.allocations) {
        if (a.period == period) return (tx: t, amount: a.amount);
      }
    }
    return null;
  }

  /// Months of [apartmentNumber] covered by counted payments other than
  /// [exceptTxId].
  Set<String> paidPeriods(int apartmentNumber, {String? exceptTxId}) => {
    for (final t in txs)
      if (!t.voided &&
          t.type == TxType.subscription &&
          t.apartmentNumber == apartmentNumber &&
          t.id != exceptTxId)
        ...t.periods,
  };

  @override
  List<Object?> get props => [txs];
}

class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this.repo) : super(const LedgerLoading()) {
    _sub = repo.watchAll().listen(
      (txs) => emit(LedgerLoaded(txs)),
      onError: (_) => emit(const LedgerFailure()),
    );
  }

  final LedgerRepository repo;
  late final StreamSubscription<List<LedgerTx>> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
