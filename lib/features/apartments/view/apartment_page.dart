import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/phone.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../sheet_import/view/contributions_page.dart';
import '../cubit/apartments_cubit.dart';
import '../data/apartment.dart';
import 'apartments_page.dart' show whatsappGreen;

/// Apartment profile and editor. Financial sections are added with the
/// ledger; this page currently covers the apartment's own details.
class ApartmentPage extends StatelessWidget {
  const ApartmentPage({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApartmentsCubit, ApartmentsState>(
      builder: (context, state) {
        final apartment = state is ApartmentsLoaded
            ? state.byId(apartmentId)
            : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(apartment == null ? 'شقة' : 'شقة ${apartment.number}'),
          ),
          body: switch (state) {
            ApartmentsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ApartmentsFailure() => const Center(
              child: Text('تعذر تحميل بيانات الشقة'),
            ),
            ApartmentsLoaded() =>
              apartment == null
                  ? const Center(child: Text('الشقة غير موجودة'))
                  : _ApartmentForm(
                      key: ValueKey(apartment),
                      apartment: apartment,
                    ),
          },
        );
      },
    );
  }
}

class _ApartmentForm extends StatefulWidget {
  const _ApartmentForm({super.key, required this.apartment});

  final Apartment apartment;

  @override
  State<_ApartmentForm> createState() => _ApartmentFormState();
}

class _ApartmentFormState extends State<_ApartmentForm> {
  late Apartment _draft = widget.apartment;
  late final _floor = TextEditingController(
    text: widget.apartment.floor?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.apartment.notes);
  bool _busy = false;

  bool get _dirty => _draft != widget.apartment;

  @override
  void dispose() {
    _floor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<SessionCubit>().state;
    if (_busy || session is! SessionActive) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<ApartmentsCubit>().save(
        before: widget.apartment,
        after: _draft,
        byUid: session.user.uid,
      );
      messenger.showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر الحفظ، حاول مرة أخرى')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editContact([int? index]) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (_) => _ContactDialog(
        initial: index == null ? null : _draft.contacts[index],
      ),
    );
    if (result == null) return;
    final contacts = [..._draft.contacts];
    if (index == null) {
      contacts.add(result);
    } else {
      contacts[index] = result;
    }
    setState(() => _draft = _draft.copyWith(contacts: contacts));
  }

  void _removeContact(int index) {
    final contacts = [..._draft.contacts]..removeAt(index);
    setState(() => _draft = _draft.copyWith(contacts: contacts));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ApartmentStatus>(
              initialValue: _draft.status,
              decoration: const InputDecoration(labelText: 'حالة الشقة'),
              items: [
                for (final s in ApartmentStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (s) =>
                  setState(() => _draft = _draft.copyWith(status: s)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _floor,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'الدور',
                helperText: '٠ = الدور الأرضي',
              ),
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(floor: () => int.tryParse(v)),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تُحسب عليها الاشتراكات الشهرية'),
              subtitle: const Text(
                'قرار مستقل عن حالة الشقة؛ لا تُعفى الشقة تلقائيًا إذا كانت '
                'خالية أو لم تُسلَّم.',
              ),
              value: _draft.feeEligible,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(feeEligible: v)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(notes: v)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الملاك والمستأجرون',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _editContact,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            if (_draft.contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا يوجد شخص مسجل لهذه الشقة (غير معروف).'),
              ),
            for (final (i, c) in _draft.contacts.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(c.name),
                subtitle: Text(
                  [
                    c.kind.label,
                    if (c.phone.isNotEmpty) c.phone,
                    if (c.note.isNotEmpty) c.note,
                  ].join(' · '),
                ),
                onTap: () => _editContact(i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.phone.trim().isNotEmpty)
                      IconButton(
                        tooltip: 'واتساب',
                        icon: const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          color: whatsappGreen,
                        ),
                        onPressed: () => openWhatsApp(context, c.phone),
                      ),
                    if (c.phone.trim().isNotEmpty)
                      IconButton(
                        tooltip: 'اتصال بـ${c.kind.label}',
                        icon: const Icon(Icons.call),
                        onPressed: () => callPhone(context, c.phone),
                      ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeContact(i),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _dirty && !_busy ? _save : null,
              child: const Text('حفظ التعديلات'),
            ),
            ApartmentSheetHistory(apartmentNumber: widget.apartment.number),
          ],
        ),
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.initial});

  final Contact? initial;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _note = TextEditingController(text: widget.initial?.note);
  late ContactKind _kind = widget.initial?.kind ?? ContactKind.owner;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Contact(
        name: _name.text.trim(),
        kind: _kind,
        phone: _phone.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة شخص' : 'تعديل البيانات'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<ContactKind>(
                segments: [
                  for (final k in ContactKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الهاتف (اختياري)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                ),
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
        FilledButton(onPressed: _submit, child: const Text('تم')),
      ],
    );
  }
}
