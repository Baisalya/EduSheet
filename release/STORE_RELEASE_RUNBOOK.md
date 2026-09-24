# EduSheet Store release runbook

This is the operating contract for a human or AI releasing EduSheet. Read the
whole file, inspect `release/RELEASE_LOG.md`, and update the log after every
build, upload, submission, rejection, approval, rollout, or monetization change.

## AI start here: choose the release mode

Before running any build, upload, or Store command, inspect the owner's current
request. If it does not explicitly select a mode, ask exactly:

```text
EduSheet release mode kaunsa chahiye?
1. Google Play ads-ready Free closed test
2. Google Play ads-ready Free production promotion
3. Activate Google Play Premium remotely
4. Microsoft Store remote-ready Free release
```

Do not infer a paid release from billing code, product IDs, or prepared Store
records. If the answer is missing or unclear, stop before building and leave the
current Free configuration and inactive products unchanged.

Follow only the matching path:

- **1 — Google ads-ready Free closed test:** use `BUILD_PLAY_AAB.ps1`. Keep the
  Premium base plan inactive, configure the AdMob app/version as a test app,
  and test real ad-unit wiring without generating live ad traffic.
- **2 — Google ads-ready Free production promotion:** promote only the exact
  AAB that passed closed testing. Do not rebuild it. Keep the Premium base plan
  inactive; remove AdMob test-app mode only when public traffic should earn.
- **3 — Activate Google Premium remotely:** do not upload a new AAB. First
  enable and verify the entitlement backend, then activate the prepared monthly
  base plan. The installed ads-ready AAB discovers it on a fresh app launch.
- **4 — Microsoft remote-ready Free:** use `BUILD_STORE_MSIX.ps1`. The package
  includes the official `Windows.Services.Store` subscription bridge and exact
  add-on product ID, but the unpublished/inactive add-on keeps checkout hidden
  and grants complimentary full access. Do not submit or publish the add-on
  until the separate activation checklist passes.

### QA is separate from AAB/MSIX packaging

After the release mode is known, treat these as independent jobs:

1. QA/testing only.
2. Android AAB packaging only.
3. Windows MSIX packaging only.
4. Store upload or promotion of an existing artifact.

Do not automatically run the full Flutter test suite because an AAB or MSIX was
requested. If the owner says the current source is already tested, use the
default packaging-only command and record the reused QA evidence in
`release/RELEASE_LOG.md`. Fresh QA is required only when explicitly requested,
when source/dependency/build configuration changed after that evidence, or when
the owner chooses it because no usable evidence exists. Store upload and
Production promotion never rebuild the artifact.

QA-only commands:

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

## Product decision in force

EduSheet Android is an ads-supported Free app. The current closed-test and
first Production release must show consent-managed ads while keeping every
feature available. The Premium product stays inactive, so checkout and Free
feature limits do not appear yet. Microsoft Store remains full-access and
ad-free while its add-on is unpublished or unavailable.

Current Google Play builds must contain:

```text
PREMIUM_ENABLED=true
ADS_ENABLED=true
PREMIUM_PRODUCT_ID=edusheet_premium_yearly
EDUSHEET_PURCHASE_VERIFICATION_URL=<production HTTPS verifier>
```

The AdMob app, banner and interstitial IDs must also be supplied at build time.
With the Play base plan inactive, store discovery returns no sellable product;
EduSheet therefore grants complimentary full feature access, keeps checkout
unavailable, and continues showing Free-plan ads. When the owner later
activates the base plan, the same installed AAB switches to the documented
Free/Premium boundary on its next store refresh—no app update is required.

The Microsoft Store package follows the same fail-open catalogue pattern but
does not contain Google ads. It is compiled with `PREMIUM_ENABLED=true` and the
Partner Center product ID `edusheet_premium_yearly`. While that add-on is
unpublished or unavailable, EduSheet grants complimentary full access and does
not show checkout. After the add-on is submitted, published and available, the
same installed MSIX can discover it on a cold launch/store refresh without an
app update. Active ownership is read through the official Store license APIs;
an inactive or expired license does not restore Premium.

