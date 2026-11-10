import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../../core/phone.dart';
import '../../subscriptions/data/arrears.dart';
import '../cubit/apartments_cubit.dart';
import '../data/apartment.dart';

class ApartmentsPage extends StatefulWidget {
  const ApartmentsPage({super.key});

  @override
  State<ApartmentsPage> createState() => _ApartmentsPageState();
}

class _ApartmentsPageState extends State<ApartmentsPage> {
  /// null = all; otherwise 'rented' or an [ApartmentStatus] name.
  String? _filter;

  bool _matches(Apartment a, Arrears? arrears) => switch (_filter) {
    null => true,
    'rented' => a.isRented,
    'owing' => (arrears?.totalFor(a.number) ?? 0) > 0,
    final status => a.status.name == status,
  };

  Widget _chip(String label, String? value) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            spacing: 8,
            children: [
              _chip('الكل', null),
              _chip('مؤجرة', 'rented'),
              _chip('عليها متأخرات', 'owing'),
              for (final s in ApartmentStatus.values) _chip(s.label, s.name),
            ],
          ),
        ),
        Expanded(
          child: ArrearsBuilder(
            builder: (context, arrears) =>
                switch (context.watch<ApartmentsCubit>().state) {
                  ApartmentsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  ApartmentsFailure() => const Center(
                    child: Text('تعذر تحميل الشقق. تأكد من الاتصال بالإنترنت.'),
                  ),
                  ApartmentsLoaded(:final apartments) => _list(
                    apartments.where((a) => _matches(a, arrears)).toList(),
                    arrears,
                  ),
                },
          ),
        ),
      ],
    );
  }

  Widget _list(List<Apartment> items, Arrears? arrears) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد شقق مطابقة'));
    }
    final theme = Theme.of(context);
    // Group by floor, ground floor first; apartments without a floor last.
    final floors = {for (final a in items) a.floor}.toList()
      ..sort((a, b) => (a ?? 1 << 20).compareTo(b ?? 1 << 20));
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final floor in floors) ...[
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              floor == null ? 'بدون دور محدد' : Apartment.floorName(floor),
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final a in items.where((a) => a.floor == floor))
            _ApartmentTile(
              apartment: a,
              unpaid: arrears?.byApartment[a.number] ?? const [],
            ),
        ],
      ],
    );
  }
}

String _months(List<UnpaidMonth> months) => months.length == 1
    ? periodLabel(months.first.period)
    : '${months.length == 2 ? 'شهرين' : '${toArabicDigits('${months.length}')} شهور'} من ${periodLabel(months.first.period)}';

const whatsappGreen = Color(0xFF25D366);

/// Lets the user choose owner or renter when more than one has a number.
Future<Contact?> pickContact(
  BuildContext context,
  List<Contact> contacts,
  String question,
) async {
  if (contacts.length == 1) return contacts.first;
  return showModalBottomSheet<Contact>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(question)),
          for (final c in contacts)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${c.kind.label}: ${c.name}'),
              subtitle: Text(c.phone, textDirection: TextDirection.ltr),
              onTap: () => Navigator.of(context).pop(c),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _ApartmentTile extends StatelessWidget {
  const _ApartmentTile({required this.apartment, required this.unpaid});

  final Apartment apartment;

  /// Unpaid subscription months of the apartment.
  final List<UnpaidMonth> unpaid;

  Future<void> _call(BuildContext context) async {
    final c = await pickContact(
      context,
      apartment.callableContacts,
      'الاتصال بمن؟',
    );
    if (c != null && context.mounted) await callPhone(context, c.phone);
  }

  Future<void> _whatsApp(BuildContext context) async {
    final c = await pickContact(
      context,
      apartment.callableContacts,
      'مراسلة من على واتساب؟',
    );
    if (c != null && context.mounted) await openWhatsApp(context, c.phone);
  }

  @override
  Widget build(BuildContext context) {
    final a = apartment;
    final hasPhone = a.callableContacts.isNotEmpty;
    return ListTile(
      leading: CircleAvatar(child: Text('${a.number}')),
      title: Text(a.displayName ?? 'غير معروف'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              a.status.label,
              if (a.isRented) 'مؤجرة',
              if (!a.feeEligible) 'معفاة من الاشتراك',
            ].join(' · '),
          ),
          if (unpaid.isNotEmpty)
            Text(
              'غير مدفوع على ${a.isRented ? 'المستأجر' : 'المالك'}: '
              '${formatEgp(unpaid.fold(0, (s, m) => s + m.owed))} '
              '(${_months(unpaid)})',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      trailing: hasPhone
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'واتساب',
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: whatsappGreen,
                  ),
                  onPressed: () => _whatsApp(context),
                ),
                IconButton(
                  tooltip: 'اتصال',
                  icon: const Icon(Icons.call),
                  onPressed: () => _call(context),
                ),
              ],
            )
          : null,
      onTap: () => context.go('/app/apartments/${a.id}'),
    );
  }
}
