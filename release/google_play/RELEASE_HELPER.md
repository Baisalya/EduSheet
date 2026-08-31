# EduSheet Google Play release helper

## Release configuration

- Application ID: `com.baishalya.edusheet`
- Version: `1.2.2+5`
- Target SDK: Android 16 / API 36
- Subscription product ID: `edusheet_premium_yearly`
- Subscription behavior: store-driven, fail-open

The release bundle is built with Play Billing discovery enabled. The Play
Console product controls whether subscription UI is active:

- Product inactive, unpublished, unavailable, or Store offline: all workspace
  styles and all core tools remain free; no checkout starts.
- Product active and returned by Google Play: optional premium styles require
  the subscription. Selecting a locked style opens the premium screen, and the
  teacher explicitly taps the Store-priced Subscribe button.
- Core paper creation, Question Bank, math authoring, and current exports stay
  free even after subscription activation.

The app does not show an unsolicited purchase dialog on launch.

## Clean App Bundle build

Run from the repository root:

```powershell
flutter clean
flutter pub get
flutter test
flutter analyze --no-pub
flutter build appbundle --release `
  --dart-define=PREMIUM_ENABLED=true `
  --dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly
```

The upload artifact is:

```text
build/app/outputs/bundle/release/app-release.aab
```

`android/key.properties` and its referenced private keystore must remain local
and must never be committed.

For a repeatable build, run:

```powershell
.\release\google_play\BUILD_PLAY_AAB.ps1
```

## Verified local artifact

- Build result: PASS
- Path: `build/app/outputs/bundle/release/app-release.aab`
- Size: 105,097,690 bytes (100.2 MB)
- SHA-256: `F6843B57EF775700FDC340294ECE4E245E6CD36313C3FD6E8232BB167A976F9D`
- Signature: verified and not signed with the Android debug certificate
- Manifest: version code 5, version name 1.2.2, target SDK 36
- Permissions: Internet and `com.android.vending.BILLING` present

The build emits one non-blocking forward-compatibility warning for third-party
plugins that still apply the legacy Kotlin Gradle Plugin (`device_info_plus`,
`image_picker_android`, `in_app_review`, `package_info_plus`,
`quill_native_bridge_android`, and `shared_preferences_android`). The app module
itself no longer applies Kotlin and builds successfully on Flutter 3.47 / AGP
9.0.1. Track plugin updates before a future Flutter version removes temporary
legacy-plugin support. Dependency "newer version available" messages are also
informational; no unsafe major upgrade was included in this release.

## Play Console setup — keep inactive for now

1. Create a subscription with product ID `edusheet_premium_yearly`.
2. Add an annual auto-renewing base plan, price, countries, tax settings, and
   localized title/description.
3. Leave the subscription/base plan inactive while the app should be fully
   free.
4. Upload this AAB to an internal or closed test track before production.
5. Before activation, test purchase, cancellation, pending payment, restore,
   renewal, expiry, grace period, and account hold with Play licence testers.
6. Add backend purchase-token verification and subscription-state handling
   before treating the paid entitlement as revenue-secure at scale.
7. Activate the product/base plan only after those checks pass. The same app
   bundle will then discover the product and expose the optional checkout.

Generating this bundle does not upload it, publish it, or activate a Play
Console subscription.
