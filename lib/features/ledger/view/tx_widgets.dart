import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../subscriptions/view/payment_sheet.dart';
import '../cubit/ledger_cubit.dart';
import '../data/ledger_repository.dart';
import '../data/ledger_tx.dart';

const incomeColor = Color(0xFF16A34A);
const expenseColor = Color(0xFFDC2626);

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx});

  final LedgerTx tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tx.voided
        ? theme.colorScheme.outline
        : tx.isOutgoing
        ? expenseColor
        : incomeColor;
    final strike = tx.voided ? TextDecoration.lineThrough : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(tx.icon, size: 20),
      ),
      title: Text(
        tx.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(decoration: strike),
      ),
      subtitle: Text(
        [
          formatDate(tx.date),
          tx.type.label,
          if (tx.voided) 'ملغاة',
        ].join(' · '),
      ),
      trailing: Text(
        '${tx.isOutgoing ? '-' : '+'}${formatAmount(tx.amount)}',
        textDirection: TextDirection.ltr,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          decoration: strike,
        ),
      ),
      onTap: () => showTxActions(context, tx),
    );
  }
}

/// Details of an entry with edit-amount and cancel/restore actions.
Future<void> showTxActions(BuildContext context, LedgerTx tx) async {
  final session = context.read<SessionCubit>().state;
  if (session is! SessionActive) return;
  final repo = context.read<LedgerCubit>().repo;
  final messenger = ScaffoldMessenger.of(context);
  final canEdit = tx.type != TxType.opening || session.member.isAdmin;

  Future<void> run(Future<void> Function() action, String done) async {
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on MonthAlreadyPaid {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لا يمكن الاسترجاع: أحد الشهور دُفع بدفعة أخرى'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر الحفظ، حاول مرة أخرى')),
      );
    }
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              tx.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '${tx.type.label} · ${formatDate(tx.date)}${tx.voided ? ' · ملغاة' : ''}',
            ),
            trailing: Text(
              formatEgp(tx.amount),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (tx.type == TxType.subscription && tx.periods.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: Text('يغطي: ${describeMonths(tx.periods)}'),
              subtitle: tx.payerName.isEmpty
                  ? null
                  : Text('دفعها: ${tx.payerName}'),
            ),
          if (canEdit && !tx.voided)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                tx.type == TxType.subscription
                    ? 'تعديل الدفعة'
                    : 'تعديل المبلغ',
              ),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
          if (canEdit && tx.type != TxType.opening)
            ListTile(
              leading: Icon(tx.voided ? Icons.restore : Icons.block),
              title: Text(tx.voided ? 'استرجاع الحركة' : 'إلغاء الحركة'),
              subtitle: const Text('تبقى في السجل للمراجعة'),
              onTap: () =>
                  Navigator.of(context).pop(tx.voided ? 'restore' : 'void'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final uid = session.user.uid;
  switch (choice) {
    case 'edit' when tx.type == TxType.subscription:
      final apartments = context.read<ApartmentsCubit>().state;
      final apartment = apartments is ApartmentsLoaded
          ? apartments.byId('${tx.apartmentNumber}')
          : null;
      if (apartment != null) {
        await showPaymentSheet(context, apartment: apartment, existing: tx);
      }
    case 'edit':
      final amount = await askAmount(
        context,
        title: 'تعديل المبلغ',
        initial: tx.amount,
      );
      if (amount != null && amount != tx.amount) {
        await run(
          () => repo.updateAmount(tx, amount, byUid: uid),
          'تم تعديل المبلغ',
        );
      }
    case 'void':
      await run(() => repo.setVoided(tx, true, byUid: uid), 'تم إلغاء الحركة');
    case 'restore':
      await run(
        () => repo.setVoided(tx, false, byUid: uid),
        'تم استرجاع الحركة',
      );
  }
}

/// Asks for an amount in EGP; returns piastres.
Future<int?> askAmount(
  BuildContext context, {
  required String title,
  int? initial,
  String? message,
}) {
  final controller = TextEditingController(
    text: initial == null ? '' : formatAmount(initial).replaceAll(',', ''),
  );
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (context) {
      void submit() {
        if (formKey.currentState!.validate()) {
          Navigator.of(context).pop(parsePiastres(controller.text));
        }
      }

      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: 'ج.م',
                ),
                validator: (v) {
                  final p = parsePiastres(v ?? '');
                  return p == null || p <= 0 ? 'اكتب مبلغًا صحيحًا' : null;
                },
                onFieldSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(onPressed: submit, child: const Text('حفظ')),
        ],
      );
    },
  );
}
