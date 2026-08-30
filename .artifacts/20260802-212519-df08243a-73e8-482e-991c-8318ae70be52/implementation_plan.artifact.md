# Addressing Build Warnings and Upgrading Tooling

The project currently has several warnings regarding deprecated Gradle, AGP, and Kotlin versions, as well as obsolete Java source/target versions and deprecated API usage in `MainActivity.java`. This plan upgrades the core build tools to the latest recommended versions and fixes these warnings.

## Proposed Changes

### Build Configuration

#### [gradle-wrapper.properties](file:///C:/Users/baish/StudioProjects/EduSheet/android/gradle/wrapper/gradle-wrapper.properties)

- Upgrade Gradle from 8.14.0 to 9.1.0.

```diff
-distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-all.zip
+distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip
```

#### [settings.gradle.kts](file:///C:/Users/baish/StudioProjects/EduSheet/android/settings.gradle.kts)

- Upgrade Android Gradle Plugin from 8.12.1 to 9.0.1.
- Upgrade Kotlin from 2.2.20 to 2.3.20.

```diff
 plugins {
     id("dev.flutter.flutter-plugin-loader") version "1.0.0"
-    id("com.android.application") version "8.12.1" apply false
-    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
+    id("com.android.application") version "9.0.1" apply false
+    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
 }
```

### Android Components

#### [MainActivity.java](file:///C:/Users/baish/StudioProjects/EduSheet/android/app/src/main/java/com/baishalya/edusheet/MainActivity.java)

- Fix deprecated `getParcelableExtra(String)` usage by using the type-safe version on API 33+ (Tiramisu).

```diff
         if (Intent.ACTION_SEND.equals(action)) {
-            Object stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
-            return stream instanceof Uri ? (Uri) stream : null;
+            Uri uri;
+            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
+                uri = intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
+            } else {
+                uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
+            }
+            return uri;
         }
```

## Verification Plan

### Automated Tests
- Run `flutter clean` then `flutter pub get`.
- Run `flutter build appbundle --release` and verify that the warnings about Gradle, AGP, and Kotlin versions are gone.
- Verify that the Java 8 obsolete warnings are reduced or gone (though some might persist from 3rd party plugins until they upgrade).

### Manual Verification
- Check the build output logs for any new errors introduced by the tooling upgrade.
- Verify the app still launches and can handle shared documents (tested via `MainActivity.java` changes).
