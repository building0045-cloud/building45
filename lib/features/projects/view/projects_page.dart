import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app_theme.dart';
import '../../../core/money.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../../sheet_import/data/import_item.dart';
import '../data/project.dart';
import 'project_form_sheet.dart';
import '../../sheet_import/view/contributions_page.dart';

IconData _projectIcon(String name) {
  if (name.contains('كاميرا')) return Icons.videocam_outlined;
  if (name.contains('سور')) return Icons.fence_outlined;
  if (name.contains('تشجير')) return Icons.park_outlined;
  return Icons.savings_outlined;
}

/// Special contributions (cameras, fence, landscaping) as cards.
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late final Stream<List<ImportItem>> _items = context
      .read<ImportRepository>()
      .watchAll();
  late final Stream<List<Project>> _projects = context
      .read<ProjectRepository>()
      .watchAll();

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => showProjectForm(
                context,
                apartments: apartments.where((a) => a.inService).toList(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('مشروع جديد'),
            )
          : null,
      body: StreamBuilder<List<Project>>(
        stream: _projects,
        builder: (context, projectSnap) => StreamBuilder<List<ImportItem>>(
          stream: _items,
          builder: (context, snap) {
            if (snap.hasError || projectSnap.hasError) {
              return const Center(child: Text('تعذر تحميل المشاريع'));
            }
            if (!snap.hasData || !projectSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!.where((i) => i.period == null).toList();
            final sheetProjects = <String, List<ImportItem>>{};
            for (final i in items) {
              sheetProjects.putIfAbsent(i.sheetGid, () => []).add(i);
            }
            final appProjects = projectSnap.data!;
            if (sheetProjects.isEmpty && appProjects.isEmpty) {
              return const Center(child: Text('لا توجد مشاريع'));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    for (final p in appProjects) ...[
                      _AppProjectCard(
                        project: p,
                        collected: ledger?.projectCollected(p.id) ?? 0,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (appProjects.isNotEmpty && sheetProjects.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Text(
                          'من الشيت القديم',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    for (final entry in sheetProjects.entries) ...[
                      _ProjectCard(gid: entry.key, items: entry.value),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'اضغط على أي مشروع لعرض وتعديل سجلاته.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppProjectCard extends StatelessWidget {
  const _AppProjectCard({required this.project, required this.collected});

  final Project project;
  final int collected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = project.total == 0
        ? 0.0
        : (collected / project.total).clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/app/project/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      projectIcon(project.icon),
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${toArabicDigits('${project.shares.length}')} شقة مشاركة',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatAmount(collected),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'من ${formatAmount(project.total)} ج.م',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.gid, required this.items});

  final String gid;
  final List<ImportItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = items.first.sheetName;
    final payments = items.where(
      (i) =>
          i.kind == ImportKind.payment &&
          i.apartmentNumber != null &&
          i.col == 3,
    );
    final total = payments.fold<num>(0, (s, i) => s + (i.amount ?? 0));
    final notes = items
        .where(
          (i) =>
              i.apartmentNumber == null &&
              i.kind != ImportKind.total &&
              i.text.isNotEmpty,
        )
        .length;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/app/projects/$gid'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_projectIcon(name), color: AppColors.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'ساهمت ${toArabicDigits('${payments.length}')} شقة${notes > 0 ? ' · ${toArabicDigits('$notes')} ملاحظة' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount((total * 100).round()),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('ج.م', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.sheetGid});

  final String sheetGid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ImportItem>>(
      stream: context.read<ImportRepository>().watchAll(),
      builder: (context, snap) {
        final name =
            snap.data
                ?.where((i) => i.sheetGid == sheetGid)
                .firstOrNull
                ?.sheetName ??
            'المشروع';
        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ContributionsPage(projects: true, sheetGid: sheetGid),
        );
      },
    );
  }
}
