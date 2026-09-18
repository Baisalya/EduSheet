import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/contextual_help_prompt.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/smart_work_activity_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _suggestion = ContextualHelpSuggestion(
  id: 'planner.syllabus.widget',
  screen: GuidedScreenContext.teachingPlanner,
  title: 'Need help setting up your syllabus?',
  message: 'Your syllabus setup is incomplete.',
  requiresIncompleteAction: true,
);

const _signals = ContextualHelpSignals(
  currentScreen: GuidedScreenContext.teachingPlanner,
  hasIncompleteAction: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('contextual offer is non-blocking and Show Me uses real callback', (
    tester,
  ) async {
    var showMeCount = 0;
    var backgroundTapCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ContextualHelpOffer(
              suggestion: _suggestion,
              signals: _signals,
              onShowMe: () => showMeCount += 1,
              child: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () => backgroundTapCount += 1,
                  child: const Text('Background action'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Need help setting up your syllabus?'), findsOneWidget);

    await tester.tap(find.text('Background action'));
    await tester.pump();
    expect(backgroundTapCount, 1);

    await tester.tap(find.text('Show Me'));
    await tester.pump();
    expect(showMeCount, 1);
    expect(find.text('Need help setting up your syllabus?'), findsNothing);
  });

  testWidgets('Show Me remains tappable inside the app-wide activity host', (
    tester,
  ) async {
    var showMeCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SmartWorkActivityHost(
            child: Scaffold(
              body: ContextualHelpOffer(
                suggestion: _suggestion,
                signals: _signals,
                onShowMe: () => showMeCount += 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show Me'), findsOneWidget);
    await tester.tap(find.text('Show Me'));
    await tester.pump();

    expect(showMeCount, 1);
    expect(find.text('Show Me'), findsNothing);
  });

  testWidgets('Not Now hides the current prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ContextualHelpOffer(
              suggestion: _suggestion,
              signals: _signals,
              onShowMe: _noop,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not Now'), findsOneWidget);

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('Not Now'), findsNothing);
  });

  testWidgets('Turn Off disables future Smart Work Assistant offers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ContextualHelpOffer(
              suggestion: _suggestion,
              signals: _signals,
              onShowMe: _noop,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Turn Off'), findsOneWidget);

    await tester.tap(find.text('Turn Off'));
    await tester.pumpAndSettle();

    expect(find.text('Smart Work Assistant'), findsNothing);
    expect(find.text('Turn Off'), findsNothing);
  });

  testWidgets('persisted helper disable prevents contextual offers', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'guided_experience.contextual_help':
          '{"helperEnabled":false,"snoozedUntilBySuggestion":{}}',
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ContextualHelpOffer(
              suggestion: _suggestion,
              signals: _signals,
              onShowMe: _noop,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Need help setting up your syllabus?'), findsNothing);
  });
}

void _noop() {}
