import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../cubit/ledger_cubit.dart';
import 'add_expense_sheet.dart';
import 'tx_widgets.dart';

enum _Filter { all, income, expense }

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحركات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddExpense(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: BlocBuilder<LedgerCubit, LedgerState>(
        builder: (context, state) {
          if (state is LedgerLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is! LedgerLoaded) {
            return const Center(child: Text('تعذر تحميل السجل'));
          }
          final txs = state.txs
              .where(
                (t) => switch (_filter) {
                  _Filter.all => true,
                  _Filter.income => !t.isOutgoing,
                  _Filter.expense => t.isOutgoing,
                },
              )
              .toList();
          final children = <Widget>[];
          String? month;
          for (final t in txs) {
            final m = periodOf(t.date);
            if (m != month) {
              month = m;
              children.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    periodLabel(m),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              );
            }
            children.add(TxTile(tx: t));
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'الرصيد: ${formatEgp(state.balance)}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SegmentedButton<_Filter>(
                      segments: const [
                        ButtonSegment(value: _Filter.all, label: Text('الكل')),
                        ButtonSegment(
                          value: _Filter.income,
                          label: Text('إيرادات'),
                        ),
                        ButtonSegment(
                          value: _Filter.expense,
                          label: Text('مصروفات'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) =>
                          setState(() => _filter = s.first),
                    ),
                  ),
                  if (txs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('لا توجد حركات')),
                    ),
                  ...children,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
