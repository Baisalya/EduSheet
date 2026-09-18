import 'package:flutter/material.dart';

/// App-wide visual system for EduSheet.
///
/// The selected workspace colour is the single accent source for interactive
/// controls and lightly tints neutral surfaces. Feature-specific semantic
/// colours (error/success/document types, etc.) can still be used where they
/// carry meaning, but structural UI should inherit this theme.
class EduSheetTheme {
  static const Color seed = Color(0xFF2563EB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color _lightScaffoldBase = Color(0xFFF5F7FB);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceContainerBase = Color(0xFFF0F4F9);
  static const Color _lightSurfaceHighBase = Color(0xFFE7EDF5);
  static const Color _lightOutlineBase = Color(0xFFC7D1DE);
  static const Color _lightText = Color(0xFF101828);
  static const Color _lightMutedText = Color(0xFF526174);

  static const Color _darkScaffoldBase = Color(0xFF09111F);
  static const Color _darkSurface = Color(0xFF111827);
  static const Color _darkSurfaceContainerBase = Color(0xFF172033);
  static const Color _darkSurfaceHighBase = Color(0xFF202B3D);
  static const Color _darkOutlineBase = Color(0xFF334155);
  static const Color _darkText = Color(0xFFF8FAFC);
  static const Color _darkMutedText = Color(0xFFA7B3C6);

  static ThemeData light({Color seedColor = seed}) {
    final generated = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final scaffold = _tint(_lightScaffoldBase, generated.primary, 0.025);
    final surfaceContainer = _tint(
      _lightSurfaceContainerBase,
      generated.primary,
      0.035,
    );
    final surfaceHigh = _tint(
      _lightSurfaceHighBase,
      generated.primary,
      0.045,
    );
    final outline = _tint(_lightOutlineBase, generated.primary, 0.025);

    final scheme = generated.copyWith(
      surface: _lightSurface,
      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: _tint(_lightSurface, generated.primary, 0.018),
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: _tint(
        const Color(0xFFDDE5EF),
        generated.primary,
        0.045,
      ),
      outline: outline,
      outlineVariant: _tint(
        const Color(0xFFD7E0EA),
        generated.primary,
        0.025,
      ),
      onSurface: _lightText,
      onSurfaceVariant: _lightMutedText,
    );

    return _build(
      scheme: scheme,
      scaffoldBackground: scaffold,
      cardColor: _lightSurface,
      fieldColor: scheme.surfaceContainerLow,
      borderColor: outline,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark({Color seedColor = seed}) {
    final generated = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    final scaffold = _tint(_darkScaffoldBase, generated.primary, 0.045);
    final surface = _tint(_darkSurface, generated.primary, 0.025);
    final surfaceContainer = _tint(
      _darkSurfaceContainerBase,
      generated.primary,
      0.045,
    );
    final surfaceHigh = _tint(
      _darkSurfaceHighBase,
      generated.primary,
      0.055,
    );
    final outline = _tint(_darkOutlineBase, generated.primary, 0.035);

    final scheme = generated.copyWith(
      surface: surface,
      surfaceContainerLowest: scaffold,
      surfaceContainerLow: _tint(surface, generated.primary, 0.035),
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: _tint(
        const Color(0xFF263247),
        generated.primary,
        0.06,
      ),
      outline: outline,
      outlineVariant: _tint(
        const Color(0xFF29364A),
        generated.primary,
        0.04,
      ),
      onSurface: _darkText,
      onSurfaceVariant: _darkMutedText,
    );

    return _build(
      scheme: scheme,
      scaffoldBackground: scaffold,
      cardColor: surface,
      fieldColor: scheme.surfaceContainerLow,
      borderColor: outline,
      brightness: Brightness.dark,
    );
  }

  static Color _tint(Color base, Color accent, double opacity) {
    return Color.alphaBlend(accent.withValues(alpha: opacity), base);
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color fieldColor,
    required Color borderColor,
    required Brightness brightness,
  }) {
    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scaffoldBackground,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ).copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
    );

    final palette = EduSheetSemanticColors(
      workspace: scheme.primary,
      workspaceSoft: scheme.primaryContainer,
      onWorkspaceSoft: scheme.onPrimaryContainer,
      success: success,
      warning: warning,
      danger: danger,
      info: scheme.tertiary,
      canvas: scaffoldBackground,
      surface: scheme.surface,
      surfaceMuted: scheme.surfaceContainer,
      surfaceStrong: scheme.surfaceContainerHigh,
      border: scheme.outlineVariant,
      ink: scheme.onSurface,
      inkMuted: scheme.onSurfaceVariant,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: scheme.outlineVariant),
    );

