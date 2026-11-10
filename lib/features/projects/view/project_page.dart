import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_theme.dart';
import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../ledger/data/ledger_tx.dart';
import '../../ledger/view/tx_widgets.dart';
import '../data/project.dart';
import 'project_form_sheet.dart';

/// A project created in the app: progress and each apartment's share.
class ProjectPage extends StatelessWidget {
  const ProjectPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionCubit>().state;
    final isAdmin = session is SessionActive && session.member.isAdmin;
    final apartmentsState = context.watch<ApartmentsCubit>().state;
    final apartments = apartmentsState is ApartmentsLoaded
        ? apartmentsState.apartments
        : const <Apartment>[];
    final ledgerState = context.watch<LedgerCubit>().state;
    final ledger = ledgerState is LedgerLoaded ? ledgerState : null;

    return StreamBuilder<List<Project>>(
      stream: context.read<ProjectRepository>().watchAll(),
      builder: (context, snap) {
        final project = snap.data?.where((p) => p.id == projectId).firstOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(project?.name ?? 'المشروع'),
            actions: [
              if (isAdmin && project != null)
                IconButton(
                  tooltip: 'تعديل المشروع',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showProjectForm(
                    context,
                    apartments: apartments.where((a) => a.inService).toList(),
                    existing: project,
                  ),
                ),
            ],
          ),
          body: project == null || ledger == null
              ? Center(
                  child: snap.hasError
                      ? const Text('تعذر تحميل المشروع')
                      : (snap.hasData && project == null)
                      ? const Text('المشروع غير موجود')
                      : const CircularProgressIndicator(),
                )
              : _body(context, theme, project, ledger, apartments),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    ThemeData theme,
    Project project,
    LedgerLoaded ledger,
    List<Apartment> apartments,
  ) {
    final collected = ledger.projectCollected(project.id);
    final byNumber = {for (final a in apartments) a.number: a};
    final numbers = project.shares.keys.toList()..sort();
    final paidCount = numbers
        .where((n) => ledger.projectPayment(project.id, n) != null)
        .length;
    final progress = project.total == 0
        ? 0.0
        : (collected / project.total).clamp(0.0, 1.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            projectIcon(project.icon),
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تم تحصيل',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '${formatEgp(collected)} من ${formatEgp(project.total)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'دفعت ${toArabicDigits('$paidCount')} من ${toArabicDigits('${numbers.length}')} شقة · '
                      'متبقي ${formatEgp((project.total - collected).clamp(0, project.total))}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final n in numbers)
              _ShareRow(
                project: project,
                number: n,
                apartment: byNumber[n],
                payment: ledger.projectPayment(project.id, n),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.project,
    required this.number,
    required this.apartment,
    required this.payment,
  });

  final Project project;
  final int number;
  final Apartment? apartment;
  final LedgerTx? payment;

  Future<void> _collect(BuildContext context) async {
    final session = context.read<SessionCubit>().state;
    if (session is! SessionActive) return;
    final repo = context.read<LedgerCubit>().repo;
    final messenger = ScaffoldMessenger.of(context);
    final share = project.shares[number] ?? 0;
    try {
      await repo.recordProjectPayment(
        projectId: project.id,
        projectName: project.name,
        apartmentNumber: number,
        amount: share,
        byUid: session.user.uid,
        byName: session.member.name,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('تم تحصيل ${formatEgp(share)} من شقة $number'),
          ),
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
    final share = project.shares[number] ?? 0;
    final paid = payment;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: paid != null
            ? incomeColor.withValues(alpha: 0.12)
            : null,
        foregroundColor: paid != null ? incomeColor : null,
        child: Text('$number'),
      ),
      title: Text(apartment?.displayName ?? 'غير معروف'),
      subtitle: Text(
        paid == null
            ? 'الحصة ${formatEgp(share)}'
            : 'الحصة ${formatEgp(share)} · حُصّل ${formatDate(paid.date)}',
      ),
      trailing: paid != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatEgp(paid.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: incomeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showTxActions(context, paid),
                ),
              ],
            )
          : IconButton.filledTonal(
              tooltip: 'تحصيل ${formatEgp(share)}',
              icon: const Icon(Icons.check),
              onPressed: () => _collect(context),
            ),
    );
  }
}
