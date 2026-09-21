# EduSheet release log

Update this file after every build and Store action. Do not replace prior
entries; append a new dated entry.

## 2026-09-13 — free Android and Windows release preparation

- Decision: EduSheet remains free on Google Play and Microsoft Store. Only
  SurveyCam is paid.
- Flutter source version: `1.2.2+5`.
- Android artifact: `build/app/outputs/bundle/release/app-release.aab`.
- Android size: `111,300,918` bytes.
- Android SHA-256: `CB7179AA860E9812AE6B78F6EEDA30CD8940789874E6765A568B11CF981BEA05`.
- Android manifest: `com.baishalya.edusheet`, version name `1.2.2`, version code
  `5`.
- Android mode: `PREMIUM_ENABLED=false`; entitlement URL absent from the native
  release libraries; checkout disabled.
- Android signature: verified.
- Windows artifact:
  `release/microsoft_store/packages/EduSheet_1.2.5.0_x64_store.msix`.
- Windows size: `30,940,845` bytes.
- Windows SHA-256: `42081252E718108A6E438E55337E4A3734C992B2162BDF1E87F5A07F14B187FE`.
- Windows manifest: identity `Baishalya.EduSheet`, publisher
  `CN=8A4649E8-2942-4B3D-9789-6B628C3C006F`, version `1.2.5.0`, architecture
  `x64`; verification passed.
- Windows mode: `PREMIUM_ENABLED=false`; Microsoft add-on `9PGCF60ZZ4ZC`
  remains inactive and unsubmitted.
- Tests: full Flutter suite passed, 656 tests.
- Premium-focused analysis: passed with no issues.
- Full analysis: no errors or warnings; 16 pre-existing info-level style
  findings remain in Teaching Planner files.
- Entitlement API: EduSheet registered but verification disabled; SurveyCam
  remains enabled. Worker version
  `7ee1002d-c34b-4a6c-b2d2-2ae747ca2c90` deployed.
- Backend validation: typecheck, lint, and 60 tests passed; live health passed;
  inactive EduSheet request returned `valid:false, active:false`.
- Backend behavior commit: `f5d251d0a9ec9cff427dc25fdfb35f6d7fad0562`.
- Backend repository head after documentation clarification:
  `7d75ec626859e0d03d13cd3bc2892752071ab8f6`, pushed to `origin/main`.
- EduSheet release implementation/runbook commit:
  `9d4004fb98b99c227fd500dc6f2076287d61fcd9`, pushed to `origin/master`.
- Google Play upload/submission: not performed in this preparation.
- Microsoft Store upload/submission: not performed in this preparation.

## 2026-09-14 — Google Play annual subscription draft configured

- Play Console product `edusheet_premium_yearly` created with the name
  `EduSheet Premium`.
- Base plan `annual` created as a yearly auto-renewing plan.
- India price: `INR 200.00` per year. Google Play generated converted local
  prices for the other available regions.
- Base plan status verified as `Draft annual`; the `Activate` action was not
  used, so the plan remains inactive and unavailable for purchase.
- User-facing subscription benefits were verified against the implemented
  Premium entitlement and saved in Play Console:
  - `Premium themes and supporter badge`
  - `Advanced Teaching Planner insights`
  - `Period scheduling and conflict checks`
  - `Planner workspace backup and restore`
- After saving the benefits, base plan `annual` was rechecked and remained
  `Inactive`.
- App release mode remains Free with `PREMIUM_ENABLED=false`; no build, upload,
  submission, rollout, or entitlement-backend change was performed.
- Play Console showed an existing payments-profile issue. It does not change
  the inactive draft state, but it must be resolved before future activation.

## 2026-09-15 — free Android and Windows release preparation

Date/time: 2026-09-15 12:49
Operator or AI task: AI Assistant
Source commit/worktree state: Unchanged from last run
Flutter version: 1.2.2+6
Play version name/code: 1.2.2 / 6
MSIX version: 1.2.5.0
Build flags: PREMIUM_ENABLED=false
AAB path/size/SHA-256/signature: build/app/outputs/bundle/release/app-release.aab / 111505339 bytes / D6555EF86768B67EA9D927EE82583DA7C7359BD5F1380186149483159B576B2F / Verified (Release key)
MSIX path/size/SHA-256/manifest/signature: release/microsoft_store/packages/EduSheet_1.2.5.0_x64_store.msix / 30940846 bytes / 11C926115E8D6D652FF88302A5E9BCB9B822EA6F47795DD7A2629779EF044A03 / Identity Baishalya.EduSheet, NotSigned
Tests and analysis: All tests passed. Analysis passed with no fatal warnings/errors.
Play track/release/status/rollout/URL: Not uploaded (AI Agent waiting for human action)
Partner Center submission/status/flight/URL: Not uploaded (AI Agent waiting for human action)
Subscription/base plan/add-on state: Inactive (Free build)
Backend version and state: Unchanged
Decision, issue, or rollback: Successfully built Free mode as requested by user.
Next required action: Upload AAB to Play Console closed testing track and MSIX to Partner Center.