## Store identities and versions

| Field | Current value |
| --- | --- |
| Flutter source version | `1.2.3+8` (Windows package remains `1.2.8.0`) |
| Android package | `com.baishalya.edusheet` |
| Next Play version name | `1.2.3` |
| Current Play version code | `9` (built and verified; ready for Console upload) |
| Next Play version code | `10` (for subsequent build/upload) |
| Existing Play product | `edusheet_premium_yearly` (created, inactive; opaque legacy ID) |
| Planned Play base plan | `monthly-premium` (new, inactive; monthly auto-renewing) |
| Planned Play monthly price | India `INR 25.00`; final localized price comes from Play |
| Microsoft Store ID | `9N0ZK8C31X94` |
| MSIX identity | `Baishalya.EduSheet` |
| MSIX publisher | `CN=8A4649E8-2942-4B3D-9789-6B628C3C006F` |
| Publisher display name | `Baishalya` |
| MSIX architecture | `x64` |
| MSIX version | `1.2.8.0` |
| Planned Microsoft add-on Store ID | `9PGCF60ZZ4ZC` (inactive) |
| Planned Microsoft product ID | `edusheet_premium_yearly` (inactive) |
| Google verifier prepared for later | `https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify` |

The Google verifier does not verify Microsoft purchases. Windows uses the
official packaged-app `StoreContext` product, purchase and active-license APIs;
never reuse the Google verification endpoint for a Microsoft transaction.

## Version rules

Flutter uses `major.minor.patch+build`.

- Increase the effective Android build code before every Play upload. Never
  reuse a version code, even for a rejected or deleted draft.
- Build code `9` is current, built, and verified. For any subsequent Android release,
  pass `-BuildNumber 10` (or a higher unused code) to the script. Never upload an old
  version code.
- Android's `--build-number` override does not change the already-generated
  Windows MSIX. Keep its `1.2.8.0` identity unchanged for this Android-only
  release.
- Microsoft maps `major.minor.patch+build` to `major.minor.build.0`. Therefore
  `1.2.3+8` maps to `1.2.8.0`.
- Keep the fourth MSIX segment at `0`. The build number must be globally
  increasing and at most `65535`.
- When the Flutter build changes, update both `msix_config.msix_version` and
  `msix_config.output_name` in `pubspec.yaml` before packaging.
- Confirm Partner Center has never received the chosen MSIX version. If
  `1.2.8.0` was used, increase the Flutter build and generate the matching MSIX.

## Build and verify the ads-ready Free Google Play AAB

The AdMob app and two production ad units already exist. From PowerShell, run
this exact command block for any subsequent build (passing `-BuildNumber 10`).
It **builds locally only**; it does not upload to Google Play.

```powershell
Set-Location 'C:\Users\baish\StudioProjects\EduSheet'
$env:EDUSHEET_ADMOB_APP_ID = 'ca-app-pub-1529558529658186~2744399552'
$env:ADMOB_ANDROID_HOME_BANNER_ID = 'ca-app-pub-1529558529658186/7280209238'
$env:ADMOB_ANDROID_HOME_INTERSTITIAL_ID = 'ca-app-pub-1529558529658186/4297813513'
$env:EDUSHEET_PURCHASE_VERIFICATION_URL = 'https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify'
.\release\google_play\BUILD_PLAY_AAB.ps1 -BuildNumber 10
```

The default command is packaging-only: it rejects missing/malformed IDs and
Google sample IDs, runs clean/dependency restore, builds the AAB, then verifies
its identity/version and records its hash. To run fresh QA in the same
invocation, append `-RunQualityChecks`:

```powershell
.\release\google_play\BUILD_PLAY_AAB.ps1 -BuildNumber 10 -RunQualityChecks
```

The release build is equivalent to:

