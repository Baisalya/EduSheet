# EduSheet archived store-release checklist

The current release contract is `release/STORE_RELEASE_RUNBOOK.md`. If this
older checklist conflicts with that runbook, follow the runbook.

The app-side premium, ratings, dynamic version display, legal links and update
prompt are implemented for version `1.1.0+2`. Complete these store-owned items
before sending the build to production review.

## Required store configuration

- Create an annual auto-renewing subscription named
  `edusheet_premium_yearly` in Google Play Console, but keep its base plan
  inactive while EduSheet should remain fully free.
- Do not activate, price, or publish the subscription for the current free
  release.
- Add the free build to a closed/internal test track and verify that no checkout
  is available.
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
- Keep `PREMIUM_ENABLED=false` for the current Google Play and Microsoft Store
  builds. Every current style stays free and the app does not query or start
  Store checkout.

## Purchase verification note

Google Play server verification is prepared in source, but EduSheet is disabled
in the live entitlement registry while the app is free. Before a future paid
release, enable and test it for purchase, renewal, expiry, grace period and
account hold. Microsoft monetization still requires a real Microsoft Store
server-verification provider.
