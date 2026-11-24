import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_theme.dart';
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
              final mine = state.txs.where((t) => t.createdBy == uid).toList();
              final counted = mine.where((t) => !t.voided);
              // The opening balance was handed over, not collected.
              final opening = counted
                  .where((t) => t.type == TxType.opening)
                  .fold(0, (s, t) => s + t.amount);
              final collected = counted
                  .where((t) => !t.isOutgoing && t.type != TxType.opening)
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _HeldCard(
                          held: balanceOf(mine),
                          opening: opening,
                        ),
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

/// Money the staff member holds now: their opening share plus what they
/// collected, minus what they paid.
class _HeldCard extends StatelessWidget {
  const _HeldCard({required this.held, required this.opening});

  final int held;
  final int opening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.ink, AppColors.inkSoft],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'الرصيد معه الآن',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatAmount(held),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ج.م',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          if (opening > 0) ...[
            const SizedBox(height: 8),
            Text(
              'منها رصيد افتتاحي ${formatEgp(opening)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
