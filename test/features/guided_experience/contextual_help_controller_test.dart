import 'package:edusheet/features/guided_experience/application/contextual_help_controller.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryContextualHelpRepository
    implements ContextualHelpPreferencesRepository {
  _MemoryContextualHelpRepository([ContextualHelpPreferences? initial])
      : value = initial ?? ContextualHelpPreferences();

  ContextualHelpPreferences value;
  int saveCount = 0;

  @override
  Future<ContextualHelpPreferences> load() async => value;

  @override
  Future<void> save(ContextualHelpPreferences preferences) async {
    saveCount += 1;
    value = preferences;
  }
}

void main() {
  test('helper setting is local, persisted, and defaults enabled', () async {
    final repository = _MemoryContextualHelpRepository();
    final controller = ContextualHelpController(repository);

    await controller.load();
    expect(controller.state.helperEnabled, isTrue);

    await controller.setHelperEnabled(false);
    expect(controller.state.helperEnabled, isFalse);
    expect(repository.value.helperEnabled, isFalse);
    expect(repository.saveCount, 1);
  });

  test('Not Now snoozes only that suggestion and records session offer', () async {
    final repository = _MemoryContextualHelpRepository();
    final controller = ContextualHelpController(repository);
    final now = DateTime(2026, 9, 16, 12);

    await controller.load();
    await controller.snooze(
      'planner.syllabus',
      duration: const Duration(hours: 24),
      now: now,
    );

    expect(controller.wasOfferedThisSession('planner.syllabus'), isTrue);
    expect(
      controller.state.preferences?.snoozedUntilBySuggestion['planner.syllabus'],
      now.add(const Duration(hours: 24)),
    );
    expect(
      controller.state.preferences?.snoozedUntilBySuggestion['paper.create'],
      isNull,
    );
  });
}
