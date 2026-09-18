import 'package:edusheet/core/navigation/dismiss_layer_coordinator.dart';
import 'package:edusheet/core/navigation/windows_escape_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<GlobalKey<NavigatorState>> pumpHarness(
    WidgetTester tester, {
    required Widget home,
    DismissLayerCoordinator? coordinator,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final dismissCoordinator = coordinator ?? DismissLayerCoordinator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dismissLayerCoordinatorProvider.overrideWithValue(
            dismissCoordinator,
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => WindowsEscapeBackScope(
            enabled: true,
            navigatorKey: navigatorKey,
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  testWidgets('plain Escape pops a child route but never the root route', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('child-page')),
              ),
            ),
            child: const Text('open-child'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-child'));
    await tester.pumpAndSettle();
    expect(find.text('child-page'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('open-child'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('open-child'), findsOneWidget);
  });

  testWidgets('Escape closes a Navigator-backed dialog before page navigation', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('dialog-open')),
            ),
            child: const Text('open-dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog-open'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('dialog-open'), findsNothing);
    expect(find.text('open-dialog'), findsOneWidget);
  });



  testWidgets('Escape still closes a dialog while its text field is focused', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                content: TextField(
                  autofocus: true,
                  decoration: InputDecoration(labelText: 'Dialog input'),
                ),
              ),
            ),
            child: const Text('open-input-dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-input-dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('open-input-dialog'), findsOneWidget);
  });

  testWidgets('registered transient layer gets Escape before Navigator', (
    tester,
  ) async {
    final coordinator = DismissLayerCoordinator();
    var dismissed = false;
    final handle = coordinator.register(
      id: 'guide-overlay',
      onEscape: () {
        dismissed = true;
        return DismissLayerResult.dismissed;
      },
    );

    final navigatorKey = await pumpHarness(
      tester,
      coordinator: coordinator,
      home: const Scaffold(body: Text('root')),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('child')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(find.text('child'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('descendant keyboard handler keeps priority over global Escape', (
    tester,
  ) async {
    var childHandledEscape = false;

    await pumpHarness(
      tester,
      home: Scaffold(
        body: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              childHandledEscape = true;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: const Text('focused-child'),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(childHandledEscape, isTrue);
    expect(find.text('focused-child'), findsOneWidget);
  });

  testWidgets('modified Escape is not treated as generic Back', (tester) async {
    final navigatorKey = await pumpHarness(
      tester,
      home: const Scaffold(body: Text('root')),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('child')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('Escape does not navigate away while editing on a page', (
    tester,
  ) async {
    final navigatorKey = await pumpHarness(
      tester,
      home: const Scaffold(body: Text('root')),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: TextField(
            autofocus: true,
            decoration: InputDecoration(labelText: 'Editing'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Escape respects PopScope instead of forcing a route pop', (
    tester,
  ) async {
    final navigatorKey = await pumpHarness(
      tester,
      home: const Scaffold(body: Text('root')),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const PopScope<Object?>(
          canPop: false,
          child: Scaffold(body: Text('protected-page')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('protected-page'), findsOneWidget);
  });

}
