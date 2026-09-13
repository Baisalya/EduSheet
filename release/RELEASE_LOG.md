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
