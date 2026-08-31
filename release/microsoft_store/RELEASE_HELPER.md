# EduSheet release helper - Android and Windows

This file is the release contract for a human or AI preparing the next EduSheet package. Read it before changing versions or generating an MSIX. Update it in the same change as every release.

## Current release state

- Release date: 2026-08-30
- App version (`pubspec.yaml`): `1.2.2+5`
- Next MSIX version: `1.2.5.0`
- Windows architecture: `x64`
- Minimum Windows version: `10.0.17763.0`
- Distribution mode: Microsoft Store MSIX preparation
- Customer price: Free
- Microsoft premium checkout: Disabled (`PREMIUM_ENABLED=false`)
- Inactive future subscription product ID: `edusheet_premium_yearly`
- Google Play premium/subscription product: Store discovery enabled in the
  Android bundle; keep the product inactive so app use remains free
- Microsoft Store subscription add-on: Scaffold only; do not submit or publish
- Partner Center submission: Not performed
- Partner Center app state: `EduSheet` reserved and `In draft`
- Store ID: `9N0ZK8C31X94`
- Package identity name: `Baishalya.EduSheet`
- Package publisher: `CN=8A4649E8-2942-4B3D-9789-6B628C3C006F`
- Publisher display name: `Baishalya`
- Subscription add-on Store ID: `9PGCF60ZZ4ZC` (`edusheet_premium_yearly`, no submission started)
- Current Store package: `release/microsoft_store/packages/EduSheet_1.2.4.0_x64_store.msix`
- Current Store package SHA-256: update after the final package is generated
- Current QA package: `release/microsoft_store/packages/EduSheet_1.2.4.0_x64_qa.msix`
- Current QA SHA-256: update after the final package is generated

## Version mapping - do not improvise

EduSheet uses `major.minor.patch+build` in `pubspec.yaml`.

Example: `1.2.0+3` maps to MSIX `1.2.3.0`.

Partner Center requires the fourth MSIX version segment (the revision) to be `0`. EduSheet therefore maps `major.minor.patch+build` to `major.minor.build.0`. The Flutter build number must increase globally, including across semantic patch changes, and must be at most `65535`.

- `major`: incompatible or large product milestone.
- `minor`: meaningful features or platform release work.
- `patch`: fixes with no major product expansion; retained in the Flutter/Android version name.
- `build`: always increase globally for every uploaded artifact, including rebuilds of the same semantic version; this becomes the third MSIX segment.

For the next release:

1. Choose the semantic bump from the actual user-visible change.
2. Increase the build number; never reuse a Store package version.
3. Update `version:` and set `msix_config.msix_version` to `major.minor.build.0` in `pubspec.yaml`; the fourth segment must stay `0`.
4. Update `msix_config.output_name` so the filename contains the new four-part MSIX version.
5. Update the Current release state above.
6. Update Store listing/release notes when the package is an update rather than the first submission.
7. After packaging, record the exact package path and SHA-256 above.
8. Generated `.msix` files are intentionally git-ignored; archive the approved upload artifact separately.

## Free-access rule for the current product decision

The owner currently wants every user to use EduSheet for free until the Google
Play subscription is deliberately activated.

- Normal Microsoft Store release builds must use `PREMIUM_ENABLED=false`.
- All current workspace colour styles remain available.
- The Google Play AAB uses `PREMIUM_ENABLED=true`, but an inactive or missing
  product fails open and keeps every style free.
- Do not activate the paid Google Play product until purchase lifecycle and
  backend verification checks are complete.
- Do not create, submit, or activate the Microsoft subscription add-on.
- The inactive add-on code and metadata may remain ready for a future explicit decision.
- Use `PREMIUM_ENABLED=true` only for the Google Play build documented in
  `release/google_play/RELEASE_HELPER.md`; keep paid activation off until the
  purchase checks there are complete.

## Build the local QA MSIX

Run from PowerShell:

```powershell
.\release\microsoft_store\BUILD_QA_MSIX.ps1
```

This creates a locally signed QA package with the provisional local identity. It is for manifest/package testing and is not the file to upload to Partner Center.

## Build the Partner Center MSIX without submitting

The app name is already reserved. Re-check and copy these exact values from Product identity before every Store build:

- Package/Identity/Name
- Package/Identity/Publisher
- Package/Properties/PublisherDisplayName
- Microsoft Store product ID for the app (used by the rating link)

Then run:

```powershell
.\release\microsoft_store\BUILD_STORE_MSIX.ps1 `
  -IdentityName 'Baishalya.EduSheet' `
  -Publisher 'CN=8A4649E8-2942-4B3D-9789-6B628C3C006F' `
  -PublisherDisplayName 'Baishalya' `
  -MicrosoftStoreId '9N0ZK8C31X94'
```

The script builds with premium checkout disabled, creates an unsigned Store MSIX, verifies its identity/version/file associations, and stops. It never uploads or submits anything.

## Required verification before any upload

1. `flutter analyze`
2. `flutter test`
3. `flutter build windows --release --dart-define=PREMIUM_ENABLED=false`
4. `VERIFY_MSIX.ps1` passes.
5. Manifest identity exactly matches Partner Center.
6. Version is higher than every previously uploaded package.
7. App launches from the installed MSIX, not only from `flutter run`.
8. Create/edit/save/preview/export a representative paper.
9. Test PDF and Word output.
10. Test supported file associations from File Explorer.
11. Confirm premium screen says free access and no checkout is available.
12. Confirm website, privacy, support, and Store listing URLs are live.
13. Capture at least four Windows screenshots from this exact build.

## Files that must stay in sync

- `pubspec.yaml`
- `lib/core/config/app_config.dart`
- `lib/features/premium/`
- `windows/runner/Runner.rc`
- `release/microsoft_store/LISTING_EN_US.md`
- `release/microsoft_store/INACTIVE_SUBSCRIPTION_ADDON.md`
- `release/microsoft_store/RELEASE_HELPER.md`
- `release/google_play/RELEASE_HELPER.md`
- `privacy_policy.html`
- Live `https://baisalya.com/EduSheet/` pages

## Submission boundary

Generating a package is not submission. Do not reserve names, create add-ons, upload packages, start certification, publish, change pricing, or activate subscriptions unless the owner explicitly asks for that external action in the current request.
