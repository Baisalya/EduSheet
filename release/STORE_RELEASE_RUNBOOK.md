# EduSheet Store release runbook

This is the operating contract for a human or AI releasing EduSheet. Read the
whole file, inspect `release/RELEASE_LOG.md`, and update the log after every
build, upload, submission, rejection, approval, rollout, or monetization change.

## AI start here: choose the release mode

Before running any build, upload, or Store command, inspect the owner's current
request. If it does not explicitly select a mode, ask exactly:

```text
EduSheet release mode kaunsa chahiye?
1. Free on Google Play and Microsoft Store
2. Google Play subscription private/closed test
3. Google Play subscription production promotion
4. Microsoft Store monetized release
```

Do not infer a paid release from billing code, product IDs, or prepared Store
records. If the answer is missing or unclear, stop before building and leave the
current Free configuration and inactive products unchanged.

Follow only the matching path:

- **1 — Free:** use `BUILD_PLAY_AAB.ps1` and/or `BUILD_STORE_MSIX.ps1` as
  documented below. Keep `PREMIUM_ENABLED=false`.
- **2 — Google private/closed test:** enable the verified Google backend,
  increase the version, build the paid AAB, upload it to a test track, and run
  the full purchase lifecycle tests. Do not promote it.
- **3 — Google production promotion:** promote only the exact AAB that passed
  closed testing. Do not rebuild it and do not create another version.
- **4 — Microsoft monetized:** stop. Microsoft server-side verification is not
  implemented, and the current MSIX builder deliberately forces Free mode.
  Complete that implementation and private-flight QA before activation.

## Product decision in force

EduSheet is free on Google Play and Microsoft Store. Do not show checkout, do
not activate a subscription/base plan/add-on, and do not enable EduSheet in the
entitlement API. SurveyCam is the only currently paid app.

Current free builds must contain:

```text
PREMIUM_ENABLED=false
```

The prepared billing and verification source can remain in the repository for
later use. With the flag false, EduSheet uses the unsupported/free gateway,
unlocks all current styles, does not query products, and cannot start checkout.

## Store identities and versions

| Field | Current value |
| --- | --- |
| Flutter version | `1.2.2+5` |
| Android package | `com.baishalya.edusheet` |
| Play version name | `1.2.2` |
| Play version code | `5` |
| Planned Play product | `edusheet_premium_yearly` (created, inactive) |
| Planned Play base plan | `annual` (draft/inactive; yearly auto-renewing) |
| Planned Play annual price | India `INR 200.00`; other regions auto-converted by Play |
| Microsoft Store ID | `9N0ZK8C31X94` |
| MSIX identity | `Baishalya.EduSheet` |
| MSIX publisher | `CN=8A4649E8-2942-4B3D-9789-6B628C3C006F` |
| Publisher display name | `Baishalya` |
| MSIX architecture | `x64` |
| MSIX version | `1.2.5.0` |
| Planned Microsoft add-on Store ID | `9PGCF60ZZ4ZC` (inactive) |
| Planned Microsoft product ID | `edusheet_premium_yearly` (inactive) |
| Google verifier prepared for later | `https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify` |

The Google verifier does not verify Microsoft purchases. The Microsoft provider
is not implemented and reports disabled.

## Version rules

Flutter uses `major.minor.patch+build`.

- Increase `build` before every Play upload. Never reuse an Android version
  code, even for a rejected or deleted draft.
- Confirm in Play Console that code `5` has never been uploaded before using the
  current AAB. If it was used, update `pubspec.yaml` to at least `1.2.2+6` and
  rebuild.
- Microsoft maps `major.minor.patch+build` to `major.minor.build.0`. Therefore
  `1.2.2+5` maps to `1.2.5.0`.
- Keep the fourth MSIX segment at `0`. The build number must be globally
  increasing and at most `65535`.
- When the Flutter build changes, update both `msix_config.msix_version` and
  `msix_config.output_name` in `pubspec.yaml` before packaging.
- Confirm Partner Center has never received the chosen MSIX version. If
  `1.2.5.0` was used, increase the Flutter build and generate the matching MSIX.

## Build and verify the free Google Play AAB

From `C:\Users\baish\StudioProjects\EduSheet` run:

```powershell
.\release\google_play\BUILD_PLAY_AAB.ps1
```

The script runs clean, dependency restore, tests, analysis, and:

```powershell
flutter build appbundle --release --dart-define=PREMIUM_ENABLED=false
```

Expected current artifact:

```text
Path: C:\Users\baish\StudioProjects\EduSheet\build\app\outputs\bundle\release\app-release.aab
Size: 111,300,918 bytes
SHA-256: CB7179AA860E9812AE6B78F6EEDA30CD8940789874E6765A568B11CF981BEA05
Package: com.baishalya.edusheet
Version name/code: 1.2.2 / 5
Mode: free
Verifier URL embedded: no
```

A changed source tree or rebuild may change the size/hash. Record the newly
verified values instead of expecting the old hash.

Before upload, verify:

1. Tests pass.
2. Analysis contains no errors or warnings. Existing info-level style findings
   may be recorded but cannot hide an error or warning.
3. AAB signature verifies and is not the Android debug certificate.
4. Manifest package and version match this runbook.
5. `PREMIUM_ENABLED=false` is the only monetization build define.
6. No entitlement URL was passed to the build.

## Upload and release the free Android app