```powershell
flutter build appbundle --release --build-number=10 `
  --dart-define=PREMIUM_ENABLED=true `
  --dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly `
  --dart-define=ADS_ENABLED=true `
  --dart-define=ADMOB_ANDROID_HOME_BANNER_ID=<real banner ID> `
  --dart-define=ADMOB_ANDROID_HOME_INTERSTITIAL_ID=<real interstitial ID> `
  --dart-define=EDUSHEET_PURCHASE_VERIFICATION_URL=<production verifier>
```

Verified Android artifact (built via `BUILD_PLAY_AAB.ps1 -BuildNumber 9`):

```text
Path: C:\Users\baish\StudioProjects\EduSheet\build\app\outputs\bundle\release\app-release.aab
Size: 129,580,702 bytes (123.6MB)
SHA-256: D325AEAD99AF4F8A6171494E5C2D3E04470FB824BC463EC0C8840656E37899B6
Package: com.baishalya.edusheet
Version name/code: 1.2.3 / 9
Mode: ads-ready Free; full feature access while base plan is inactive
Interstitial: every second completed Home return, at least 10 seconds after
  the prior show, no app-side or AdMob daily cap
Production AdMob app/banner/interstitial IDs embedded: yes
Verifier URL embedded: yes
Portable activation: .eds and .edtp MIME/extension intents present
All files access: MANAGE_EXTERNAL_STORAGE absent
Signature: verified release upload certificate
```

The full release build with version code 9 completed successfully (`SHA-256: D325AEAD99AF4F8A6171494E5C2D3E04470FB824BC463EC0C8840656E37899B6`).
All 1,012 unit tests and static analysis passed (`No issues found!`). This artifact is verified and ready for Play Console upload.

Before upload, verify or cite existing evidence for:

1. Tests pass.
2. Analysis contains no errors or warnings. Existing info-level style findings
   may be recorded but cannot hide an error or warning.
3. AAB signature verifies and is not the Android debug certificate.
4. Manifest package and version match this runbook.
5. `PREMIUM_ENABLED=true`, `ADS_ENABLED=true`, both production ad-unit IDs and
   the production verifier URL are present.
6. No Google sample/test ID is embedded in the release manifest or Dart
   defines.
7. `MANAGE_EXTERNAL_STORAGE` is absent. The legacy plugin permission
   `READ_EXTERNAL_STORAGE` is capped at Android 12L (`maxSdkVersion=32`), while
   modern file opening uses scoped content URIs and the Storage Access
   Framework.
8. The Premium base plan remains inactive, so this AAB shows ads with full
   feature access and cannot start checkout.

## Upload and release the ads-ready Free Android app

1. Open Play Console for EduSheet and inspect the highest uploaded version code.
2. Confirm the newly built code `9` is unused. If it exists anywhere, choose
   a higher unused code and rebuild with that `-BuildNumber` value first.
3. Open the required internal or closed testing track and create a release.
4. Upload `app-release.aab`.
5. Confirm Play shows the expected package, version name, version code, target
   API, signing certificate, and supported devices.
6. Add release notes, save, review, and submit the testing release.
7. In AdMob, mark this app/version as a test app (or register every tester
   device) before testers open ads. Never click production ads during QA.
8. Install only from the testing invitation link and test launch, UMP consent,
   labelled banner, a preloaded interstitial opportunity on the second
   completed Home return (subject to a 10-second minimum gap and preload;
   there is no app-side or AdMob ad-unit daily cap),
   failed ad loads,
   paper editing, exports, and file permissions.
9. Confirm every current feature is available and no Subscribe/Buy button can
   launch checkout while the base plan is inactive.
10. Promote the exact tested AAB to Production. Do not rebuild it.
11. Keep the base plan inactive. When public ad earning should begin, remove
    the AdMob test-app/version setting and monitor invalid-traffic/readiness
    status. Closed/private Play availability cannot complete AdMob public app
    readiness, so limited serving before public approval is expected.
12. Review countries, staged rollout, policy declarations, Data safety, and app
    content, then submit for review.
13. After approval, publish with Managed publishing or let the approved rollout
    start, according to the owner's instruction.
