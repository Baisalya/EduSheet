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
