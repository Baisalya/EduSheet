import 'package:edusheet/features/guided_experience/data/shared_preferences_contextual_help_repository.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists helper preference and per-suggestion snooze locally', () async {
    final repository = SharedPreferencesContextualHelpRepository();
    final snoozedUntil = DateTime(2026, 9, 17, 12);

    await repository.save(
      ContextualHelpPreferences(
        helperEnabled: false,
        snoozedUntilBySuggestion: <String, DateTime>{
          'planner.syllabus': snoozedUntil,
        },
      ),
    );

    final loaded = await repository.load();
    expect(loaded.helperEnabled, isFalse);
    expect(
      loaded.snoozedUntilBySuggestion['planner.syllabus'],
      snoozedUntil,
    );
  });

  test('malformed helper metadata fails open to safe local defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'guided_experience.contextual_help': '{broken-json',
    });

    final loaded = await SharedPreferencesContextualHelpRepository().load();
    expect(loaded.helperEnabled, isTrue);
    expect(loaded.snoozedUntilBySuggestion, isEmpty);
  });
}
