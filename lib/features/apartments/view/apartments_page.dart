import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/apartments_cubit.dart';
import '../data/apartment.dart';

class ApartmentsPage extends StatefulWidget {
  const ApartmentsPage({super.key});

  @override
  State<ApartmentsPage> createState() => _ApartmentsPageState();
}

class _ApartmentsPageState extends State<ApartmentsPage> {
  String _query = '';
  ApartmentStatus? _status;

  bool _matches(Apartment a) {
    if (_status != null && a.status != _status) return false;
    final q = _query.trim();
    if (q.isEmpty) return true;
    return '${a.number}' == q ||
        a.contacts.any((c) => c.name.contains(q) || c.phone.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث برقم الشقة أو الاسم أو الهاتف',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: _status == null,
                onSelected: (_) => setState(() => _status = null),
              ),
              for (final s in ApartmentStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<ApartmentsCubit, ApartmentsState>(
            builder: (context, state) => switch (state) {
              ApartmentsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              ApartmentsFailure() => const Center(
                child: Text('تعذر تحميل الشقق. تأكد من الاتصال بالإنترنت.'),
              ),
              ApartmentsLoaded(:final apartments) => _list(
                apartments.where(_matches).toList(),
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _list(List<Apartment> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد شقق مطابقة'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          leading: CircleAvatar(child: Text('${a.number}')),
          title: Text(a.displayName ?? 'غير معروف'),
          subtitle: Text(
            [
              a.status.label,
              if (a.floor != null) 'الدور ${a.floor}',
              if (!a.feeEligible) 'معفاة من الاشتراك',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.go('/app/apartments/${a.id}'),
        );
      },
    );
  }
}
