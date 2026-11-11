import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app_theme.dart';
import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../ledger/view/add_expense_sheet.dart';
import '../../ledger/view/tx_widgets.dart';
import '../../sheet_import/data/import_item.dart';
import '../../subscriptions/data/arrears.dart';
import '../../subscriptions/view/subscriptions_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onOpenTab});

  /// Switches the bottom navigation tab.
  final ValueChanged<int> onOpenTab;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Stream<List<ImportItem>> _sheet = context
      .read<ImportRepository>()
      .watchAll();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledgerState = context.watch<LedgerCubit>().state;
    final apartmentsState = context.watch<ApartmentsCubit>().state;
    final apartments = apartmentsState is ApartmentsLoaded
        ? apartmentsState.apartments
        : const <Apartment>[];
    final period = currentPeriod();

    if (ledgerState is LedgerLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ledgerState is! LedgerLoaded) {
      return const Center(
        child: Text('تعذر تحميل البيانات. تأكد من الاتصال بالإنترنت.'),
      );
    }
    final ledger = ledgerState;
    final recent = ledger.txs.take(5).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ArrearsBuilder(
              builder: (context, arrears) => _BalanceCard(
                balance: ledger.balance,
                income: ledger.incomeIn(period),
                expenses: ledger.expensesIn(period),
                period: period,
                arrears: arrears,
                onOpenArrears: () => widget.onOpenTab(1),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showAddExpense(context),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('إضافة مصروف'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onOpenTab(2),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تحصيل اشتراك'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ArrearsBuilder(
              builder: (context, arrears) => _CollectionMessageCard(
                period: period,
                owing: arrears?.apartmentsOwing ?? 0,
              ),
            ),
            const SizedBox(height: 16),
            _ApartmentStats(apartments: apartments),
            const SizedBox(height: 16),
            StreamBuilder<List<ImportItem>>(
              stream: _sheet,
              builder: (context, snap) {
                final summary = summarizeMonth(
                  period,
                  apartments,
                  ledger,
                  snap.data ?? const [],
                );
                final due = summary.dueCount;
                return _Panel(
                  onTap: () => widget.onOpenTab(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'اشتراكات ${periodLabel(period)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            formatEgp(summary.collected),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: due == 0 ? 0 : summary.paidCount / due,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'دفعت ${toArabicDigits('${summary.paidCount}')} من ${toArabicDigits('$due')} شقة · متبقي ${toArabicDigits('${due - summary.paidCount}')}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _Panel(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'آخر الحركات',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/app/ledger'),
                          child: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                  ),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('لا توجد حركات بعد')),
                    ),
                  for (final t in recent) TxTile(tx: t),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.period,
    required this.arrears,
    required this.onOpenArrears,
  });

  final int balance;
  final int income;
  final int expenses;
  final String period;
  final Arrears? arrears;
  final VoidCallback onOpenArrears;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onDark = Colors.white;
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
                'الرصيد الحالي',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onDark.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatAmount(balance),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: onDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ج.م',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onDark.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'دخل ${arabicMonths[periodMonth(period) - 1]}',
                  value: income,
                  icon: Icons.south_west,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'مصروفات ${arabicMonths[periodMonth(period) - 1]}',
                  value: expenses,
                  icon: Icons.north_east,
                  color: const Color(0xFFFF8A80),
                ),
              ),
            ],
          ),
          if (arrears case final arrears?) ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFFF8A80).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onOpenArrears,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions_outlined,
                        color: Color(0xFFFF8A80),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اشتراكات غير مدفوعة منذ '
                              '${periodLabel(arrears.from)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              arrears.total == 0
                                  ? 'لا توجد متأخرات'
                                  : '${formatEgp(arrears.total)} · '
                                        '${toArabicDigits('${arrears.apartmentsOwing}')} شقة',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (arrears.carriedTotal > 0)
                              Text(
                                'منها متأخرات سنوات سابقة: '
                                '${formatEgp(arrears.carriedTotal)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  formatEgp(value),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApartmentStats extends StatelessWidget {
  const _ApartmentStats({required this.apartments});

  final List<Apartment> apartments;

  @override
  Widget build(BuildContext context) {
    final inService = apartments.where((a) => a.inService).length;
    final rented = apartments.where((a) => a.inService && a.isRented).length;
    final out = apartments.length - inService;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.home_outlined,
            label: 'في الخدمة',
            value: inService,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.key_outlined,
            label: 'مؤجرة',
            value: rented,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.no_meeting_room_outlined,
            label: 'غير مستخدمة',
            value: out,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              toArabicDigits('$value'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Points to the monthly collection message; prominent in the first days
/// of the month, when it is sent.
class _CollectionMessageCard extends StatelessWidget {
  const _CollectionMessageCard({required this.period, required this.owing});

  final String period;
  final int owing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = DateTime.now().day <= 5 && owing > 0;
    final month = arabicMonths[periodMonth(period) - 1];
    return Card(
      margin: EdgeInsets.zero,
      color: due ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: const Icon(Icons.campaign_outlined),
        title: Text(due ? 'رسالة تحصيل شهر $month جاهزة' : 'رسالة التحصيل'),
        subtitle: Text(
          owing == 0
              ? 'لا توجد شقق عليها اشتراكات'
              : '${toArabicDigits('$owing')} شقة عليها اشتراكات · '
                    'انسخها أو شاركها على جروب العمارة',
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => context.go('/app/collection-message'),
      ),
    );
  }
}
