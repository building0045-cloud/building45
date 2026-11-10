import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/data/apartment.dart';
import '../../apartments/view/apartments_page.dart';
import '../../settings/data/members_repository.dart';
import '../../settings/view/more_page.dart';
import '../../sheet_import/view/contributions_page.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('الرئيسية', Icons.dashboard_outlined, Icons.dashboard),
  _Tab('الشقق', Icons.apartment_outlined, Icons.apartment),
  _Tab('الاشتراكات', Icons.receipt_long_outlined, Icons.receipt_long),
  _Tab('المشاريع', Icons.savings_outlined, Icons.savings),
  _Tab('المزيد', Icons.menu, Icons.menu),
];

/// Staff area: bottom navigation on phones, side rail on wide screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(
      index: _index,
      children: const [
        _DashboardPlaceholder(),
        ApartmentsPage(),
        ContributionsPage(projects: false),
        ContributionsPage(projects: true),
        MorePage(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<String>(
          stream: context.read<MembersRepository>().watchBuildingName(),
          builder: (context, snap) =>
              Text(_index == 0 ? (snap.data ?? '') : _tabs[_index].label),
        ),
      ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: [
                      for (final t in _tabs)
                        NavigationRailDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.selectedIcon),
                          label: Text(t.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in _tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}

/// Until the ledger exists there are no financial figures to show, so the
/// dashboard only summarises the apartments and says so plainly.
class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ApartmentsCubit, ApartmentsState>(
      builder: (context, state) {
        final apartments = state is ApartmentsLoaded
            ? state.apartments
            : const <Apartment>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الشقق', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _Stat('الإجمالي', apartments.length),
                        for (final s in ApartmentStatus.values)
                          _Stat(
                            s.label,
                            apartments.where((a) => a.status == s).length,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('لا توجد بيانات مالية بعد'),
                subtitle: Text(
                  'الأرصدة والتحصيلات والمصروفات تظهر هنا بعد إضافة سجل '
                  'الحركات واستيراد ملف الإكسل.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
