import 'package:flutter/material.dart';

/// Visual foundation for the Teaching Planner only.
///
/// The module owns its component geometry and semantic secondary colours, while
/// structural surfaces and the primary accent inherit EduSheet's global theme.
/// This keeps Planner visually distinctive without isolating it from Day/Night
/// mode or the selected workspace colour.
abstract final class TeachingPlannerDesign {
  static const double contentMaxWidth = 1280;
  static const double compactContentMaxWidth = 760;

  static const Color referenceBlue = Color(0xFF2F7DF6);
  static const Color referenceTeal = Color(0xFF12B8AE);
  static const Color referenceNavy = Color(0xFF102A5C);
  static const Color referencePurple = Color(0xFF7A5AF8);
  static const Color referenceCoral = Color(0xFFF25F74);
  static const Color referenceOrange = Color(0xFFF59A53);

  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 18;
  static const double radiusXLarge = 22;
  static const double radiusHero = 26;

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space18 = 18;
  static const double space20 = 20;
  static const double space22 = 22;
  static const double space24 = 24;
  static const double space28 = 28;
  static const double space32 = 32;
  static const double space40 = 40;

  static const Duration fastMotion = Duration(milliseconds: 160);
  static const Duration standardMotion = Duration(milliseconds: 240);
}

@immutable
class TeachingPlannerColors extends ThemeExtension<TeachingPlannerColors> {
  const TeachingPlannerColors({
    required this.canvas,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceStrong,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.teal,
    required this.tealSoft,
    required this.purple,
    required this.purpleSoft,
    required this.coral,
    required this.coralSoft,
    required this.orange,
    required this.orangeSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceStrong;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color teal;
  final Color tealSoft;
  final Color purple;
  final Color purpleSoft;
  final Color coral;
  final Color coralSoft;
  final Color orange;
  final Color orangeSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;

  static const light = TeachingPlannerColors(
    canvas: Color(0xFFF8FBFF),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF4F8FE),
    surfaceStrong: Color(0xFFEAF2FF),
    ink: Color(0xFF102A5C),
    inkMuted: Color(0xFF667899),
    border: Color(0xFFDDE7F5),
    primary: TeachingPlannerDesign.referenceBlue,
    primarySoft: Color(0xFFE8F1FF),
    teal: TeachingPlannerDesign.referenceTeal,
    tealSoft: Color(0xFFE4F9F6),
    purple: TeachingPlannerDesign.referencePurple,
    purpleSoft: Color(0xFFF0ECFF),
    coral: TeachingPlannerDesign.referenceCoral,
    coralSoft: Color(0xFFFFEDF0),
    orange: TeachingPlannerDesign.referenceOrange,
    orangeSoft: Color(0xFFFFF2E7),
    success: Color(0xFF12A878),
    warning: Color(0xFFE89B1B),
    danger: Color(0xFFE95563),
    shadow: Color(0x17102A5C),
  );

  static const dark = TeachingPlannerColors(
    canvas: Color(0xFF0C1423),
    surface: Color(0xFF121D2E),
    surfaceSoft: Color(0xFF17253A),
    surfaceStrong: Color(0xFF1C2E49),
    ink: Color(0xFFF4F8FF),
    inkMuted: Color(0xFFA9B8CF),
    border: Color(0xFF2A3C58),
    primary: Color(0xFF6FA4FF),
    primarySoft: Color(0xFF1D355D),
    teal: Color(0xFF3CD5CB),
    tealSoft: Color(0xFF153E42),
    purple: Color(0xFFA893FF),
    purpleSoft: Color(0xFF302850),
    coral: Color(0xFFFF8190),
    coralSoft: Color(0xFF492731),
    orange: Color(0xFFFFB873),
    orangeSoft: Color(0xFF493422),
    success: Color(0xFF45C99B),
    warning: Color(0xFFF1BA52),
    danger: Color(0xFFFF7C87),
    shadow: Color(0x52000000),
  );

  /// Adapts the planner's structural palette to the active EduSheet theme.
  ///
  /// The planner keeps its semantic secondary colours, but workspace accent,
  /// surfaces, borders and text now come from the parent theme. That makes
  /// day/night mode and Workspace colour apply here exactly like the rest of
  /// the app instead of creating an isolated blue-only visual island.
  static TeachingPlannerColors fromTheme(ThemeData theme) {
    final base = theme.brightness == Brightness.dark ? dark : light;
    final scheme = theme.colorScheme;
    return base.copyWith(
      canvas: theme.scaffoldBackgroundColor,
      surface: scheme.surface,
      surfaceSoft: scheme.surfaceContainerLow,
      surfaceStrong: scheme.surfaceContainerHigh,
      ink: scheme.onSurface,
      inkMuted: scheme.onSurfaceVariant,
      border: scheme.outlineVariant,
      primary: scheme.primary,
      primarySoft: scheme.primaryContainer,
      danger: scheme.error,
      shadow: Colors.black.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.30 : 0.07,
      ),
    );
  }

