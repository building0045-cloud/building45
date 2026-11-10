import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../data/import_item.dart';

/// Contributions as recorded in the old spreadsheet: one row per apartment
/// for the chosen month (or project), the total and the sheet's notes.
class ContributionsPage extends StatefulWidget {
  const ContributionsPage({super.key, required this.projects});

  /// Show the special-contribution sheets instead of the monthly ones.
  final bool projects;

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
        final gid = _sheetGid ?? _defaultSheet(sheets, all);
        final items = all.where((i) => i.sheetGid == gid).toList()
          ..sort(
            (a, b) => a.row != b.row
                ? a.row.compareTo(b.row)
                : a.col.compareTo(b.col),
          );
        final notes = items
            .where(
              (i) => i.apartmentNumber == null && i.kind != ImportKind.total,
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
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    title: const Text('إجمالي المبالغ المدفوعة'),
                    subtitle: const Text('كما ورد في الشيت، قبل المراجعة'),
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
                      title: Text(n.originalText.trim()),
                      subtitle: Text(n.kind.label),
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
  const _ApartmentRow({required this.apartment, required this.items});

  final Apartment apartment;
  final List<ImportItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final main = items.where((i) => i.col == 3).firstOrNull;
    final rowNotes = items.where((i) => i.col > 3).toList();
    final isPayment = main?.kind == ImportKind.payment;

    return ListTile(
      leading: CircleAvatar(child: Text('${apartment.number}')),
      title: Text(apartment.displayName ?? 'غير معروف'),
      subtitle: rowNotes.isEmpty
          ? null
          : Text(rowNotes.map((n) => n.originalText.trim()).join(' · ')),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          main == null
              ? 'لا يوجد تسجيل'
              : isPayment
              ? '${_money(main.amount ?? 0)} ج.م'
              : main.originalText.trim(),
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
      onTap: () => context.go('/app/apartments/${apartment.id}'),
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
                .where((i) => i.apartmentNumber == widget.apartmentNumber)
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
                        : i.originalText.trim(),
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
