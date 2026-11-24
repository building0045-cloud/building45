import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app_theme.dart';
import '../../../core/money.dart';
import '../../auth/data/member.dart';
import '../../settings/data/members_repository.dart';
import '../cubit/ledger_cubit.dart';
import '../data/ledger_tx.dart';

/// The building balance split by who holds the money.
class HoldersPage extends StatefulWidget {
  const HoldersPage({super.key});

  @override
  State<HoldersPage> createState() => _HoldersPageState();
}

class _HoldersPageState extends State<HoldersPage> {
  late final Stream<List<Member>> _members = context
      .read<MembersRepository>()
      .watchMembers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الرصيد مع المسؤولين')),
      body: BlocBuilder<LedgerCubit, LedgerState>(
        builder: (context, state) {
          if (state is LedgerLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is! LedgerLoaded) {
            return const Center(child: Text('تعذر تحميل السجل'));
          }
          return StreamBuilder<List<Member>>(
            stream: _members,
            builder: (context, snap) {
              final members = {
                for (final m in snap.data ?? <Member>[]) m.uid: m,
              };
              final held = balanceByHolder(state.txs);
              final staff = [
                for (final m in members.values)
                  if (m.role != MemberRole.resident || (held[m.uid] ?? 0) != 0)
                    m,
              ]..sort((a, b) => (held[b.uid] ?? 0).compareTo(held[a.uid] ?? 0));
              // Money recorded by accounts that are not members any more.
              final unknown = held.entries
                  .where((e) => !members.containsKey(e.key) && e.value != 0)
                  .fold(0, (s, e) => s + e.value);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _TotalCard(balance: state.balance),
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, m) in staff.indexed) ...[
                              if (i > 0) const Divider(height: 1),
                              _HolderTile(
                                name: m.name,
                                subtitle: m.role.label,
                                amount: held[m.uid] ?? 0,
                                total: state.balance,
                                onTap: () =>
                                    context.go('/app/members/${m.uid}'),
                              ),
                            ],
                            if (unknown != 0) ...[
                              if (staff.isNotEmpty) const Divider(height: 1),
                              _HolderTile(
                                name: 'غير محدد',
                                subtitle: 'حركات بدون مسؤول معروف',
                                amount: unknown,
                                total: state.balance,
                              ),
                            ],
                            if (staff.isEmpty && unknown == 0)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('لا يوجد مسؤولون'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'رصيد كل مسؤول = الرصيد الافتتاحي معه + ما حصّله − ما صرفه.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.balance});

  final int balance;

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
          Text(
            'إجمالي الرصيد',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatAmount(balance),
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
        ],
      ),
    );
  }
}

class _HolderTile extends StatelessWidget {
  const _HolderTile({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.total,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final int amount;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Row(
        children: [
          Expanded(child: Text(name)),
          Text(
            formatEgp(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: amount < 0 ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}
