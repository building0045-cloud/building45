import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../apartments/data/apartment.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/data/ledger_tx.dart';
import '../../sheet_import/data/import_item.dart';

/// Records a subscription payment covering one or more months, or edits
/// [existing].
Future<void> showPaymentSheet(
  BuildContext context, {
  required Apartment apartment,
  LedgerTx? existing,
  String? startPeriod,
}) {
  final ledger = context.read<LedgerCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: ledger,
      child: _PaymentSheet(
        apartment: apartment,
        existing: existing,
        startPeriod: startPeriod,
      ),
    ),
  );
}

/// All months that can be paid, oldest first.
List<String> _openPeriods() {
  final last = lastOpenPeriod();
  return [
    for (var p = firstPeriod; p.compareTo(last) <= 0; p = shiftPeriod(p, 1)) p,
  ];
}

class _Payer {
  const _Payer(this.name, this.kind);
  final String name;
  final String kind;
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.apartment,
    required this.existing,
    required this.startPeriod,
  });

  final Apartment apartment;
  final LedgerTx? existing;
  final String? startPeriod;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final LedgerRepository _repo = context.read<LedgerCubit>().repo;
  late final Stream<int> _fee = _repo.watchMonthlyFee();
  late final Stream<List<ImportItem>> _sheet = context
      .read<ImportRepository>()
      .watchAll();
  late final String _id = widget.existing?.id ?? _repo.newId();

  late final List<_Payer> _payers = [
    for (final c in widget.apartment.contacts)
      if (c.name.trim().isNotEmpty) _Payer(c.name.trim(), c.kind.name),
  ];
  late int _payer = _initialPayer();
  final _otherPayer = TextEditingController();
  final _amount = TextEditingController();
  bool _amountEdited = false;
  String? _start;
  late int _count = widget.existing?.allocations.length ?? 1;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _busy = false;
  String? _error;

  /// Index into [_payers]; `_payers.length` means "someone else".
  int _initialPayer() {
    final e = widget.existing;
    if (e != null && e.payerName.isNotEmpty) {
      final i = _payers.indexWhere((p) => p.name == e.payerName);
      if (i >= 0) return i;
      _otherPayer.text = e.payerName;
      return _payers.length;
    }
    final owner = _payers.indexWhere((p) => p.kind == ContactKind.owner.name);
    return owner >= 0 ? owner : (_payers.isEmpty ? 0 : 0);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = formatAmount(e.amount).replaceAll(',', '');
      _amountEdited = true;
    }
  }

  @override
  void dispose() {
    _otherPayer.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Months that another payment, or the old spreadsheet, already covers.
  Set<String> _blocked(LedgerLoaded? ledger, List<ImportItem> sheet) => {
    ...?ledger?.paidPeriods(
      widget.apartment.number,
      exceptTxId: widget.existing?.id,
    ),
    for (final i in sheet)
      if (i.period != null &&
          i.apartmentNumber == widget.apartment.number &&
          i.col == 3 &&
          i.text.isNotEmpty &&
          const {
            ImportKind.payment,
            ImportKind.settledNote,
            ImportKind.paymentReference,
          }.contains(i.kind))
        i.period!,
  };

  String _defaultStart(Set<String> blocked, List<String> open) {
    final e = widget.existing;
    if (e != null && e.periods.isNotEmpty) return e.periods.first;
    final wanted = widget.startPeriod ?? currentPeriod();
    return open.firstWhere(
      (p) => p.compareTo(wanted) >= 0 && !blocked.contains(p),
      orElse: () => wanted,
    );
  }

  /// Consecutive free months from [start], at most [prepayMonths].
  int _maxCount(String start, Set<String> blocked) {
    var n = 0;
    final last = lastOpenPeriod();
    for (
      var p = start;
      n < prepayMonths && p.compareTo(last) <= 0 && !blocked.contains(p);
      p = shiftPeriod(p, 1)
    ) {
      n++;
    }
    return n;
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

  Future<void> _save(List<Allocation> allocations) async {
    final session = context.read<SessionCubit>().state;
    if (_busy || session is! SessionActive) return;
    final other = _payer >= _payers.length;
    final payerName = other ? _otherPayer.text.trim() : _payers[_payer].name;
    final payerKind = other ? '' : _payers[_payer].kind;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.savePayment(
        id: _id,
        apartmentNumber: widget.apartment.number,
        allocations: allocations,
        date: _date,
        payerName: payerName,
        payerKind: payerKind,
        byUid: session.user.uid,
        byName: session.member.name,
        previous: widget.existing,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null ? 'تم تسجيل الدفعة' : 'تم تعديل الدفعة',
          ),
        ),
      );
    } on MonthAlreadyPaid {
      if (mounted) {
        setState(
          () => _error = 'أحد الشهور المختارة مدفوع بالفعل، اختر شهورًا أخرى',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الحفظ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledgerState = context.watch<LedgerCubit>().state;
    final ledger = ledgerState is LedgerLoaded ? ledgerState : null;
    return StreamBuilder<int>(
      stream: _fee,
      builder: (context, feeSnap) => StreamBuilder<List<ImportItem>>(
        stream: _sheet,
        builder: (context, sheetSnap) {
          if (!feeSnap.hasData || !sheetSnap.hasData || ledger == null) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _form(context, feeSnap.data!, ledger, sheetSnap.data!);
        },
      ),
    );
  }

  Widget _form(
    BuildContext context,
    int fee,
    LedgerLoaded ledger,
    List<ImportItem> sheet,
  ) {
    final theme = Theme.of(context);
    final open = _openPeriods();
    final blocked = _blocked(ledger, sheet);
    final start = _start ??= _defaultStart(blocked, open);
    final maxCount = _maxCount(start, blocked);
    if (_count > maxCount && maxCount > 0) _count = maxCount;
    final periods = [for (var i = 0; i < _count; i++) shiftPeriod(start, i)];
    if (!_amountEdited) {
      _amount.text = formatAmount(_count * fee).replaceAll(',', '');
    }
    final total = parsePiastres(_amount.text) ?? 0;
    final split = maxCount == 0 ? null : splitPayment(total, periods, fee);
    final previousCounted = widget.existing != null && !widget.existing!.voided
        ? widget.existing!.amount
        : 0;
    final otherPayer = _payer >= _payers.length;
    final payerOk = !otherPayer || _otherPayer.text.trim().isNotEmpty;

    String? amountError;
    if (maxCount == 0) {
      amountError = null;
    } else if (total <= 0) {
      amountError = 'اكتب المبلغ';
    } else if (total > _count * fee) {
      amountError = 'المبلغ أكبر من ${formatEgp(_count * fee)}؛ زِد عدد الشهور';
    } else if (split == null) {
      amountError =
          'المبلغ لا يغطي ${toArabicDigits('$_count')} شهور؛ قلّل عدد الشهور';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'تسجيل دفعة اشتراك · شقة ${widget.apartment.number}'
                  : 'تعديل دفعة · شقة ${widget.apartment.number}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('من دفع؟', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, p) in _payers.indexed)
                  ChoiceChip(
                    label: Text(
                      '${p.name} (${ContactKind.parse(p.kind).label})',
                    ),
                    selected: _payer == i,
                    onSelected: (_) => setState(() => _payer = i),
                  ),
                ChoiceChip(
                  label: const Text('شخص آخر'),
                  selected: otherPayer,
                  onSelected: (_) => setState(() => _payer = _payers.length),
                ),
              ],
            ),
            if (otherPayer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherPayer,
                decoration: const InputDecoration(labelText: 'اسم من دفع'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: start,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'من شهر'),
              items: [
                for (final p in open)
                  DropdownMenuItem(
                    value: p,
                    enabled: !blocked.contains(p),
                    child: Text(
                      blocked.contains(p)
                          ? '${periodLabel(p)} (مدفوع)'
                          : periodLabel(p),
                      style: blocked.contains(p)
                          ? TextStyle(color: theme.colorScheme.outline)
                          : null,
                    ),
                  ),
              ],
              onChanged: (p) => setState(() {
                _start = p;
                _count = 1;
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('عدد الشهور', style: theme.textTheme.titleMedium),
                ),
                IconButton.outlined(
                  tooltip: 'شهر أقل',
                  onPressed: _count > 1 ? () => setState(() => _count--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    toArabicDigits('$_count'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'شهر أكثر',
                  onPressed: _count < maxCount
                      ? () => setState(() => _count++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (maxCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'هذا الشهر مدفوع بالفعل، اختر شهرًا آخر.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else if (_count == maxCount && maxCount < prepayMonths)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'الشهر التالي مدفوع أو خارج المدة المسموحة.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                labelText: 'المبلغ المستلم',
                suffixText: 'ج.م',
                helperText:
                    'الاشتراك ${formatEgp(fee)} × ${toArabicDigits('$_count')} = ${formatEgp(fee * _count)}',
                errorText: amountError,
              ),
              onChanged: (_) => setState(() => _amountEdited = true),
            ),
            if (split != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in split)
                    Chip(
                      label: Text(
                        '${periodLabel(a.period)}: ${formatAmount(a.amount)}'
                        '${a.amount < fee ? ' (جزئي)' : ''}',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('تاريخ الاستلام'),
              trailing: Text(formatDate(_date)),
              onTap: _pickDate,
            ),
            if (split != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'سيُسجَّل ${formatEgp(total)}'
                  '${otherPayer ? (_otherPayer.text.trim().isEmpty ? '' : ' من ${_otherPayer.text.trim()}') : ' من ${_payers[_payer].name} (${ContactKind.parse(_payers[_payer].kind).label})'}'
                  ' لشقة ${widget.apartment.number} عن ${describeMonths(periods)}.\n'
                  'الرصيد بعد الحفظ: ${formatEgp(ledger.balance - previousCounted + total)}',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: split != null && payerOk && !_busy
                  ? () => _save(split)
                  : null,
              icon: const Icon(Icons.check),
              label: Text(
                widget.existing == null ? 'حفظ الدفعة' : 'حفظ التعديل',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