14. Record the release ID, track, review state, rollout percentage, timestamps,
    artifact hash, and console URL in `release/RELEASE_LOG.md`.

Keep product `edusheet_premium_yearly` and every base plan inactive. A free
AAB compiled with the ads-ready flags above can expose Premium later without an
app update. Inactive product means full feature access plus ads; activating the
monthly base plan makes the existing app expose checkout and the documented
Free limits after its next store refresh.

## Build and verify the remote-ready Free Microsoft Store MSIX

From the repository root run:

```powershell
.\release\microsoft_store\BUILD_STORE_MSIX.ps1 `
  -IdentityName 'Baishalya.EduSheet' `
  -Publisher 'CN=8A4649E8-2942-4B3D-9789-6B628C3C006F' `
  -PublisherDisplayName 'Baishalya' `
  -MicrosoftStoreId '9N0ZK8C31X94'
```

That is the packaging-only command. Add `-RunQualityChecks` only when fresh
analysis/tests are wanted in the same invocation. `-SkipChecks` remains accepted
for older automation but is no longer necessary because packaging-only is the
default.

The script builds Windows with `PREMIUM_ENABLED=true`, the known Microsoft
product ID and Store ID. Because the add-on is still unpublished/unavailable,
runtime discovery fails open to complimentary full access and no checkout is
shown. The script creates an unsigned Store package, verifies identity/version
plus document, `.eds` and `.edtp` file associations, and never uploads or
submits anything.

Expected current artifact:

```text
Path: C:\Users\baish\StudioProjects\EduSheet\release\microsoft_store\packages\EduSheet_1.2.8.0_x64_store.msix
Size: 34,147,922 bytes
SHA-256: AA9DFF6AC2240FD35556206AAD6A74444371CEEE828551BC4CCA8E08987A3CD9
Identity: Baishalya.EduSheet
Publisher: CN=8A4649E8-2942-4B3D-9789-6B628C3C006F
Version: 1.2.8.0
Architecture: x64
Signature: NotSigned (correct for this Partner Center upload artifact)
Mode: remote-ready Free; complimentary full access while add-on is unavailable
```

For local install testing, use `BUILD_QA_MSIX.ps1`; do not upload the QA package
to Partner Center.

## Upload and release the free Windows app

1. Open Partner Center, select EduSheet, and create/open the application
   submission.
2. Check Product identity against this runbook.
3. Check the highest package version. Rebuild with a higher mapped version if
   `1.2.8.0` has already been uploaded.
4. Set the base app price to Free and complete markets, properties, age rating,
   privacy/support URLs, listing text, images, and certification notes.
5. Upload `EduSheet_1.2.8.0_x64_store.msix` to Packages.
6. Confirm Partner Center accepts identity, publisher, architecture, minimum OS,
   and version.
7. Do not include, submit or publish add-on `9PGCF60ZZ4ZC`; leaving it
   unavailable is what keeps this release complimentary and checkout-free.
8. Run Partner Center validation, review the submission, and submit the free app
   for certification only when the owner asks for the external submission.
9. After certification, publish the free app with the requested visibility and
   record every status change in `release/RELEASE_LOG.md`.

Uploading this MSIX or promoting an Android Closed release is a Store action.
Do not rebuild either artifact and do not rerun the full Flutter suite during
that action; use its recorded version, hash, build flags, and QA evidence.

## Activate Google Play Free + Premium monetization later

The ads-ready AAB already contains billing, verifier and freemium support.
Premium activation is a controlled Console/backend operation and does not
require another app update:

1. Confirm the boundary: Free keeps core editing, three basic templates, five
   saved papers, two active classes, five PDF exports per month, and personal
   `.eds` backup/restore. Premium adds unlimited usage, Word export, all
   templates/branding, advanced planner/analytics/scheduling/curriculum/bulk
   operations, and removes ads. Existing work must always remain viewable and
   editable. Never replace a navigation option with an ad.
