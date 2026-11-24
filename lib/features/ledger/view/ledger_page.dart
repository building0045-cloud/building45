import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../cubit/ledger_cubit.dart';
import '../data/ledger_tx.dart';
import 'add_expense_sheet.dart';
import 'tx_widgets.dart';

enum _Filter { all, income, expense }

class LedgerPage extends StatefulWidget {
  /// [type] is `income` or `expense`; anything else shows everything.
  /// [months] are `yyyy-MM` periods; null starts on the current month.
  const LedgerPage({super.key, this.type, this.months});

  final String? type;
  final Set<String>? months;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late _Filter _filter = switch (widget.type) {
    'income' => _Filter.income,
    'expense' => _Filter.expense,
    _ => _Filter.all,
  };

  /// Empty means every month.
  late Set<String> _months = widget.months ?? {currentPeriod()};

  Future<void> _pickMonths() async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MonthPickerSheet(initial: _months),
    );
    if (picked != null) setState(() => _months = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحركات')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: expenseActionColor,
        foregroundColor: Colors.white,
        onPressed: () => showAddExpense(context),
        icon: const ExpenseIcon(),
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
                (t) =>
                    (_months.isEmpty || _months.contains(periodOf(t.date))) &&
                    switch (_filter) {
                      _Filter.all => true,
                      // The opening balance is not income of any month.
                      _Filter.income =>
                        !t.isOutgoing && t.type != TxType.opening,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ActionChip(
                        avatar: const Icon(Icons.calendar_month_outlined),
                        label: Text(describeSelection(_months)),
                        onPressed: _pickMonths,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        if (_filter != _Filter.expense)
                          Expanded(
                            child: _PeriodTotal(
                              label: 'الإيرادات',
                              value: state.incomeInPeriods(_months),
                              color: incomeColor,
                            ),
                          ),
                        if (_filter == _Filter.all) const SizedBox(width: 12),
                        if (_filter != _Filter.income)
                          Expanded(
                            child: _PeriodTotal(
                              label: 'المصروفات',
                              value: state.expensesInPeriods(_months),
                              color: expenseColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (txs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('لا توجد حركات في هذه الفترة')),
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

class _PeriodTotal extends StatelessWidget {
  const _PeriodTotal({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              formatEgp(value),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks months by year: single months, several months (also across
/// years), a whole year, or every month.
class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late final Set<String> _selected = {...widget.initial};
  final int _firstYear = periodYear(firstPeriod);
  final int _lastYear = periodYear(currentPeriod());
  late int _year = widget.initial.isEmpty
      ? _lastYear
      : (widget.initial.map(periodYear).reduce((a, b) => a > b ? a : b))
            .clamp(_firstYear, _lastYear);

  String _period(int month) => '$_year-${month.toString().padLeft(2, '0')}';

  List<String> get _yearMonths => [for (var m = 1; m <= 12; m++) _period(m)];

  bool get _wholeYear => _yearMonths.every(_selected.contains);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'السنة السابقة',
                  onPressed: _year > _firstYear
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    toArabicDigits('$_year'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'السنة التالية',
                  onPressed: _year < _lastYear
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [
                for (var m = 1; m <= 12; m++)
                  FilterChip(
                    showCheckmark: false,
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        arabicMonths[m - 1],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: _selected.contains(_period(m)),
                    onSelected: (on) => setState(
                      () => on
                          ? _selected.add(_period(m))
                          : _selected.remove(_period(m)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('السنة كاملة (${toArabicDigits('$_year')})'),
              value: _wholeYear,
              onChanged: (on) => setState(
                () => on
                    ? _selected.addAll(_yearMonths)
                    : _selected.removeAll(_yearMonths),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop({currentPeriod()}),
                    child: const Text('هذا الشهر'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(<String>{}),
                    child: const Text('كل الفترات'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({..._selected}),
              child: Text(
                _selected.isEmpty
                    ? 'تطبيق (كل الفترات)'
                    : 'تطبيق: ${describeSelection(_selected)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
