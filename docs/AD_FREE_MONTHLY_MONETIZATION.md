# EduSheet Free and Premium plan

## Product boundary

### Free

- Three basic paper templates.
- Up to five saved papers and two active classes.
- Up to five basic PDF exports per calendar month.
- Core paper editing, syllabus planning, progress editing, and personal
  `.eds` backup/restore.
- Supported Android/iOS editions may show a labelled home banner and an
  occasional preloaded interstitial after every second completed return to
  Home. Interstitials have a 10-second minimum gap and no app-side daily cap;
  a show is still skipped if consent, eligibility or a preloaded ad is missing.

### Premium

- Unlimited saved papers, active classes, and exports.
- Editable Word export, all templates, custom styles, and new school-logo
  branding.
- Advanced planner, analytics, period scheduling, curriculum packages, and
  bulk operations.
- No advertising.

### Data-safety rules

- Existing papers, classes, templates, logos, and personal backups are never
  locked. A teacher may continue viewing and editing existing work after a
  subscription expires.
- Personal `.eds` backup and restore stay available on Free, including for an
  unsaved paper that has reached the Free saved-paper limit.
- Expiry blocks only new Premium operations after a seven-day grace period.
- If billing, catalogue discovery, or server verification is unavailable, the
  app fails open to complimentary full access rather than unexpectedly locking
  work. Complimentary access is still the ad-supported Free experience; only
  paid or grace-period entitlement removes ads.

## Remote launch contract

The first closed-test and Production AAB is built with billing, the production
verifier URL and ads enabled, while the Play base plan remains inactive. In
that state teachers receive full feature access plus Free-plan ads, and no
checkout is available.

Later, the owner can enable the verifier backend and activate the prepared Play
base plan. On the next fresh store discovery, the same installed AAB exposes
the Free limits and Premium checkout. No app update is required. If the
Production AAB was built with `PREMIUM_ENABLED=false` or without the verifier
URL, this remote launch is impossible and a new app release is required.

## Google Play setup

The existing subscription product ID `edusheet_premium_yearly` is retained as
an opaque backend identity. Create a monthly base plan named
`monthly-premium`, target India at INR 25.00/month, and keep the old annual
draft inactive. The UI reads Google Play's localized price; no currency string
is hardcoded in checkout.

Configure a seven-day grace period in Play Console. The purchase-verification
service must validate the package name, product ID, purchase token, expiry,
acknowledgement, cancellation, grace, and account-hold state. The app's local
seven-day calculation is a continuity fallback; the verifier remains the
authority for production entitlement.

Before enabling ads, create production AdMob banner and interstitial units,
publish a UMP consent message, complete Play Console Ads and Data safety
declarations, and publish `app-ads.txt` for the developer domain.

## Build switches

Source defaults keep ads and checkout off, but the ads-ready Play release must
override them. Set the environment values, then use
`release/google_play/BUILD_PLAY_AAB.ps1`:

```powershell
$env:EDUSHEET_ADMOB_APP_ID = 'ca-app-pub-REAL_APP_ID'
$env:ADMOB_ANDROID_HOME_BANNER_ID = 'ca-app-pub-REAL_BANNER_ID'
$env:ADMOB_ANDROID_HOME_INTERSTITIAL_ID = 'ca-app-pub-REAL_INTERSTITIAL_ID'
$env:EDUSHEET_PURCHASE_VERIFICATION_URL = 'https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify'
flutter build appbundle --release `
  --dart-define=PREMIUM_ENABLED=true `
  --dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly `
  --dart-define=ADS_ENABLED=true `
  --dart-define=ADMOB_ANDROID_HOME_BANNER_ID=ca-app-pub-REAL_BANNER_ID `
  --dart-define=ADMOB_ANDROID_HOME_INTERSTITIAL_ID=ca-app-pub-REAL_INTERSTITIAL_ID `
  --dart-define=EDUSHEET_PURCHASE_VERIFICATION_URL=https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify
```

Never ship Google's sample app ID or test ad-unit IDs in a release. Test first
in Play closed testing with the app/version marked as a test app in AdMob (or
every tester device registered). Include UMP consent, failed ad loads, ad
frequency caps and full-access/no-checkout behavior while the base plan is
inactive. Before remotely activating Premium, also test purchase, restore,
cancellation, expiry, seven-day grace, account hold, limit rollover,
existing-data editing, and backup/restore.
