# EduSheet store-release checklist

The app-side premium, ratings, dynamic version display, legal links and update
prompt are implemented for version `1.1.0+2`. Complete these store-owned items
before sending the build to production review.

## Required store configuration

- Create an active **non-consumable** product named
  `edusheet_premium_lifetime` in Google Play Console and App Store Connect.
- Set its price, localized title/description, tax category and reviewer notes.
- Add the release build to a closed/internal test track and complete a real
  purchase, cancellation, pending-payment and restore test with licence users.
- When Apple creates the listing, build with
  `--dart-define=APPLE_APP_ID=<numeric-id>` so the permanent rating shortcut can
  open the App Store review page.
- For Microsoft Store builds, add
  `--dart-define=MICROSOFT_STORE_ID=<product-id>` for the rating shortcut.

## Required public URLs and declarations

- Publish a final privacy policy and use its public URL in every store listing.
- Verify that `support@edusheet.com` is a working, monitored mailbox or replace
  it in `AppConfig` and the website before release.
- Add the real Google Play and Microsoft Store URLs to the static website.
- Update store Data Safety/App Privacy answers to disclose store billing,
  ratings, update checks, OCR/camera/gallery use and on-device document storage.
- Add screenshots for phone, tablet and Windows using the exact release build.

## Release validation

- Supply the private Android `key.properties` and keystore; never commit them.
- Build and upload an AAB, then test the store-delivered artifact (not only a
  locally installed APK).
- Verify app links, document VIEW/SEND handling, camera/gallery permission
  wording, PDF/Word export, purchase restore and update prompts on physical
  devices.
- Keep `PREMIUM_ENABLED=true` for store builds. Use a different
  `PREMIUM_PRODUCT_ID` only when the matching store product is configured.

## Purchase verification note

The current lifetime entitlement is delivered after the platform store reports
the product as purchased/restored and is cached locally for offline use. Before
introducing high-value server features or large-scale licensing, add server-side
receipt/token verification and account-based entitlement recovery.
