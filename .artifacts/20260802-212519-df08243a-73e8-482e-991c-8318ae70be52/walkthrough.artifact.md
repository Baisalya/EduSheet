# Walkthrough: Fixing Release Build and Upgrading Tooling

I have successfully resolved the build failure and upgraded the project's Android build tooling to the latest recommended versions.

## Key Fixes

### 1. Integration Test Plugin Error
Fixed the compilation error in release builds where `IntegrationTestPlugin` was missing from the classpath.
- **Change**: Moved `integration_test` from `dev_dependencies` to `dependencies` in `pubspec.yaml`.

### 2. Tooling Upgrades
Upgraded the core build components to resolve warnings and improve build stability.
- **Gradle**: Upgraded to **9.1.0**.
- **Android Gradle Plugin (AGP)**: Upgraded to **9.0.1**.
- **Kotlin**: Upgraded to **2.3.20**.

### 3. Global Compatibility Fixes
Many plugins had hardcoded low `compileSdk` values or old Java versions, causing conflicts in AGP 9.0.
- **Compile SDK**: Forced `compileSdk 36` for all subprojects and plugins in the root `build.gradle.kts`. This resolves "CheckAarMetadata" failures where dependencies required newer APIs than the plugins they were part of.
- **Java/Kotlin 17**: Forced all subprojects to use **Java 17** and **Kotlin JVM Target 17**. This eliminates numerous "source value 8 is obsolete" warnings and ensures consistency across the build.

### 4. AGP 9.0 DSL Migration
Handled breaking changes in AGP 9.0's Kotlin DSL.
- **Legacy DSL**: Reverted `android.newDsl` to `false` in `gradle.properties` to maintain compatibility with the current Flutter Gradle Plugin version.
- **Modern Syntax**: Migrated `jvmTarget` usage to the new `compilerOptions` DSL in `build.gradle.kts` files to satisfy AGP 9.0's requirements.

## Verification Summary

- **Successful Build**: Verified that `flutter build appbundle --release` now completes successfully.
- **Warning Reduction**: Confirmed that the majority of tooling and compatibility warnings have been eliminated.
- **Plugin Registry**: Confirmed that all necessary plugins (including `integration_test`) are correctly registered and available in the release build.

You can now generate your production appbundle with:
```powershell
flutter build appbundle --release
```
