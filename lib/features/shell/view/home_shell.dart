import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../apartments/view/apartments_page.dart';
import '../../dashboard/view/dashboard_page.dart';
import '../../projects/view/projects_page.dart';
import '../../settings/data/members_repository.dart';
import '../../settings/view/more_page.dart';
import '../../subscriptions/view/subscriptions_page.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('الرئيسية', Icons.dashboard_outlined, Icons.dashboard),
  _Tab('الشقق', Icons.apartment_outlined, Icons.apartment),
  _Tab('الاشتراكات', Icons.event_available_outlined, Icons.event_available),
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

  void _open(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(
      index: _index,
      children: [
        DashboardPage(onOpenTab: _open),
        const ApartmentsPage(),
        const SubscriptionsPage(),
        const ProjectsPage(),
        const MorePage(),
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
                    onDestinationSelected: _open,
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
              onDestinationSelected: _open,
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