1. Open Play Console for EduSheet and inspect the highest uploaded version code.
2. If code `5` exists anywhere, increase the build number and rebuild first.
3. Open the required internal or closed testing track and create a release.
4. Upload `app-release.aab`.
5. Confirm Play shows the expected package, version name, version code, target
   API, signing certificate, and supported devices.
6. Add release notes, save, review, and submit the testing release.
7. Install only from the testing invitation link and test launch, paper
   creation/editing, save/open, preview, PDF/Word export, and file permissions.
8. Open the premium/styles screen and confirm every current style is free and
   no Subscribe/Buy button can launch checkout.
9. Promote the tested release to Production and reuse the exact same AAB.
10. Review countries, staged rollout, policy declarations, Data safety, and app
    content, then submit for review.
11. After approval, publish with Managed publishing or let the approved rollout
    start, according to the owner's instruction.
12. Record the release ID, track, review state, rollout percentage, timestamps,
    artifact hash, and console URL in `release/RELEASE_LOG.md`.

Keep product `edusheet_premium_yearly` and base plan `annual` inactive. A free
AAB compiled with `PREMIUM_ENABLED=false` cannot become paid only by changing a
Play Console switch; a new paid-enabled AAB is required later.

## Build and verify the free Microsoft Store MSIX

From the repository root run:

```powershell
.\release\microsoft_store\BUILD_STORE_MSIX.ps1 `
  -IdentityName 'Baishalya.EduSheet' `
  -Publisher 'CN=8A4649E8-2942-4B3D-9789-6B628C3C006F' `
  -PublisherDisplayName 'Baishalya' `
  -MicrosoftStoreId '9N0ZK8C31X94'
```

The script builds Windows with `PREMIUM_ENABLED=false`, creates an unsigned
Store package, verifies its manifest and file associations, and does not upload
or submit anything.

Expected current artifact:

```text
Path: C:\Users\baish\StudioProjects\EduSheet\release\microsoft_store\packages\EduSheet_1.2.5.0_x64_store.msix
Size: 30,940,845 bytes
SHA-256: 42081252E718108A6E438E55337E4A3734C992B2162BDF1E87F5A07F14B187FE
Identity: Baishalya.EduSheet
Publisher: CN=8A4649E8-2942-4B3D-9789-6B628C3C006F
Version: 1.2.5.0
Architecture: x64
Signature: NotSigned (correct for this Partner Center upload artifact)
Mode: free
```

For local install testing, use `BUILD_QA_MSIX.ps1`; do not upload the QA package
to Partner Center.

## Upload and release the free Windows app

1. Open Partner Center, select EduSheet, and create/open the application
   submission.
2. Check Product identity against this runbook.
3. Check the highest package version. Rebuild with a higher mapped version if
   `1.2.5.0` has already been uploaded.
4. Set the base app price to Free and complete markets, properties, age rating,
   privacy/support URLs, listing text, images, and certification notes.
5. Upload `EduSheet_1.2.5.0_x64_store.msix` to Packages.
6. Confirm Partner Center accepts identity, publisher, architecture, minimum OS,
   and version.
7. Do not include or submit add-on `9PGCF60ZZ4ZC`.
8. Run Partner Center validation, review the submission, and submit the free app
   for certification only when the owner asks for the external submission.
9. After certification, publish the free app with the requested visibility and
   record every status change in `release/RELEASE_LOG.md`.

## Activate Google Play monetization later

The existing free AAB remains free. Monetization requires a new private-test
AAB and all of these steps:

1. Approve the paid feature boundary and price disclosures.
2. Activate `edusheet_premium_yearly` with base plan `annual` in Play Console.
3. Set EduSheet `verificationEnabled: true` in the entitlement API registry,
   run its checks, deploy it, and verify the live route.
4. Increase the Flutter build number.
5. Build with the exact paid defines documented in
   `release/google_play/RELEASE_HELPER.md`.
6. Upload to closed testing and test purchase, pending payment, cancellation,
   refund, restore, renewal, expiry, grace period, account hold, invalid token,
   offline/retry behavior, and fresh installation.
7. Confirm Pro unlocks only after `valid: true` and `active: true` from the
   verifier.
8. Promote the exact tested AAB to Production and record the change.

## Activate Microsoft monetization later

The current free MSIX cannot become paid merely by publishing the existing
add-on. Before activating it:

1. Implement and test real Microsoft Store server-side entitlement
   verification. The current Google route is not valid for Microsoft.
2. Test purchase, cancellation, refund, restore, renewal, expiry, offline
   licence, and account-switch behavior with Microsoft test accounts.
3. Complete price, markets, subscription period, privacy, support, listing, and
   reviewer information for add-on Store ID `9PGCF60ZZ4ZC`.
4. Increase the Flutter build and mapped MSIX version.
5. Build a private-flight MSIX with `PREMIUM_ENABLED=true` only after the
   Microsoft verification path is ready.
6. Validate the flight, then submit the add-on and paid-enabled app update in
   the order required by Partner Center.
7. Keep the previous free package available until the paid update passes
   certification and purchase QA.

## Failure and rollback rules

- If a free release shows checkout, stop rollout and rebuild with
  `PREMIUM_ENABLED=false`.
- If a version was uploaded, never reuse it; increase the build/version.
- If store verification is unavailable during a future paid rollout, pause the
  rollout instead of trusting client-only purchase state.
- Never place a service-account JSON key in source, build flags, AAB, MSIX, or
  logs. Do not rotate the existing key unless the owner explicitly requests it.
- Generated packages are git-ignored. Preserve the approved artifact and its
  hash in a controlled release archive.
