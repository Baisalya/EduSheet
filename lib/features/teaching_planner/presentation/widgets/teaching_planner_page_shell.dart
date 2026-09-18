import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../navigation/teaching_planner_navigation.dart';
import 'teaching_planner_home_navigation.dart';

class TeachingPlannerPageShell extends StatelessWidget {
  const TeachingPlannerPageShell({
    super.key,
    required this.title,
    required this.body,
    this.currentDestination,
    this.actions = const [],
    this.floatingActionButton,
    this.showGlobalNavigation = true,
    this.automaticallyImplyLeading = true,
    this.navigationBarKey = const ValueKey('planner-global-navigation-bar'),
    this.navigationRailKey = const ValueKey('planner-global-navigation-rail'),
    this.showAppBar = true,
  });

  final String title;
  final Widget body;
  final TeachingPlannerDestination? currentDestination;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool showGlobalNavigation;
  final bool automaticallyImplyLeading;
  final Key navigationBarKey;
  final Key navigationRailKey;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerThemeScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail =
              showGlobalNavigation &&
              TeachingPlannerBreakpoints.useNavigationRail(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              );

          return Scaffold(
            appBar: showAppBar
                ? AppBar(
                    automaticallyImplyLeading: automaticallyImplyLeading,
                    title: title.isEmpty
                        ? const SizedBox.shrink()
                        : Text(title),
                    actions: actions,
                  )
                : null,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: showGlobalNavigation && !useRail
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: TeachingPlannerTheme.colorsOf(context).border,
                        ),
                      ),
                    ),
                    child: TeachingPlannerAdaptiveNavigationBar(
                      key: navigationBarKey,
                      currentDestination: currentDestination,
                      onHome: () => _goHome(context),
                      onOpenDestination: (destination) =>
                          _switchDestination(context, destination),
                    ),
                  )
                : null,
            body: useRail
                ? Row(
                    children: [
                      TeachingPlannerAdaptiveNavigationRail(
                        key: navigationRailKey,
                        currentDestination: currentDestination,
                        onHome: () => _goHome(context),
                        onOpenDestination: (destination) =>
                            _switchDestination(context, destination),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: TeachingPlannerTheme.colorsOf(context).border,
                      ),
                      Expanded(child: body),
                    ],
                  )
                : body,
          );
        },
      ),
    );
  }

  void _goHome(BuildContext context) {
    if (currentDestination == null) return;
    Navigator.of(context).maybePop();
  }

  void _switchDestination(
    BuildContext context,
    TeachingPlannerDestination destination,
  ) {
    if (destination == currentDestination) return;

    final navigator = Navigator.of(context);
    if (currentDestination == null) {
      navigator.push<void>(TeachingPlannerNavigation.routeFor(destination));
      return;
    }

    navigator.pushReplacement<void, void>(
      TeachingPlannerNavigation.routeFor(destination),
    );
  }
}