    final controlOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return scheme.primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered)) {
        return scheme.primary.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.focused)) {
        return scheme.primary.withValues(alpha: 0.10);
      }
      return null;
    });

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: textTheme,
      canvasColor: scaffoldBackground,
      dividerColor: scheme.outlineVariant,
      splashColor: scheme.primary.withValues(alpha: 0.09),
      highlightColor: scheme.primary.withValues(alpha: 0.05),
      focusColor: scheme.primary.withValues(alpha: 0.10),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        scheme: scheme,
        fillColor: fieldColor,
        borderColor: borderColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.12);
            }
            return scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.onPrimary;
          }),
          overlayColor: controlOverlay,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: scheme.primary, width: 1.5);
            }
            return BorderSide(color: scheme.outline);
          }),
          overlayColor: controlOverlay,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          overlayColor: controlOverlay,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          overlayColor: controlOverlay,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 1,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        elevation: 0,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required ColorScheme scheme,
    required Color fillColor,
    required Color borderColor,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: border(borderColor),
      enabledBorder: border(borderColor),
      focusedBorder: border(scheme.primary, 1.7),
      errorBorder: border(danger),
      focusedErrorBorder: border(danger, 1.7),
    );
  }
}

@immutable
class EduSheetSemanticColors extends ThemeExtension<EduSheetSemanticColors> {
  const EduSheetSemanticColors({
    required this.workspace,
    required this.workspaceSoft,
    required this.onWorkspaceSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.border,
    required this.ink,
    required this.inkMuted,
  });

  final Color workspace;
  final Color workspaceSoft;
  final Color onWorkspaceSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceStrong;
  final Color border;
  final Color ink;
  final Color inkMuted;

  @override
  EduSheetSemanticColors copyWith({
    Color? workspace,
    Color? workspaceSoft,
    Color? onWorkspaceSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? border,
    Color? ink,
    Color? inkMuted,
  }) {
    return EduSheetSemanticColors(
      workspace: workspace ?? this.workspace,
      workspaceSoft: workspaceSoft ?? this.workspaceSoft,
      onWorkspaceSoft: onWorkspaceSoft ?? this.onWorkspaceSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
    );
  }

  @override
  EduSheetSemanticColors lerp(
    covariant ThemeExtension<EduSheetSemanticColors>? other,
    double t,
  ) {
    if (other is! EduSheetSemanticColors) return this;
    return EduSheetSemanticColors(
      workspace: Color.lerp(workspace, other.workspace, t)!,
      workspaceSoft: Color.lerp(workspaceSoft, other.workspaceSoft, t)!,
      onWorkspaceSoft: Color.lerp(onWorkspaceSoft, other.onWorkspaceSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
    );
  }
}

extension EduSheetThemeContext on BuildContext {
  EduSheetSemanticColors get eduColors {
    return Theme.of(this).extension<EduSheetSemanticColors>() ??
        _fallbackSemanticColors(Theme.of(this));
  }
}

EduSheetSemanticColors _fallbackSemanticColors(ThemeData theme) {
  final scheme = theme.colorScheme;
  return EduSheetSemanticColors(
    workspace: scheme.primary,
    workspaceSoft: scheme.primaryContainer,
    onWorkspaceSoft: scheme.onPrimaryContainer,
    success: EduSheetTheme.success,
    warning: EduSheetTheme.warning,
    danger: EduSheetTheme.danger,
    info: scheme.tertiary,
    canvas: theme.scaffoldBackgroundColor,
    surface: scheme.surface,
    surfaceMuted: scheme.surfaceContainer,
    surfaceStrong: scheme.surfaceContainerHigh,
    border: scheme.outlineVariant,
    ink: scheme.onSurface,
    inkMuted: scheme.onSurfaceVariant,
  );
}