2. Under the existing opaque product ID `edusheet_premium_yearly`, prepare the
   monthly auto-renewing base plan `monthly-premium`, targeting India at
   `INR 25.00`, with a seven-day grace period. Leave it inactive until every
   following prerequisite passes; keep the old annual draft inactive.
3. Set EduSheet `verificationEnabled: true` in the entitlement API registry,
   deploy it, and verify live valid, invalid, expired, grace and account-hold
   responses. This must happen before plan activation.
4. Confirm the exact Production AAB was built with `PREMIUM_ENABLED=true`, the
   matching product ID and the live verifier URL. If not, stop: remote launch
   is impossible for that installed build and an app update is required.
5. Use Play license testers to activate/test the plan before general
   availability if Play Console permits the prepared test configuration. Test
   purchase, pending payment, cancellation, refund, restore, renewal, expiry,
   the full seven-day grace period, account hold, invalid token, quota rollover
   and offline/retry behavior.
6. Confirm ads disappear with Premium access, expiry restricts only new
   Premium operations after grace, existing data remains editable, and
   personal backup/restore stays available.
7. Activate `monthly-premium`. Do not upload or rebuild the app. Allow Play
   catalogue propagation, then cold-start an installed Production build and
   confirm localized ₹25/month checkout appears.
8. Record backend version, base-plan status/time, verification evidence and
   rollback owner in `release/RELEASE_LOG.md`.

Rollback: deactivate the base plan to prevent new purchases. Existing
subscriptions may continue renewing, so use Play order/subscription controls if
billing must also stop for existing customers. Never disable verification while
any active or grace-period entitlement exists.

## Activate Microsoft monetization later

The `1.2.8.0` MSIX already contains the official `StoreContext` catalogue,
purchase and active-license flow. Publishing the matching add-on can therefore
expose Premium to the same installed app without another MSIX update. Before
activation:

1. Confirm the installed Store build is exactly `1.2.8.0` (or a later package
   built with `PREMIUM_ENABLED=true`) and contains product ID
   `edusheet_premium_yearly`.
2. Complete and privately validate the subscription add-on submission for
   Store ID `9PGCF60ZZ4ZC`: product ID, recurring period, price, markets,
   privacy/support text and reviewer notes must match this runbook.
3. Test catalogue discovery, purchase, cancellation, refund, restore, renewal,
   expiry, Microsoft grace handling, offline licence and account switching with
   Partner Center test accounts/private availability. The native bridge must
   restore Premium only when the matching Store license is active.
4. Confirm Free limits affect only new operations. File opening/inspection,
   existing documents, existing paper/class editing and personal `.eds`
   backup/restore must remain available after expiry.
5. Publish/make the add-on available without uploading another MSIX. Allow
   Store catalogue propagation, then cold-start the already installed Store
   package and confirm localized checkout appears.
6. Record add-on submission ID, availability time, markets, price, test
   evidence and rollback owner in `release/RELEASE_LOG.md`.

Rollback: remove/deactivate add-on availability to stop new purchases. Existing
subscriber renewals and refunds must be managed through Partner Center; never
pretend that hiding checkout cancels an existing subscription.

## Failure and rollback rules

- If checkout appears while the base plan is intended to be inactive, stop the
  rollout and inspect Play product availability; do not disable ads-ready code.
- If Microsoft checkout appears before the add-on launch, stop rollout and
  inspect add-on availability/market targeting. Do not rebuild merely to hide a
  product that should still be unpublished.
- If ads appear for a verified paid/grace user, stop rollout or deactivate the
  base plan until entitlement restoration is fixed.
- If a version was uploaded, never reuse it; increase the build/version.
- If Google server verification or Microsoft Store active-license validation is
  unavailable during a future paid rollout, pause activation and keep the
  fail-open complimentary state instead of blocking teachers.
- Never place a service-account JSON key in source, build flags, AAB, MSIX, or
  logs. Do not rotate the existing key unless the owner explicitly requests it.
- Generated packages are git-ignored. Preserve the approved artifact and its
  hash in a controlled release archive.
