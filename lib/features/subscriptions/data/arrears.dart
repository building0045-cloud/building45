import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/periods.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../sheet_import/data/import_item.dart';

/// Subscriptions are treated as settled up to the month before this one.
const defaultDuesFrom = '2026-06';

class UnpaidMonth {
  const UnpaidMonth(this.period, this.owed);
  final String period;

  /// Piastres still owed for the month.
  final int owed;
}

class Arrears {
  const Arrears(this.byApartment, {required this.from, required this.to});

  final Map<int, List<UnpaidMonth>> byApartment;
  final String from;
  final String to;

  int totalFor(int apartmentNumber) =>
      (byApartment[apartmentNumber] ?? const []).fold(0, (s, m) => s + m.owed);

  int get total => byApartment.keys.fold(0, (s, n) => s + totalFor(n));

  int get apartmentsOwing =>
      byApartment.values.where((months) => months.isNotEmpty).length;
}

/// Unpaid subscription months from [from] through [to] for apartments in
/// service that pay the subscription.
///
/// A month is unpaid when nothing at all is recorded for it: no payment in
/// the app and an empty cell in the old spreadsheet. Any written state in
/// the spreadsheet (an amount, «خالص», «تم الدفع في…», a note) counts as
/// handled. A partial payment in the app owes the rest of the fee.
Arrears computeArrears({
  required List<Apartment> apartments,
  required LedgerLoaded ledger,
  required List<ImportItem> sheetItems,
  required int fee,
  String from = defaultDuesFrom,
  String? to,
}) {
  final last = to ?? currentPeriod();
  final periods = [
    for (var p = from; p.compareTo(last) <= 0; p = shiftPeriod(p, 1)) p,
  ];
  final sheetText = <String, String>{
    for (final i in sheetItems)
      if (i.period != null && i.apartmentNumber != null && i.col == 3)
        '${i.period}_${i.apartmentNumber}': i.text,
  };
  final result = <int, List<UnpaidMonth>>{};
  for (final a in apartments) {
    if (!a.inService || !a.feeEligible) continue;
    final months = <UnpaidMonth>[];
    for (final p in periods) {
      final paid = ledger.subscriptionFor(p, a.number);
      if (paid != null) {
        if (paid.amount < fee) months.add(UnpaidMonth(p, fee - paid.amount));
        continue;
      }
      if ((sheetText['${p}_${a.number}'] ?? '').isNotEmpty) continue;
      months.add(UnpaidMonth(p, fee));
    }
    result[a.number] = months;
  }
  return Arrears(result, from: from, to: last);
}

/// Rebuilds with the current arrears, or null while loading.
class ArrearsBuilder extends StatefulWidget {
  const ArrearsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Arrears? arrears) builder;

  @override
  State<ArrearsBuilder> createState() => _ArrearsBuilderState();
}

class _ArrearsBuilderState extends State<ArrearsBuilder> {
  late final Stream<List<ImportItem>> _sheet = context
      .read<ImportRepository>()
      .watchAll();
  late final Stream<int> _fee = context
      .read<LedgerCubit>()
      .repo
      .watchMonthlyFee();

  @override
  Widget build(BuildContext context) {
    final apartments = context.watch<ApartmentsCubit>().state;
    final ledger = context.watch<LedgerCubit>().state;
    return StreamBuilder<List<ImportItem>>(
      stream: _sheet,
      builder: (context, sheet) => StreamBuilder<int>(
        stream: _fee,
        builder: (context, fee) {
          if (apartments is! ApartmentsLoaded ||
              ledger is! LedgerLoaded ||
              !sheet.hasData) {
            return widget.builder(context, null);
          }
          return widget.builder(
            context,
            computeArrears(
              apartments: apartments.apartments,
              ledger: ledger,
              sheetItems: sheet.data!,
              fee: fee.data ?? defaultMonthlyFee,
            ),
          );
        },
      ),
    );
  }
}
