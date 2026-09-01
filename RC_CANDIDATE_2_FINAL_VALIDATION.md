# EduSheet RC Candidate 2 — Final Real-device & Release Validation

Baseline: Professional Formatting Phase 3 QA Fix 1, Windows automated QA green (`flutter analyze` clean, Phase 3 focused gates green, release suite green, full suite +327).

## Goal

No new editor architecture or formatting feature work. RC2 is a release-hardening pass that validates the now-complete Smart/Word authoring, professional formatting, WYSIWYG page/header system, exports, recovery, responsiveness and production builds as one candidate.

## Automated gate

Use:

```powershell
.\tool\run_rc_candidate_2_gate.ps1
.\tool\run_rc_candidate_2_gate.ps1 -BuildWindows -BuildAndroid
```

The gate fails immediately on any non-zero native command and checks:

1. formatting
2. analyzer
3. PDF font/offline export, autosave, large-paper, page-layout, dual-editor, Phase-3 WYSIWYG and Office export focused tests
4. all release tests
5. full regression suite
6. optional Windows release build + artifact existence
7. optional Android release APK + artifact existence
8. reminder that real-device smoke is still required

## Windows manual smoke

- Launch the **release build**, not `flutter run`.
- Create a paper with at least 3 sections using different Phase-1/2 formatting settings.
- Switch Smart -> Word -> Preview -> Word -> Smart repeatedly; verify no content/marks/header changes.
- Test A4 portrait, A4 landscape and one non-A4 page size.
- Change margins and verify Word Mode and Preview keep the same page geometry.
- Test Board/Academic/Modern header templates.
- Use Arrange Header: drag, resize, snap, align, add text/line, save as custom template, reopen it.
- Test a two-column template with enough questions to wrap to the next column/page.
- Resize the app from narrow (~520 px) to maximized while editing.
- Type into a rich-text question, open Math/Geometry, close it and verify cursor/focus return.
- Export PDF offline with English + Hindi/Odia + `− × ÷ √ π` and inspect every glyph.
- Export DOCX, open in Microsoft Word, make a supported tagged edit and import it back.
- Verify header/footer/page number/manual page breaks/images/tables survive Preview/PDF/DOCX.
- Kill/restart during unsaved editing and verify autosave/recovery behavior.

## Android manual smoke

- Install the **release APK** on a physical device.
- Test a 360-ish dp phone width with the software keyboard open.
- Confirm Add Section and primary Word actions remain reachable without awkward scrolling.
- Create/edit a long question and verify cursor remains visible as the keyboard opens/closes.
- Insert Math and Geometry; verify focus/cursor/scroll position on return.
- Switch Smart <-> Word repeatedly after unsaved typing.
- Test header templates and Word/Preview parity on portrait and landscape.
- Test Page Setup without overflow/SafeArea/back-navigation issues.
- Export PDF with network disabled using English + Hindi/Odia + `− × ÷ √ π`; open/share the file and inspect glyphs.
- Test page break, header/footer, image, table and two-column output.
- Background/kill/reopen during an unsaved paper and verify recovery.

## Release lock rule

RC2 can be locked only when:

- analyzer is clean;
- focused tests pass;
- release tests pass;
- full test suite passes;
- Windows release build succeeds;
- Android release APK succeeds;
- Windows manual smoke passes;
- Android manual smoke passes;
- offline multilingual/math PDF visually renders correctly.

Warnings from legacy Google-font fallbacks are not blockers by themselves. Missing or broken glyphs in the actual offline exported PDF are blockers.
