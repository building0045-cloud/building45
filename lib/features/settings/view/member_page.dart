import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../auth/data/member.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../ledger/data/ledger_tx.dart';
import '../../ledger/view/tx_widgets.dart';
import '../data/members_repository.dart';

/// What one staff member collected and paid, with their entries.
class MemberPage extends StatelessWidget {
  const MemberPage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Member>>(
      stream: context.read<MembersRepository>().watchMembers(),
      builder: (context, snap) {
        final member = snap.data?.where((m) => m.uid == uid).firstOrNull;
        return Scaffold(
          appBar: AppBar(title: Text(member?.name ?? 'المسؤول')),
          body: BlocBuilder<LedgerCubit, LedgerState>(
            builder: (context, state) {
              if (state is LedgerLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is! LedgerLoaded) {
                return const Center(child: Text('تعذر تحميل السجل'));
              }
              final mine = state.txs
                  .where((t) => t.createdBy == uid && t.type != TxType.opening)
                  .toList();
              final counted = mine.where((t) => !t.voided);
              final collected = counted
                  .where((t) => !t.isOutgoing)
                  .fold(0, (s, t) => s + t.amount);
              final paid = counted
                  .where((t) => t.isOutgoing)
                  .fold(0, (s, t) => s + t.amount);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (member != null)
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(member.name),
                          subtitle: Text(member.role.label),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _Total(
                                label: 'حصّل',
                                value: collected,
                                color: incomeColor,
                                icon: Icons.south_west,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Total(
                                label: 'صرف',
                                value: paid,
                                color: expenseColor,
                                icon: Icons.north_east,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'الحركات التي سجّلها (${toArabicDigits('${mine.length}')})',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (mine.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('لم يسجّل أي حركات بعد')),
                        ),
                      for (final t in mine) TxTile(tx: t),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              formatEgp(value),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
