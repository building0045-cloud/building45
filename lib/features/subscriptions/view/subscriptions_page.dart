import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/data/ledger_tx.dart';
import '../../ledger/view/tx_widgets.dart';
import '../../sheet_import/data/import_item.dart';
import '../../sheet_import/view/contributions_page.dart';
import 'payment_sheet.dart';

/// One apartment's subscription for one month.
class SubscriptionStatus {
  factory SubscriptionStatus.of(
    Apartment apartment,
    ({LedgerTx tx, int amount})? paid, {
    ImportItem? sheetRecord,
  }) => SubscriptionStatus(
    apartment: apartment,
    payment: paid?.tx,
    share: paid?.amount ?? 0,
    sheetRecord: sheetRecord,
  );

  const SubscriptionStatus({
    required this.apartment,
    this.payment,
    this.share = 0,
    this.sheetRecord,
  });

  final Apartment apartment;

  /// Payment recorded in the app that covers this month (counts in the
  /// balance), possibly together with other months.
  final LedgerTx? payment;

  /// Part of [payment] that belongs to this month.
  final int share;

  /// What the old spreadsheet says for that month, if anything.
  final ImportItem? sheetRecord;

  /// The sheet shows the month as paid, settled, or paid in another month.
  bool get coveredBySheet {
    final r = sheetRecord;
    return r != null &&
        r.text.isNotEmpty &&
        const {
          ImportKind.payment,
          ImportKind.settledNote,
          ImportKind.paymentReference,
        }.contains(r.kind);
  }

  bool get isPaid => payment != null || coveredBySheet;

  /// Paid amount, from the app or a number in the sheet.
  int get paidAmount => payment != null
      ? share
      : (coveredBySheet ? ((sheetRecord!.amount ?? 0) * 100).round() : 0);
}

class MonthSummary {
  MonthSummary(this.statuses);

  final List<SubscriptionStatus> statuses;

  Iterable<SubscriptionStatus> get eligible =>
      statuses.where((s) => s.apartment.feeEligible || s.isPaid);
  int get paidCount => eligible.where((s) => s.isPaid).length;
  int get dueCount => eligible.length;
  int get collected => statuses.fold(0, (sum, s) => sum + s.paidAmount);
}