## 2026-09-20 — ads-ready Free and remote Premium launch preparation

- Decision: the next Android closed-test and Production artifact will be Free
  with consent-managed ads and full feature access while the Play Premium base
  plan is inactive.
- Future launch: the same installed AAB is compiled with billing, product ID
  `edusheet_premium_yearly`, and the production verifier URL. After backend
  verification is enabled, activating the prepared `monthly-premium` base plan
  can expose ₹25/month checkout and Free limits without an app update.
- Entitlement boundary: complimentary/inactive-catalogue access unlocks every
  feature but remains ad-supported. Only verified paid or seven-day
  grace-period access is ad-free.
- Data safety: existing papers/classes/templates/logos remain viewable and
  editable after expiry; personal `.eds` backup/restore remains available;
  only new Premium operations are restricted after grace.
- Ads: labelled adaptive Home banner plus a preloaded Home-return interstitial
  opportunity after every third completed return, with a ten-minute cooldown
  and maximum three impressions per day. Missing/failed ads are skipped.
- Build gate: `release/google_play/BUILD_PLAY_AAB.ps1` now requires a real
  AdMob app ID, banner ID, interstitial ID and HTTPS verifier URL; it rejects
  malformed IDs and Google sample IDs. It builds with `PREMIUM_ENABLED=true`
  and `ADS_ENABLED=true`.
- Website: root `app-ads.txt` prepared for publisher
  `pub-1529558529658186`; the website release builder copies it to the domain
  root and release/dist validators check it. Confirm this publisher line
  against AdMob's personalized snippet before deployment.
- Privacy: app and website policies disclose Free ads, Google Mobile Ads data,
  Premium purchase handling, seven-day grace and the never-lock-existing-work
  rule.
- Verification: Flutter static analysis passed with no issues. Advertising,
  Premium, entitlement and release-surface focused suite passed (33 tests).
  Website release-content validation and release build-plan validation passed.
- External state: no AdMob app/ad units were created, no AAB was built or
  uploaded, no Play release was promoted, no backend flag was changed, and no
  subscription/base plan was activated in this task.
- Closed-test rule: mark the AdMob app/version as a test app or register every
  tester device before opening ads. Do not click production ads. Public earning
  begins only after Production availability, AdMob app linking/app-ads.txt
  verification/readiness approval, and removal of test-app mode.
- Next required action: sign in to AdMob with the Google account associated
  with the existing AdSense publisher, create/link EduSheet
  (`com.baishalya.edusheet`), create Home banner and Home-return interstitial
  units, publish the UMP message, verify `app-ads.txt`, set the four build
  environment values, and generate a new closed-test AAB with a previously
  unused version code.

## 2026-09-20 — Windows 1.2.8.0 remote-ready Free package

- Scope: implemented the portable file activation and subscription-boundary
  work, generated the Microsoft Store MSIX, and updated release operations.
  No Store upload, submission, publication, or external product-state change
  was performed.
- Flutter source version: `1.2.3+8`; Microsoft package version: `1.2.8.0`.
- Windows build flags: `PREMIUM_ENABLED=true`,
  `PREMIUM_PRODUCT_ID=edusheet_premium_yearly`, Microsoft Store ID
  `9N0ZK8C31X94`. This makes the installed package ready to discover the same
  add-on after it is published without requiring an app update.
- Current release behavior: add-on Store ID `9PGCF60ZZ4ZC` remains
  unsubmitted/inactive/unavailable. Catalogue unavailability therefore grants
  complimentary full access and hides checkout. Windows remains ad-free.
- Future activation guard: publish only the matching Durable subscription
  add-on after private validation. Premium restoration requires both matching
  `InAppOfferToken` and an active `StoreLicense`; an expired/inactive licence
  does not restore Premium.
- Data boundary: existing documents and existing saved papers/classes remain
  viewable and editable after expiry. Personal `.eds` inspection and
  backup/restore remain available; only a new quota-exceeding or Premium
  operation is gated.
- Portable activation: Windows `.eds` and `.edtp` associations were added.
  Android custom MIME/extension intent routing was prepared as source code,
  but no Android artifact was built in this task. Incoming files are decoded
  and inspected before a Premium-only import/merge operation is requested.
- Artifact:
  `release/microsoft_store/packages/EduSheet_1.2.8.0_x64_store.msix`.
- Artifact size: `34,147,922` bytes.
- Artifact SHA-256:
  `AA9DFF6AC2240FD35556206AAD6A74444371CEEE828551BC4CCA8E08987A3CD9`.
