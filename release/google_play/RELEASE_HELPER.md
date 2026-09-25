# EduSheet Google Play release helper

Before running a command, read the release-mode gate in
`release/STORE_RELEASE_RUNBOOK.md`. If the owner's current request does not say
ads-ready Free closed test, ads-ready Free production promotion, or remote
Premium activation,
ask for that choice first. Never infer monetization from prepared billing code.

The AI may ask for one of three actions: QA only, AAB generation only, or a
Store action using an existing artifact. `BUILD_PLAY_AAB.ps1` never runs tests
or analysis and accepts no QA switch. Closed upload and Production promotion
reuse the exact existing AAB without rebuilding or retesting it.

## Current release contract

- Application ID: `com.baishalya.edusheet`
- Flutter source version: `1.2.3+8`
- Current built Play version code: `9` (built & verified; ready for Console upload)
- Next Play version code: `10` (for subsequent builds)
- Play version name: `1.2.3`
- Target SDK: Android 16 / API 36
- Customer price: Free
- App premium flag: `PREMIUM_ENABLED=true`
- Advertising flag: `ADS_ENABLED=true`
- Subscription product `edusheet_premium_yearly`: created; keep inactive/unpublished
- Planned base plan `monthly-premium`: not active, monthly auto-renewing
- Planned monthly price: India `INR 25.00`; the app displays Play's localized price
- Checkout and Free limits: remotely dormant while the base plan is inactive
- Entitlement verifier URL: embedded now so Premium can launch without an update

The current release is Free with ads and full feature access. Keep the base
plan inactive. Store discovery then exposes no checkout, while the compiled
billing/verifier path is ready for a later Console-only Premium launch.

## Build the ads-ready Free AAB

Before every Play upload, choose a version code higher than every previously
uploaded one. Since build code `9` is now built and verified, pass `-BuildNumber 10`
for any subsequent build to override the source default without changing the existing
Windows MSIX version. Google Play does not accept a previously uploaded code.

Run from the repository root:

```powershell
Set-Location 'C:\Users\baish\StudioProjects\EduSheet'
$env:EDUSHEET_ADMOB_APP_ID = 'ca-app-pub-1529558529658186~2744399552'
$env:ADMOB_ANDROID_HOME_BANNER_ID = 'ca-app-pub-1529558529658186/7280209238'
$env:ADMOB_ANDROID_HOME_INTERSTITIAL_ID = 'ca-app-pub-1529558529658186/4297813513'
$env:EDUSHEET_PURCHASE_VERIFICATION_URL = 'https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify'
.\release\google_play\BUILD_PLAY_AAB.ps1 -BuildNumber 10
```

The script cleans the build, restores dependencies, and builds the AAB. It
never runs tests or static analysis; run those separately only when QA is
requested. The release build is:

```powershell
flutter build appbundle --release --build-number=10 `
  --dart-define=PREMIUM_ENABLED=true `
  --dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly `
  --dart-define=ADS_ENABLED=true `
  --dart-define=ADMOB_ANDROID_HOME_BANNER_ID=<real banner ID> `
  --dart-define=ADMOB_ANDROID_HOME_INTERSTITIAL_ID=<real interstitial ID> `
  --dart-define=EDUSHEET_PURCHASE_VERIFICATION_URL=<production verifier URL>
```

Upload artifact:

```text
build/app/outputs/bundle/release/app-release.aab
```

Verified artifact (built via `BUILD_PLAY_AAB.ps1 -BuildNumber 9`):

```text
Path: build/app/outputs/bundle/release/app-release.aab
Size: 129,580,702 bytes (123.6MB)
SHA-256: D325AEAD99AF4F8A6171494E5C2D3E04470FB824BC463EC0C8840656E37899B6
Package/version: com.baishalya.edusheet / 1.2.3 (9)
Signature: verified release upload certificate
Mode: ads-ready Free; full feature access while base plan is inactive
All files access: MANAGE_EXTERNAL_STORAGE absent
Portable activation: .eds and .edtp MIME/extension intents present
```

`android/key.properties` and its private keystore must remain local and must
never be committed.

The full release build with version code 9 was executed and verified (`SHA-256: D325AEAD99AF4F8A6171494E5C2D3E04470FB824BC463EC0C8840656E37899B6`).
All unit tests and static analysis passed. This AAB is ready for upload to Google Play Console.

## Historical full-access/no-ads artifact (2026-09-13)

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

## Upload ads-ready Free release to Play Console

1. Confirm the AAB version code is higher than all prior Play uploads.
2. Open the required testing track and create a release.
3. Upload `app-release.aab` and confirm Play reads the expected version.
4. Use release notes that describe user-visible changes only.
5. Save, review, and submit the testing release.
6. Before testers open ads, mark the app/version as a test app in AdMob or add
   every device as a test device. Never click a production ad during QA.
7. Install from the tester invitation link and verify UMP consent, banner,
   every-second-return interstitial with a 10-second minimum gap (no daily
   app-side or AdMob cap), paper editing, exports, full feature access,
   and that no Subscribe/Buy checkout is available.
8. Promote the tested release to Production and reuse the same AAB.
9. Keep the Premium base plan inactive. Remove AdMob test-app mode only when
   public earning should start, then monitor readiness and invalid traffic.
10. Review countries and rollout percentage, then submit for Google review.

The Play Console subscription and base plan must stay inactive. This ads-ready
build contains the verifier URL for future use but does not call checkout while
the catalogue has no active product.

## Activate Google Play Free + Premium monetization later

Do these steps only after the owner explicitly launches Premium. The ads-ready
Production AAB does not need to be updated:

1. Keep core paper editing, three basic templates, five saved papers, two
   active classes, five monthly PDF exports, and personal `.eds`
   backup/restore on Free. Premium adds unlimited usage, Word export, all
   templates/branding, advanced planner/analytics/scheduling/curriculum/bulk
   operations, and removes ads. Existing data remains viewable and editable.
2. Under product `edusheet_premium_yearly` (an opaque legacy ID), prepare base
   plan `monthly-premium`. Set India to `INR 25.00`, configure a seven-day grace
   period, countries, tax, account hold and localized text, but keep it inactive
   until backend validation is complete. Keep the old annual draft inactive.
3. Enable EduSheet in the entitlement API registry, deploy it, and validate
   active, invalid, expired, grace and account-hold responses.
4. Confirm this verifier is live:
   `https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify`.
5. Confirm the installed Production AAB was built with the ads-ready flags and
   matching verifier URL documented above. Otherwise an app update is required.
6. Test consent, preload/failure, interstitial cadence and accidental-click spacing,
   purchase, pending payment, cancellation, restore, renewal, expiry, the full
   seven-day grace period, account hold, invalid token, quota rollover, and
   temporary verifier failure using Play license testers.
7. Verify that Premium users see no ads; expired users retain existing-data
   editing and personal backup/restore, while only new Premium operations are
   restricted after grace.
8. Activate `monthly-premium`, allow catalogue propagation, and cold-start the
   installed Production app. Confirm localized checkout appears without an app
   update.
9. Record the backend version, activation timestamp and rollback owner. To stop
   new purchases, deactivate the base plan; existing subscriptions require
   separate Play order/subscription handling.

The verifier URL handles Google Play only. It must never be used as Microsoft
Store purchase verification.

Generating an AAB does not upload or publish it.
