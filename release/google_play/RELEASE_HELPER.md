# EduSheet Google Play release helper

Before running a command, read the release-mode gate in
`release/STORE_RELEASE_RUNBOOK.md`. If the owner's current request does not say
Free, Google Play private/closed subscription test, or production promotion,
ask for that choice first. Never infer monetization from prepared billing code.

## Current release contract

- Application ID: `com.baishalya.edusheet`
- Flutter version: `1.2.2+5`
- Play version name: `1.2.2`
- Play version code: `5`
- Target SDK: Android 16 / API 36
- Customer price: Free
- App premium flag: `PREMIUM_ENABLED=false`
- Subscription product `edusheet_premium_yearly`: keep inactive/unpublished
- Base plan `annual`: future use only
- Checkout, paywall, and entitlement verification: inactive in this build

The current release is intentionally free. Do not add a purchase verifier URL
or set `PREMIUM_ENABLED=true` in an AAB intended for this release.

## Build the free AAB

Before every Play upload, increase the number after `+` in `pubspec.yaml`.
Google Play does not accept a version code that has already been uploaded.

Run from the repository root:

```powershell
.\release\google_play\BUILD_PLAY_AAB.ps1
```

The script cleans the build, restores dependencies, runs all tests and static
analysis, then builds exactly:

```powershell
flutter build appbundle --release --dart-define=PREMIUM_ENABLED=false
```

Upload artifact:

```text
build/app/outputs/bundle/release/app-release.aab
```

`android/key.properties` and its private keystore must remain local and must
never be committed.

## Verified free artifact (2026-09-13)

- Path: `build/app/outputs/bundle/release/app-release.aab`
- Size: `111,300,918` bytes
- SHA-256: `CB7179AA860E9812AE6B78F6EEDA30CD8940789874E6765A568B11CF981BEA05`
- Manifest: package `com.baishalya.edusheet`, version code `5`, version name
  `1.2.2`
- Signature: verified
- Premium flag: false
- Entitlement API URL in release native libraries: absent
- Billing permission: present because future billing support remains compiled;
  runtime store discovery and checkout are disabled by the premium flag

## Upload free release to Play Console

1. Confirm the AAB version code is higher than all prior Play uploads.
2. Open the required testing track and create a release.
3. Upload `app-release.aab` and confirm Play reads the expected version.
4. Use release notes that describe user-visible changes only.
5. Save, review, and submit the testing release.
6. Install from the tester invitation link and verify app launch, paper editing,
   save/open, PDF/Word export, and that no Subscribe/Buy checkout is available.
7. Promote the tested release to Production and reuse the same AAB.
8. Review countries and rollout percentage, then submit for Google review.

The Play Console subscription and base plan must stay inactive. The free build
does not depend on the entitlement API.

## Activate Google Play monetization later

Do these steps only after the owner explicitly changes EduSheet from free to
paid:

1. Review the paid feature boundary and user-facing price disclosures.
2. Activate product `edusheet_premium_yearly` and base plan `annual` in Play
   Console, with price, countries, tax, grace period, account hold, and localized
   text completed.
3. Enable EduSheet in the entitlement API registry and deploy it.
4. Confirm this verifier is live:
   `https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify`.
5. Increase the version code and build a private paid-test AAB with:

```powershell
flutter build appbundle --release `
  --dart-define=PREMIUM_ENABLED=true `
  --dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly `
  --dart-define=EDUSHEET_PURCHASE_VERIFICATION_URL=https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify
```

6. Test purchase, pending payment, cancellation, restore, renewal, expiry,
   grace period, account hold, invalid token, and temporary verifier failure
   using Play license testers.
7. Promote that exact tested paid AAB from closed testing to Production.

The verifier URL handles Google Play only. It must never be used as Microsoft
Store purchase verification.

Generating an AAB does not upload or publish it.