- Manifest: identity `Baishalya.EduSheet`, publisher
  `CN=8A4649E8-2942-4B3D-9789-6B628C3C006F`, version `1.2.8.0`, architecture
  `x64`; document, `.eds`, and `.edtp` associations verified.
- Signature: `NotSigned`, as expected for this Partner Center upload artifact.
- Verification: focused portable/import tests passed (22 tests), full Flutter
  test suite passed (1,012 tests), static analysis reported no issues, Windows
  release compilation succeeded, and MSIX verification passed.
- Play/Android action: none. Partner Center action: none. Backend state:
  unchanged. Subscription/add-on state: unchanged and inactive.
- Next action: the owner may upload only this base-app MSIX to Partner Center
  while keeping the add-on unpublished. Before any later monetization launch,
  privately validate catalogue discovery, purchase, restore, expiry and
  existing-data access with the same product ID.

## 2026-09-20 — Android 1.2.3+8 latest ads-ready Free AAB

- Scope: rebuilt Android from the latest source after portable `.eds`/`.edtp`
  activation was added. No Play upload, release submission, rollout, product
  activation, backend change, or Microsoft Store change was performed.
- Play Console read-only check: highest uploaded version code is `7`; version
  code `8` is currently unused and valid for the next upload.
- Version/package: `1.2.3+8`, `com.baishalya.edusheet`.
- Runtime mode: `PREMIUM_ENABLED=true`, `ADS_ENABLED=true`, product ID
  `edusheet_premium_yearly`, and the production HTTPS purchase verifier are
  embedded. The Play base plan remains inactive, so checkout and Free limits
  stay unavailable while all features remain complimentary; ads stay enabled.
- AdMob verification: account and ad serving are approved. EduSheet Android
  app ID, Home Banner and Home Return Interstitial were verified in AdMob and
  embedded. Interstitial ad-unit frequency cap is three impressions per user
  per day. Google sample/test IDs are absent from the release app binary.
- File activation: custom MIME and extension routing for `.eds` and `.edtp` is
  present. `MANAGE_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE` are absent.
  The `open_filex` legacy `READ_EXTERNAL_STORAGE` permission is capped at
  `maxSdkVersion=32`; modern Android uses scoped content URIs/SAF.
- Artifact: `build/app/outputs/bundle/release/app-release.aab`.
- Size: `129,590,569` bytes.
- SHA-256:
  `8A31D432697590168B122778D24B75AE2780094BC24C0E77F34DFC7720D02AE0`.
- Signing: JAR signature verified with release upload certificate SHA-256
  `80:52:56:62:BB:CA:47:AF:5E:21:3C:34:D3:92:E2:92:4C:ED:7D:99:EA:48:BC:57:5E:20:82:DB:19:BA:ED:E1`.
- Verification: all `1,012` Flutter tests passed; static analysis reported no
  issues; production banner/interstitial IDs, live verifier URL and Premium
  product ID were found in the compiled release; manifest package, version,
  AdMob app ID and portable-file intents were verified.
- External state: Play subscription/base plan remains inactive, AdMob account
  remains approved, backend state is unchanged, and no file was uploaded.
- Next action: upload this exact AAB to the closed-test release, complete the
  new permission declaration state shown by Play, keep AdMob test-app/tester
  protection on during QA, and keep the Premium base plan inactive.

## 2026-09-21 — Connected Android banner QA (local debug only)

- Device: Motorola edge 60 stylus (`ZA2234SFXF`), Android API 36; installed
  EduSheet `1.2.3+8`. No app data was cleared.
- Initial symptom: Home banner absent, even at the bottom after Settings.
  The app did not crash, privacy policy v5 was accepted, and Premium checkout
  correctly reported inactive/full complimentary access.
- Root cause: the locally installed debug APK had been compiled with
  `ADS_ENABLED=false` (confirmed against its live Dart VM configuration), so
  neither consent nor AdMob initialized. This did not diagnose a failure in
  the separately built production AAB.
- Rebuilt a **debug-only** APK with `ADS_ENABLED=true`,
  `PREMIUM_ENABLED=true`, and the production purchase-verifier URL, then
  updated the connected device with `adb install -r`. Debug mode selects
  Google's official test banner/interstitial units, not paid inventory.
- Result: UMP consent refreshed, Mobile Ads initialized, and the official
  "AdMob Adaptive Banner / Test Ad" loaded visibly below the Settings card
  on Home. Evidence: `build/diagnostics/edusheet_banner_ads_enabled.png`.
- The production AAB at `build/app/outputs/bundle/release/app-release.aab`
  was **not rebuilt or uploaded** in this QA pass; its 2026-09-20 hash and
  release configuration above remain the upload reference. Real production
  fill/revenue still requires closed-test verification of that AAB and AdMob
  serving; a debug test ad cannot prove live fill.

