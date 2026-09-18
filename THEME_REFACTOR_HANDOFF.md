# EduSheet App-Wide Day/Night + Workspace Colour Refactor

Source baseline: `EduSheet_GuidedDemoIsolation_FirstSave_Hotfix_Full.zip`

## Goal

Make Day/Night mode readable and consistent across the app, and make the selected Workspace colour a real app-wide accent instead of a mostly decorative setting.

## Architecture

- `EduSheetTheme` is the app-wide source of structural colours.
- The selected Workspace colour drives `ColorScheme.primary`, primary containers, focus states, selection states, buttons, navigation, switches, checkboxes, sliders, progress indicators, text selection, and lightly tinted app surfaces.
- Day mode uses high-contrast dark text on light surfaces.
- Night mode uses high-contrast light text on dark surfaces.
- `EduSheetSemanticColors` exposes named structural/semantic theme tokens to feature code.
- Teaching Planner now inherits the parent app brightness, structural surfaces, and Workspace primary accent instead of operating as an isolated blue theme.
- Theme transitions animate at the root `MaterialApp`.
- Theme persistence guards against a slow startup preference read overwriting a theme/accent changed by the user during startup.

## Representative feature propagation

Updated app chrome/structural UI in:

- Home
- Settings + live theme preview
- Saved Papers
- Question Bank
- Teaching Planner
- Calculator
- Document Reader shell
- PDF viewer chrome
- Word viewer surround
- Spreadsheet viewer toolbar/selection
- Presentation viewer toolbar/selection
- Text viewer
- OCR
- OMR Generator
- Word Converter
- Rating/support card

## Intentionally not recoloured by Workspace colour

These colours carry content meaning or must preserve output fidelity:

- PDF/Word/PowerPoint document content itself
- white paper/page preview canvases and printable document colours
- document-type identity colours (PDF red, Word blue, etc.)
- success, warning, error and destructive states
- difficulty/category/data-series colours where colour encodes meaning
- presentation-mode black surround where it is part of the viewing mode

## Validation performed in this environment

- All modified Dart files passed token-aware delimiter/structure validation.
- `git diff --check` reported no whitespace errors.
- Light text/surface contrast tokens were checked at approximately 17.75:1 (primary text) and 6.32:1 (muted text).
- Dark text/surface contrast tokens were checked at approximately 16.96:1 (primary text) and 8.37:1 (muted text).
- Theme tests were strengthened for contrast and shared interactive component propagation.
- Teaching Planner tests were updated to require inherited workspace accent and parent brightness.

Flutter/Dart SDK executables are not installed in this execution environment, so `flutter analyze` and `flutter test` could not be run here.

## Run locally

```powershell
flutter analyze --no-pub
flutter test test/shared/design/app_theme_test.dart
flutter test test/features/teaching_planner/teaching_planner_design_system_test.dart
flutter test
flutter run -d windows
```

For Android, use your normal connected-device target after the tests pass.
