import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../apartments/data/apartment.dart';
import '../../auth/cubit/session_cubit.dart';
import '../data/project.dart';

/// Creates a project, or edits [existing]. [apartments] are the ones that
/// can take part.
Future<void> showProjectForm(
  BuildContext context, {
  required List<Apartment> apartments,
  Project? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ProjectForm(apartments: apartments, existing: existing),
);

class _ProjectForm extends StatefulWidget {
  const _ProjectForm({required this.apartments, this.existing});

  final List<Apartment> apartments;
  final Project? existing;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final ProjectRepository _repo = context.read<ProjectRepository>();
  late final String _id = widget.existing?.id ?? _repo.newId();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _total = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatAmount(widget.existing!.total).replaceAll(',', ''),
  );
  late String _icon = widget.existing?.icon ?? 'savings';

  /// Participating apartments and their share (piastres).
  late Map<int, int> _shares =
      widget.existing?.shares ??
      {for (final a in widget.apartments) a.number: 0};
  final Map<int, TextEditingController> _shareFields = {};

  /// Shares edited by hand stay as typed when the total changes.
  bool _custom = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _custom = widget.existing != null;
    for (final a in _allNumbers) {
      _shareFields[a] = TextEditingController(text: _shareText(a));
    }
  }

  List<int> get _allNumbers => {
    for (final a in widget.apartments) a.number,
    ...?widget.existing?.shares.keys,
  }.toList()..sort();

  String _shareText(int apt) {
    final v = _shares[apt];
    return v == null || v == 0 ? '' : formatAmount(v).replaceAll(',', '');
  }

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    for (final c in _shareFields.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalValue => parsePiastres(_total.text) ?? 0;
  int get _sharesSum => _shares.values.fold(0, (s, v) => s + v);

  void _redistribute() {
    final split = splitEqually(_totalValue, _shares.keys.toList()..sort());
    setState(() {
      _custom = false;
      _shares = {for (final a in _shares.keys) a: split[a] ?? 0};
      for (final a in _shares.keys) {
        _shareFields[a]!.text = _shareText(a);
      }
    });
  }

  void _toggle(int apt, bool on) {
    setState(() {
      if (on) {
        _shares = {..._shares, apt: 0};
      } else {
        _shares = {..._shares}..remove(apt);
      }
    });
    if (!_custom) _redistribute();
  }

  Future<void> _save() async {
    final session = context.read<SessionCubit>().state;
    if (_busy || session is! SessionActive) return;
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'اكتب اسم المشروع');
    if (_totalValue <= 0) return setState(() => _error = 'اكتب إجمالي المشروع');
    if (_shares.isEmpty) return setState(() => _error = 'اختر الشقق المشاركة');
    if (_shares.values.any((v) => v <= 0)) {
      return setState(() => _error = 'لكل شقة مشاركة مبلغ أكبر من صفر');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.save(
        Project(
          id: _id,
          name: name,
          icon: _icon,
          total: _totalValue,
          shares: _shares,
        ),
        byUid: session.user.uid,
        previous: widget.existing,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null ? 'تم إنشاء المشروع' : 'تم حفظ المشروع',
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الحفظ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byNumber = {for (final a in widget.apartments) a.number: a};
    final diff = _totalValue - _sharesSum;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'مشروع جديد' : 'تعديل المشروع',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم المشروع',
                hintText: 'مثال: دهان السلم',
              ),
            ),
            const SizedBox(height: 16),
            Text('الأيقونة', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in projectIcons.entries)
                  ChoiceChip(
                    label: Icon(e.value, size: 22),
                    showCheckmark: false,
                    selected: _icon == e.key,
                    onSelected: (_) => setState(() => _icon = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                labelText: 'إجمالي المشروع',
                suffixText: 'ج.م',
              ),
              onChanged: (_) {
                if (_custom) {
                  setState(() {});
                } else {
                  _redistribute();
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'المشاركون (${toArabicDigits('${_shares.length}')} شقة)',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _redistribute,
                  icon: const Icon(Icons.balance),
                  label: const Text('توزيع بالتساوي'),
                ),
              ],
            ),
            Text(
              diff == 0
                  ? 'مجموع الحصص يساوي الإجمالي.'
                  : 'مجموع الحصص ${formatEgp(_sharesSum)}، '
                        '${diff > 0 ? 'أقل' : 'أكثر'} من الإجمالي بـ ${formatEgp(diff.abs())}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: diff == 0
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            for (final n in _allNumbers)
              Row(
                children: [
                  Checkbox(
                    value: _shares.containsKey(n),
                    onChanged: (v) => _toggle(n, v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'شقة $n · ${byNumber[n]?.displayName ?? 'غير معروف'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _shareFields[n],
                      enabled: _shares.containsKey(n),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: 'ج.م',
                      ),
                      onChanged: (v) => setState(() {
                        _custom = true;
                        _shares = {..._shares, n: parsePiastres(v) ?? 0};
                      }),
                    ),
                  ),
                ],
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
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(
                widget.existing == null ? 'إنشاء المشروع' : 'حفظ التعديل',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