/// Subscription status for [period] of the apartments in use, plus any
/// other apartment that already has a payment that month.
MonthSummary summarizeMonth(
  String period,
  List<Apartment> apartments,
  LedgerLoaded? ledger,
  List<ImportItem> sheetItems,
) => MonthSummary(
  [
    for (final a in apartments)
      SubscriptionStatus.of(
        a,
        ledger?.subscriptionFor(period, a.number),
        sheetRecord: sheetItems
            .where(
              (i) =>
                  i.period == period &&
                  i.apartmentNumber == a.number &&
                  i.col == 3,
            )
            .firstOrNull,
      ),
  ].where((s) => s.apartment.inService || s.isPaid).toList(),
);

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  late final Stream<List<ImportItem>> _sheet = context
      .read<ImportRepository>()
      .watchAll();
  late final Stream<int> _fee = context
      .read<LedgerCubit>()
      .repo
      .watchMonthlyFee();
  String _period = currentPeriod();

  void _select(String period) {
    if (period.compareTo(firstPeriod) < 0 ||
        period.compareTo(lastOpenPeriod()) > 0) {
      return;
    }
    setState(() => _period = period);
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsState = context.watch<ApartmentsCubit>().state;
    final ledgerState = context.watch<LedgerCubit>().state;
    final apartments = apartmentsState is ApartmentsLoaded
        ? apartmentsState.apartments
        : const <Apartment>[];
    final ledger = ledgerState is LedgerLoaded ? ledgerState : null;

    return StreamBuilder<List<ImportItem>>(
      stream: _sheet,
      builder: (context, sheetSnap) => StreamBuilder<int>(
        stream: _fee,
        builder: (context, feeSnap) {
          if (ledger == null || !sheetSnap.hasData) {
            return ledgerState is LedgerFailure || sheetSnap.hasError
                ? const Center(child: Text('تعذر تحميل الاشتراكات'))
                : const Center(child: CircularProgressIndicator());
          }
          final fee = feeSnap.data ?? defaultMonthlyFee;
          final sheetItems = sheetSnap.data!;
          final summary = summarizeMonth(
            _period,
            apartments,
            ledger,
            sheetItems,
          );
          final monthSheet = sheetItems
              .where((i) => i.period == _period)
              .firstOrNull;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _MonthPicker(period: _period, onSelect: _select),
                  _SummaryCard(period: _period, summary: summary, fee: fee),
                  const SizedBox(height: 8),
                  for (final s in summary.statuses)
                    _Row(
                      status: s,
                      period: _period,
                      fee: fee,
                      monthSheet: monthSheet,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.period, required this.onSelect});

  final String period;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = periodYear(period);
    final first = firstPeriod;
    final last = lastOpenPeriod();
    String inYear(int y, int m) => '$y-${m.toString().padLeft(2, '0')}';
    final canPrev = inYear(year - 1, 12).compareTo(first) >= 0;
    final canNext = inYear(year + 1, 1).compareTo(last) <= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'السنة السابقة',
                onPressed: canPrev
                    ? () => onSelect(
                        _clamp(inYear(year - 1, periodMonth(period))),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(toArabicDigits('$year'), style: theme.textTheme.titleLarge),
              IconButton(
                tooltip: 'السنة التالية',
                onPressed: canNext
                    ? () => onSelect(
                        _clamp(inYear(year + 1, periodMonth(period))),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (var m = 1; m <= 12; m++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(arabicMonths[m - 1]),
                      selected: periodMonth(period) == m,
                      onSelected:
                          inYear(year, m).compareTo(first) >= 0 &&
                              inYear(year, m).compareTo(last) <= 0
                          ? (_) => onSelect(inYear(year, m))
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _clamp(String p) {
    if (p.compareTo(firstPeriod) < 0) return firstPeriod;
    final last = lastOpenPeriod();
    return p.compareTo(last) > 0 ? last : p;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.period,
    required this.summary,
    required this.fee,
  });

  final String period;
  final MonthSummary summary;
  final int fee;

  Future<void> _editFee(BuildContext context) async {
    final session = context.read<SessionCubit>().state;
    if (session is! SessionActive || !session.member.isAdmin) return;
    final repo = context.read<LedgerCubit>().repo;
    final amount = await askAmount(
      context,
      title: 'الاشتراك الشهري',
      initial: fee,
      message: 'المبلغ الذي يُسجَّل عند الضغط على علامة التحصيل.',
    );
    if (amount != null && amount != fee) {
      await repo.setMonthlyFee(amount, byUid: session.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionCubit>().state;
    final isAdmin = session is SessionActive && session.member.isAdmin;
    final progress = summary.dueCount == 0
        ? 0.0
        : summary.paidCount / summary.dueCount;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'اشتراك ${periodLabel(period)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    isAdmin ? Icons.edit_outlined : Icons.sell_outlined,
                    size: 16,
                  ),
                  label: Text('${formatEgp(fee)} / شهر'),
                  onPressed: isAdmin ? () => _editFee(context) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatEgp(summary.collected),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text(
              'دفعت ${toArabicDigits('${summary.paidCount}')} من ${toArabicDigits('${summary.dueCount}')} شقة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.status,
    required this.period,
    required this.fee,
    required this.monthSheet,
  });

  final SubscriptionStatus status;
  final String period;
  final int fee;

  /// Any spreadsheet record of this month, when the month has a sheet.
  final ImportItem? monthSheet;

  Future<void> _collect(BuildContext context) async {
    final session = context.read<SessionCubit>().state;
    if (session is! SessionActive) return;
    final repo = context.read<LedgerCubit>().repo;
    final messenger = ScaffoldMessenger.of(context);
    final n = status.apartment.number;
    try {
      await repo.recordSubscription(
        period: period,
        apartmentNumber: n,
        amount: fee,
        byUid: session.user.uid,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('تم تحصيل ${formatEgp(fee)} من شقة $n'),
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () async {
                final ledger = context.read<LedgerCubit>().state;
                final tx = ledger is LedgerLoaded
                    ? ledger.subscriptionFor(period, n)?.tx
                    : null;
                if (tx != null) {
                  await repo.setVoided(tx, true, byUid: session.user.uid);
                }
              },
            ),
          ),
        );
    } on MonthAlreadyPaid {
      messenger.showSnackBar(
        const SnackBar(content: Text('هذا الشهر مدفوع بالفعل')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر التسجيل، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = status.apartment;
    final payment = status.payment;
    final sheet = status.sheetRecord;
    final sheetText = sheet?.text ?? '';

    final Widget trailing;
    if (payment != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatEgp(status.share),
            style: theme.textTheme.titleMedium?.copyWith(
              color: incomeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showTxActions(context, payment),
          ),
        ],
      );
    } else if (status.coveredBySheet) {
      trailing = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          sheet!.kind == ImportKind.payment
              ? formatEgp(status.paidAmount)
              : sheetText,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (!a.feeEligible) {
      trailing = Text('معفاة', style: theme.textTheme.bodyMedium);
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'دفع عدة شهور',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () =>
                showPaymentSheet(context, apartment: a, startPeriod: period),
          ),
          IconButton.filledTonal(
            tooltip: 'تحصيل ${formatEgp(fee)}',
            icon: const Icon(Icons.check),
            onPressed: () => _collect(context),
          ),
        ],
      );
    }

    final subtitle = [
      if (payment != null && payment.allocations.length > 1)
        'ضمن دفعة ${describeMonths(payment.periods)}',
      if (payment != null) 'حُصّل ${formatDate(payment.date)}',
      if (payment != null && payment.payerName.isNotEmpty)
        'من ${payment.payerName}',
      if (payment == null && status.coveredBySheet) 'من الشيت القديم',
      if (!status.coveredBySheet && sheetText.isNotEmpty) sheetText,
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status.isPaid
            ? incomeColor.withValues(alpha: 0.12)
            : null,
        foregroundColor: status.isPaid ? incomeColor : null,
        child: Text('${a.number}'),
      ),
      title: Text(a.displayName ?? 'غير معروف'),
      subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' · ')),
      trailing: trailing,
      // Spreadsheet months keep their records editable.
      onTap: payment == null && monthSheet != null
          ? () => editSheetContribution(
              context,
              sheet: monthSheet!,
              existing: sheet,
              apartment: a,
            )
          : null,
    );
  }
}
