import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/ledger_cubit.dart';
import '../data/ledger_tx.dart';

Future<void> showAddExpense(BuildContext context) {
  final ledger = context.read<LedgerCubit>();
  final session = context.read<SessionCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: ledger),
        BlocProvider.value(value: session),
      ],
      child: const _AddExpenseSheet(),
    ),
  );
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet();

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late final String _id = context.read<LedgerCubit>().repo.newId();
  ExpenseCategory _category = ExpenseCategory.cleaning;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025, 12),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final session = context.read<SessionCubit>().state;
    if (_busy ||
        session is! SessionActive ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<LedgerCubit>().repo.addExpense(
        id: _id,
        amount: parsePiastres(_amount.text)!,
        category: _category,
        description: _description.text.trim(),
        date: _date,
        byUid: session.user.uid,
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم تسجيل المصروف')));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الحفظ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state;
    final balance = ledger is LedgerLoaded ? ledger.balance : null;
    final amount = parsePiastres(_amount.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إضافة مصروف', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: 'ج.م',
                ),
                validator: (v) {
                  final p = parsePiastres(v ?? '');
                  return p == null || p <= 0 ? 'اكتب مبلغًا صحيحًا' : null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('النوع', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in ExpenseCategory.values)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  hintText: 'مثال: نظافة السلم',
                ),
                validator: (v) =>
                    _category == ExpenseCategory.other &&
                        (v == null || v.trim().isEmpty)
                    ? 'اكتب وصفًا للمصروف'
                    : null,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('التاريخ'),
                trailing: Text(formatDate(_date)),
                onTap: _pickDate,
              ),
              if (balance != null && amount != null && amount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'سيُخصم ${formatEgp(amount)} من الرصيد. الرصيد بعد الحفظ: ${formatEgp(balance - amount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ المصروف'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
