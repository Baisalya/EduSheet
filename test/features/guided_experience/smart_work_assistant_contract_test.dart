import 'package:edusheet/features/guided_experience/guides/create_paper_guide.dart';
import 'package:edusheet/features/guided_experience/guides/create_syllabus_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher-facing Create Paper and Syllabus help waits about one minute', () {
    expect(
      createPaperContextualSuggestion.minimumInactivity,
      const Duration(minutes: 1),
    );
    expect(
      createSyllabusContextualSuggestion.minimumInactivity,
      const Duration(minutes: 1),
    );
  });

  test('assistant actions use plain non-technical wording', () {
    for (final suggestion in [
      createPaperContextualSuggestion,
      createSyllabusContextualSuggestion,
    ]) {
      expect(suggestion.primaryLabel, 'Show Me');
      expect(suggestion.secondaryLabel, 'Not Now');
      expect(suggestion.disableLabel, 'Turn Off');
    }
  });
}
