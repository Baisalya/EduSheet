import 'package:flutter/material.dart';

import '../navigation/teaching_planner_navigation.dart';

class TeachingPlannerAdaptiveNavigationBar extends StatelessWidget {
  const TeachingPlannerAdaptiveNavigationBar({
    super.key,
    required this.currentDestination,
    required this.onHome,
    required this.onOpenDestination,
  });

  final TeachingPlannerDestination? currentDestination;
  final VoidCallback onHome;
  final ValueChanged<TeachingPlannerDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _selectedIndex(currentDestination),
      onDestinationSelected: (index) => _handleSelection(
        index,
        currentDestination: currentDestination,
        onHome: onHome,
        onOpenDestination: onOpenDestination,
      ),
      destinations: const [
        NavigationDestination(
          key: ValueKey('planner-nav-home'),
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          key: ValueKey('planner-nav-planner'),
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Planner',
        ),
        NavigationDestination(
          key: ValueKey('planner-nav-syllabus'),
          icon: Icon(Icons.account_tree_outlined),
          selectedIcon: Icon(Icons.account_tree_rounded),
          label: 'Syllabus',
        ),
        NavigationDestination(
          key: ValueKey('planner-nav-progress'),
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: 'Progress',
        ),
        NavigationDestination(
          key: ValueKey('planner-nav-more'),
          icon: Icon(Icons.more_horiz_rounded),
          label: 'More',
        ),
      ],
    );
  }
}

class TeachingPlannerAdaptiveNavigationRail extends StatelessWidget {
  const TeachingPlannerAdaptiveNavigationRail({
    super.key,
    required this.currentDestination,
    required this.onHome,
    required this.onOpenDestination,
  });

  final TeachingPlannerDestination? currentDestination;
  final VoidCallback onHome;
  final ValueChanged<TeachingPlannerDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 420;

    return NavigationRail(
      selectedIndex: _selectedIndex(currentDestination),
      labelType: compactHeight
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      groupAlignment: compactHeight ? 0 : -0.75,
      onDestinationSelected: (index) => _handleSelection(
        index,
        currentDestination: currentDestination,
        onHome: onHome,
        onOpenDestination: onOpenDestination,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: Text('Planner'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_tree_outlined),
          selectedIcon: Icon(Icons.account_tree_rounded),
          label: Text('Syllabus'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: Text('Progress'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: Text('More'),
        ),
      ],
    );
  }
}

class TeachingPlannerHomeNavigationBar extends StatelessWidget {
  const TeachingPlannerHomeNavigationBar({
    super.key,
    required this.onOpenDestination,
  });

  final ValueChanged<TeachingPlannerDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerAdaptiveNavigationBar(
      currentDestination: null,
      onHome: () {},
      onOpenDestination: onOpenDestination,
    );
  }
}

class TeachingPlannerHomeNavigationRail extends StatelessWidget {
  const TeachingPlannerHomeNavigationRail({
    super.key,
    required this.onOpenDestination,
  });

  final ValueChanged<TeachingPlannerDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerAdaptiveNavigationRail(
      currentDestination: null,
      onHome: () {},
      onOpenDestination: onOpenDestination,
    );
  }
}

int _selectedIndex(TeachingPlannerDestination? destination) =>
    switch (destination) {
      null => 0,
      TeachingPlannerDestination.calendar => 1,
      TeachingPlannerDestination.lessons => 1,
      TeachingPlannerDestination.syllabus => 2,
      TeachingPlannerDestination.progress => 3,
      TeachingPlannerDestination.workspace => 4,
      TeachingPlannerDestination.insightsBackup => 4,
    };

TeachingPlannerDestination? _destinationForIndex(int index) => switch (index) {
  0 => null,
  1 => TeachingPlannerDestination.calendar,
  2 => TeachingPlannerDestination.syllabus,
  3 => TeachingPlannerDestination.progress,
  4 => TeachingPlannerDestination.insightsBackup,
  _ => null,
};

void _handleSelection(
  int index, {
  required TeachingPlannerDestination? currentDestination,
  required VoidCallback onHome,
  required ValueChanged<TeachingPlannerDestination> onOpenDestination,
}) {
  final destination = _destinationForIndex(index);
  if (destination == null) {
    if (currentDestination != null) onHome();
    return;
  }

  if (destination == currentDestination) return;
  onOpenDestination(destination);
}
