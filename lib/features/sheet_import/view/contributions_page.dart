import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../auth/cubit/session_cubit.dart';
import '../data/import_item.dart';

/// Contributions as recorded in the old spreadsheet: one row per apartment
/// for the chosen month (or project), the total and the sheet's notes.
class ContributionsPage extends StatefulWidget {
  const ContributionsPage({super.key, required this.projects, this.sheetGid});

  /// Show the special-contribution sheets instead of the monthly ones.
  final bool projects;

  /// Show only this sheet, without the sheet picker.
  final String? sheetGid;

  @override
  State<ContributionsPage> createState() => _ContributionsPageState();
}

class _ContributionsPageState extends State<ContributionsPage> {
  late final Stream<List<ImportItem>> _items = context
      .read<ImportRepository>()
      .watchAll();
  String? _sheetGid;

  @override
  Widget build(BuildContext context) {
    final apartmentsState = context.watch<ApartmentsCubit>().state;
    final apartments = apartmentsState is ApartmentsLoaded
        ? apartmentsState.apartments
        : const <Apartment>[];

    return StreamBuilder<List<ImportItem>>(
      stream: _items,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('تعذر تحميل البيانات'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!
            .where((i) => (i.period == null) == widget.projects)
            .toList();
        if (all.isEmpty) {
          return const Center(child: Text('لا توجد بيانات مستوردة من الشيت'));
        }
        final sheets =
            <String, ImportItem>{
              for (final i in all) i.sheetGid: i,
            }.values.toList()..sort(
              (a, b) =>
                  (a.period ?? a.sheetName).compareTo(b.period ?? b.sheetName),
            );
        final gid = widget.sheetGid ?? _sheetGid ?? _defaultSheet(sheets, all);
        final items = all.where((i) => i.sheetGid == gid).toList()
          ..sort(
            (a, b) => a.row != b.row
                ? a.row.compareTo(b.row)
                : a.col.compareTo(b.col),
          );
        final notes = items
            .where(
              (i) =>
                  i.apartmentNumber == null &&
                  i.kind != ImportKind.total &&
                  i.text.isNotEmpty,
            )
            .toList();
        final paid = items
            .where((i) => i.kind == ImportKind.payment)
            .fold<num>(0, (sum, i) => sum + (i.amount ?? 0));
        final theme = Theme.of(context);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (widget.sheetGid == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(gid),
                      initialValue: gid,
                      decoration: InputDecoration(
                        labelText: widget.projects ? 'المشروع' : 'الشهر',
                      ),
                      items: [
                        for (final s in sheets)
                          DropdownMenuItem(
                            value: s.sheetGid,
                            child: Text(s.sheetName),
                          ),
                      ],
                      onChanged: (v) => setState(() => _sheetGid = v),
                    ),
                  ),
                if (widget.sheetGid != null) const SizedBox(height: 16),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    title: const Text('إجمالي المبالغ المدفوعة'),
                    subtitle: const Text('اضغط على أي شقة لتعديل قيمتها'),
                    trailing: Text(
                      '${_money(paid)} ج.م',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final a in apartments)
                  _ApartmentRow(
                    apartment: a,
                    sheet: items.first,
                    items: items
                        .where((i) => i.apartmentNumber == a.number)
                        .toList(),
                  ),
                if (notes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'ملاحظات الشيت (مصروفات وأرصدة)',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  for (final n in notes)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.notes, size: 20),
                      title: Text(n.text),
                      subtitle: Text(
                        n.isEdited ? '${n.kind.label} · عُدّلت' : n.kind.label,
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _editNote(context, n),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Latest sheet that has at least one paid amount, else the last one.
  String _defaultSheet(List<ImportItem> sheets, List<ImportItem> all) {
    for (final s in sheets.reversed) {
      if (all.any(
        (i) => i.sheetGid == s.sheetGid && i.kind == ImportKind.payment,
      )) {
        return s.sheetGid;
      }
    }
    return sheets.last.sheetGid;
  }
}

class _ApartmentRow extends StatelessWidget {
  const _ApartmentRow({
    required this.apartment,
    required this.sheet,
    required this.items,
  });

  final Apartment apartment;

  /// Any record of the sheet being shown; identifies the month or project.
  final ImportItem sheet;
  final List<ImportItem> items;

  Future<void> _edit(BuildContext context, ImportItem? existing) =>
      editSheetContribution(
        context,
        sheet: sheet,
        existing: existing,
        apartment: apartment,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = items.where((i) => i.col == 3).firstOrNull;
    final main = (existing?.text.isEmpty ?? true) ? null : existing;
    final rowNotes = items.where((i) => i.col > 3 && i.text.isNotEmpty);
    final isPayment = main?.kind == ImportKind.payment;
    final details = [
      ...rowNotes.map((n) => n.text),
      if (existing != null && existing.isEdited)
        existing.originalText.trim().isEmpty
            ? 'أُضيف يدويًا'
            : 'عُدّل · في الشيت: ${existing.originalText.trim()}',
    ];

    return ListTile(
      leading: CircleAvatar(child: Text('${apartment.number}')),
      title: Text(apartment.displayName ?? 'غير معروف'),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              main == null
                  ? 'لا يوجد تسجيل'
                  : isPayment
                  ? '${_money(main.amount ?? 0)} ج.م'
                  : main.text,
              textAlign: TextAlign.end,
              style: isPayment
                  ? theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.edit_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => _edit(context, existing),
    );
  }
}

/// Edits an apartment's value in a spreadsheet month or project.
Future<void> editSheetContribution(
  BuildContext context, {
  required ImportItem sheet,
  required ImportItem? existing,
  required Apartment apartment,
}) async {
  final session = context.read<SessionCubit>().state;
  if (session is! SessionActive) return;
  final repo = context.read<ImportRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _ContributionDialog(
      title: 'شقة ${apartment.number} · ${sheet.sheetName}',
      initial: existing?.text ?? '',
      monthly: sheet.period != null,
    ),
  );
  if (text == null || text == (existing?.text ?? '')) return;
  try {
    await repo.saveContribution(
      sheet: sheet,
      existing: existing,
      apartmentNumber: apartment.number,
      text: text,
      byUid: session.user.uid,
    );
    messenger.showSnackBar(const SnackBar(content: Text('تم حفظ التعديل')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('تعذر الحفظ، حاول مرة أخرى')),
    );
  }
}

Future<void> _editNote(BuildContext context, ImportItem note) async {
  final session = context.read<SessionCubit>().state;
  if (session is! SessionActive) return;
  final repo = context.read<ImportRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController(text: note.text);
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تعديل الملاحظة'),
      content: TextField(
        controller: controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          helperText: 'اتركها فارغة لإخفاء الملاحظة',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  if (text == null || text == note.text) return;
  try {
    await repo.saveNote(item: note, text: text, byUid: session.user.uid);
    messenger.showSnackBar(const SnackBar(content: Text('تم حفظ التعديل')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('تعذر الحفظ، حاول مرة أخرى')),
    );
  }
}

enum _Choice {
  amount('مبلغ مدفوع'),
  settled('خالص'),
  paidIn('تم الدفع في شهر آخر'),
  notHandedOver('لم يتسلم الوحدة'),
  other('نص آخر'),
  none('لا يوجد تسجيل');

  const _Choice(this.label);
  final String label;
}

/// Edits one apartment's contribution value. Pops the new text, where an
/// empty string means "no record".
class _ContributionDialog extends StatefulWidget {
  const _ContributionDialog({
    required this.title,
    required this.initial,
    required this.monthly,
  });

  final String title;
  final String initial;
  final bool monthly;

  @override
  State<_ContributionDialog> createState() => _ContributionDialogState();
}

class _ContributionDialogState extends State<_ContributionDialog> {
  final _formKey = GlobalKey<FormState>();
  late _Choice _choice;
  final _amount = TextEditingController();
  final _month = TextEditingController();
  final _other = TextEditingController();

  @override
  void initState() {
    super.initState();
    final text = widget.initial;
    if (text.isEmpty) {
      _choice = _Choice.amount;
    } else {
      switch (classifyContribution(text)) {
        case ImportKind.payment:
          _choice = _Choice.amount;
          _amount.text = _money(parseAmount(text)!);
        case ImportKind.settledNote:
          _choice = _Choice.settled;
        case ImportKind.paymentReference:
          _choice = _Choice.paidIn;
          _month.text = text.substring(paidInPrefix.length).trim();
        case ImportKind.notHandedOverNote:
          _choice = _Choice.notHandedOver;
        default:
          _choice = _Choice.other;
          _other.text = text;
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _month.dispose();
    _other.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final text = switch (_choice) {
      _Choice.amount => _money(parseAmount(_amount.text)!),
      _Choice.settled => settledText,
      _Choice.paidIn => '$paidInPrefix ${_month.text.trim()}',
      _Choice.notHandedOver => notHandedOverText,
      _Choice.other => _other.text.trim(),
      _Choice.none => '',
    };
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final c in _Choice.values)
        if (widget.monthly ||
            c == _Choice.amount ||
            c == _Choice.other ||
            c == _Choice.none ||
            c == _choice)
          c,
    ];
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<_Choice>(
                initialValue: _choice,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: [
                  for (final c in choices)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) => setState(() => _choice = c!),
              ),
              const SizedBox(height: 16),
              if (_choice == _Choice.amount)
                TextFormField(
                  controller: _amount,
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
                    final amount = parseAmount(v ?? '');
                    return amount == null || amount <= 0
                        ? 'اكتب مبلغًا صحيحًا'
                        : null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              if (_choice == _Choice.paidIn)
                TextFormField(
                  controller: _month,
                  decoration: const InputDecoration(
                    labelText: 'الشهر الذي تم فيه الدفع',
                    hintText: 'مثال: مايو',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'اكتب اسم الشهر' : null,
                ),
              if (_choice == _Choice.other)
                TextFormField(
                  controller: _other,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'النص'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'اكتب النص' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}

/// Everything the old spreadsheet says about one apartment, sheet by sheet.
class ApartmentSheetHistory extends StatefulWidget {
  const ApartmentSheetHistory({super.key, required this.apartmentNumber});

  final int apartmentNumber;

  @override
  State<ApartmentSheetHistory> createState() => _ApartmentSheetHistoryState();
}

class _ApartmentSheetHistoryState extends State<ApartmentSheetHistory> {
  late final Stream<List<ImportItem>> _items = context
      .read<ImportRepository>()
      .watchAll();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<ImportItem>>(
      stream: _items,
      builder: (context, snap) {
        final items =
            (snap.data ?? const <ImportItem>[])
                .where(
                  (i) =>
                      i.apartmentNumber == widget.apartmentNumber &&
                      i.text.isNotEmpty,
                )
                .toList()
              ..sort(
                (a, b) => (a.period ?? 'z${a.sheetName}').compareTo(
                  b.period ?? 'z${b.sheetName}',
                ),
              );
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 48),
            Text('الاشتراكات والمساهمات', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'كما وردت في الشيت القديم، قبل المراجعة.',
              style: theme.textTheme.bodySmall,
            ),
            for (final i in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(i.sheetName),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    i.kind == ImportKind.payment
                        ? '${_money(i.amount ?? 0)} ج.م'
                        : i.text,
                    textAlign: TextAlign.end,
                    style: i.kind == ImportKind.payment
                        ? theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _money(num value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';