  @override
  TeachingPlannerColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceStrong,
    Color? ink,
    Color? inkMuted,
    Color? border,
    Color? primary,
    Color? primarySoft,
    Color? teal,
    Color? tealSoft,
    Color? purple,
    Color? purpleSoft,
    Color? coral,
    Color? coralSoft,
    Color? orange,
    Color? orangeSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
  }) {
    return TeachingPlannerColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      teal: teal ?? this.teal,
      tealSoft: tealSoft ?? this.tealSoft,
      purple: purple ?? this.purple,
      purpleSoft: purpleSoft ?? this.purpleSoft,
      coral: coral ?? this.coral,
      coralSoft: coralSoft ?? this.coralSoft,
      orange: orange ?? this.orange,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  TeachingPlannerColors lerp(
    covariant ThemeExtension<TeachingPlannerColors>? other,
    double t,
  ) {
    if (other is! TeachingPlannerColors) return this;
    return TeachingPlannerColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealSoft: Color.lerp(tealSoft, other.tealSoft, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      purpleSoft: Color.lerp(purpleSoft, other.purpleSoft, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralSoft: Color.lerp(coralSoft, other.coralSoft, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

class TeachingPlannerThemeScope extends StatelessWidget {
  const TeachingPlannerThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TeachingPlannerTheme.resolve(Theme.of(context)),
      child: child,
    );
  }
}

abstract final class TeachingPlannerTheme {
  static TeachingPlannerColors colorsOf(BuildContext context) {
    final extension = Theme.of(context).extension<TeachingPlannerColors>();
    if (extension != null) return extension;
    return TeachingPlannerColors.fromTheme(Theme.of(context));
  }

  static ThemeData resolve(ThemeData base) {
    final colors = TeachingPlannerColors.fromTheme(base);
    final scheme = base.colorScheme.copyWith(
      primary: colors.primary,
      primaryContainer: colors.primarySoft,
      secondary: colors.teal,
      tertiary: colors.purple,
      surface: colors.surface,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surfaceSoft,
      surfaceContainer: colors.surfaceSoft,
      surfaceContainerHigh: colors.surfaceStrong,
      surfaceContainerHighest: colors.surfaceStrong,
      outline: colors.border,
      outlineVariant: colors.border,
      onSurface: colors.ink,
      onSurfaceVariant: colors.inkMuted,
      error: colors.danger,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    // ThemeExtension is F-bounded. When existing extensions are spread back
    // into ThemeData.copyWith, recent Flutter/Dart analyzers require the same
    // normalized cast that Flutter uses internally while building its
    // extension map. Keep every parent extension except our planner palette,
    // then append the current planner palette below.
    final originalExtensions = base.extensions.values
        .where((extension) => extension is! TeachingPlannerColors)
        .map(
          (extension) => extension as ThemeExtension<ThemeExtension<dynamic>>,
        )
        .toList(growable: false);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      splashColor: colors.primary.withValues(alpha: .08),
      highlightColor: colors.primary.withValues(alpha: .04),
      dividerColor: colors.border,
      textTheme: base.textTheme.apply(
        bodyColor: colors.ink,
        displayColor: colors.ink,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colors.ink,
          fontWeight: FontWeight.w900,
          letterSpacing: -.2,
        ),
        iconTheme: IconThemeData(color: colors.ink),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            TeachingPlannerDesign.radiusXLarge,
          ),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: colors.surfaceStrong,
          disabledForegroundColor: colors.inkMuted,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusMedium,
            ),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusMedium,
            ),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusSmall,
            ),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            TeachingPlannerDesign.radiusLarge,
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder(colors.border),
        enabledBorder: inputBorder(colors.border),
        focusedBorder: inputBorder(colors.primary, width: 1.6),
        errorBorder: inputBorder(colors.danger),
        focusedErrorBorder: inputBorder(colors.danger, width: 1.6),
        labelStyle: TextStyle(color: colors.inkMuted),
        hintStyle: TextStyle(color: colors.inkMuted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceSoft,
        selectedColor: colors.primarySoft,
        disabledColor: colors.surfaceSoft,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: colors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.primary : colors.inkMuted,
            size: 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return base.textTheme.labelSmall?.copyWith(
            color: selected ? colors.primary : colors.inkMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primarySoft,
        selectedIconTheme: IconThemeData(color: colors.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: colors.inkMuted, size: 24),
        selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: colors.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceStrong,
        circularTrackColor: colors.surfaceStrong,
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: colors.ink,
          borderRadius: BorderRadius.circular(
            TeachingPlannerDesign.radiusSmall,
          ),
        ),
        textStyle: TextStyle(color: colors.surface),
      ),
      extensions: <ThemeExtension<dynamic>>[
        ...originalExtensions,
        colors as ThemeExtension<ThemeExtension<dynamic>>,
      ],
    );
  }
}

enum TeachingPlannerTone { neutral, primary, teal, purple, coral, orange }

extension TeachingPlannerToneColors on TeachingPlannerTone {
  Color foreground(TeachingPlannerColors colors) => switch (this) {
    TeachingPlannerTone.neutral => colors.ink,
    TeachingPlannerTone.primary => colors.primary,
    TeachingPlannerTone.teal => colors.teal,
    TeachingPlannerTone.purple => colors.purple,
    TeachingPlannerTone.coral => colors.coral,
    TeachingPlannerTone.orange => colors.orange,
  };

  Color background(TeachingPlannerColors colors) => switch (this) {
    TeachingPlannerTone.neutral => colors.surfaceSoft,
    TeachingPlannerTone.primary => colors.primarySoft,
    TeachingPlannerTone.teal => colors.tealSoft,
    TeachingPlannerTone.purple => colors.purpleSoft,
    TeachingPlannerTone.coral => colors.coralSoft,
    TeachingPlannerTone.orange => colors.orangeSoft,
  };
}
