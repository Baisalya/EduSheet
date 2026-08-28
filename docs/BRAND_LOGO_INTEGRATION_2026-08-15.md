# EduSheet Brand Logo Integration — 2026-08-15

## Scope
Integrated the approved text-free EduSheet brand mark consistently across Android, Windows, Web/PWA, and the Flutter home shell.

## Changes
- Replaced `assets/Applogo.png` with an optimized 512×512 brand asset.
- Added `assets/branding/edusheet_brand_mark.png` for explicit in-app use.
- Added the brand mark beside the existing EduSheet home title. The logo artwork itself contains no app name/text.
- Rebuilt Android legacy launcher icons for mdpi through xxxhdpi.
- Rebuilt Android adaptive icon foregrounds and changed the adaptive background to deep navy (`#061B5C`).
- Rebuilt `windows/runner/resources/app_icon.ico` with 16–256 px embedded resolutions.
- Rebuilt Web/PWA favicon, standard icons, and maskable icons.
- No dependency changes and no feature/business-logic changes.

## Runtime QA still required
Run on the target Flutter SDK/platform toolchains:

```powershell
flutter analyze
flutter test
flutter run -d windows
```

Also build/install Android and visually check launcher masking on at least one round and one squircle launcher style.