## 2026-09-21 — Home-return ad cadence request

- Changed the preloaded interstitial opportunity from every third to every
  second completed Home return. The ten-minute cooldown, three-per-day cap,
  consent gate, paid/grace ad-free gate and failed-load skip remain unchanged.
- Kept the Home banner in its labelled, stable placement below the feature
  grid. Feature cards are not unexpectedly swapped with ads: such a placement
  could invite accidental taps and invalid ad traffic.
- Focused advertising policy tests passed (7 tests). The previous AAB hash
  remains valid only for the earlier every-third-return build until a new AAB
  is generated and verified. No upload or AdMob account change was made.

## 2026-09-21 — Revised interstitial frequency and AdMob setting

- Owner requested no three-per-day limit and a 10-second minimum gap.
  The app now offers a preloaded interstitial on every second completed Home
  return, with a 10-second gap from the previous successful show. No app-side
  daily cap remains; no ad is delayed into an unrelated screen or shown after
  every action.
- AdMob `EduSheet Home Return Interstitial` ad-unit frequency capping was
  switched off in the account and verified in its ad-unit list: unit-level
  `No cap`, app-level `No cap`. Banner settings were unchanged.
- The labelled Home banner remains in its stable slot. Feature cards are not
  replaced by surprise ads. Consent, paid/grace ad-free access, preload and
  failed-load skips remain in force.
- This change supersedes the earlier 10-minute/three-per-day entries. A new
  AAB is required for the app-side cadence change; changing AdMob settings
  alone does not update the installed app.
- Owner then directed **do not run the build**. The Flutter build command was
  stopped, but an already-running Gradle wrapper finished writing a code-9
  AAB at `build/app/outputs/bundle/release/app-release.aab` afterward. Its
  SHA-256 is `FBAF4067BF844CE53CF2AB27867945C14EAED2363959C979D36152E023292BF7`.
  The packaged manifest reports `com.baishalya.edusheet`, version `1.2.3`
  code `9`, and `jarsigner -verify` reports `jar verified`. The complete
  release script did not finish, so this artifact is **provisional and must
  not be uploaded**. The prior code-8 hash was
  `8A31D432697590168B122778D24B75AE2780094BC24C0E77F34DFC7720D02AE0`.
- Next Android release: version name `1.2.3`, version code `9` (or higher if
  Play Console already used 9). Windows MSIX stays `1.2.8.0`. The exact
  reproducible `-BuildNumber 9` PowerShell build command and verification
  checklist are in `release/STORE_RELEASE_RUNBOOK.md` and
  `release/google_play/RELEASE_HELPER.md`. No upload/submission was done.

## 2026-09-21 — Android 1.2.3+9 ads-ready Free AAB build complete

- Scope: executed `.\release\google_play\BUILD_PLAY_AAB.ps1 -BuildNumber 9` with production AdMob environment variables and purchase verifier URL.
- Flutter source version: `1.2.3+8`; Play version code override: `9`.
- Package / version: `com.baishalya.edusheet` / `1.2.3 (9)`.
- Build flags: `PREMIUM_ENABLED=true`, `ADS_ENABLED=true`, `PREMIUM_PRODUCT_ID=edusheet_premium_yearly`, `EDUSHEET_PURCHASE_VERIFICATION_URL=https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify`.
- AdMob Configuration: embedded production AdMob App ID (`ca-app-pub-1529558529658186~2744399552`), Banner ID (`ca-app-pub-1529558529658186/7280209238`), Interstitial ID (`ca-app-pub-1529558529658186/4297813513`).
- Artifact: `build/app/outputs/bundle/release/app-release.aab`.
- Artifact size: `129,580,702` bytes (123.6MB).
- Artifact SHA-256: `D325AEAD99AF4F8A6171494E5C2D3E04470FB824BC463EC0C8840656E37899B6`.
- Verification: all 1,012 Flutter tests passed (`+1012`); static analysis reported no issues (`No issues found!`); Gradle task `bundleRelease` completed in 1,241.1s.
- Runtime Mode: ads-ready Free; Premium activates remotely when the Play base plan becomes active.
- Next required action: Upload `app-release.aab` to Play Console closed testing track / internal testing, verify UMP consent and ads on test devices, then promote to production.

## Entry template

```text
Date/time:
Operator or AI task:
Source commit/worktree state:
Flutter version:
Play version name/code:
MSIX version:
Build flags:
AAB path/size/SHA-256/signature:
MSIX path/size/SHA-256/manifest/signature:
Tests and analysis:
Play track/release/status/rollout/URL:
Partner Center submission/status/flight/URL:
Subscription/base plan/add-on state:
Backend version and state:
Decision, issue, or rollback:
Next required action:
```
