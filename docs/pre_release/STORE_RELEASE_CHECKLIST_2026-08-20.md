# EduSheet store-release checklist

The app-side premium, ratings, dynamic version display, legal links and update
prompt are implemented for version `1.1.0+2`. Complete these store-owned items
before sending the build to production review.

## Required store configuration

- Create an annual auto-renewing subscription named
  `edusheet_premium_yearly` in Google Play Console, but keep its base plan
  inactive while EduSheet should remain fully free.
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
- Keep `PREMIUM_ENABLED=true` for Google Play builds. The app fails open while
  the matching product is inactive/unavailable and enables checkout only when
  Play returns `edusheet_premium_yearly` as an active product.

## Purchase verification note

The current subscription entitlement is delivered after the platform store
reports the product as purchased/restored. Before activating the paid base plan,
add server-side purchase-token verification and subscription lifecycle handling
for renewal, expiry, grace period and account hold.
