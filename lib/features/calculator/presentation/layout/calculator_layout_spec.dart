import 'package:flutter/widgets.dart';

enum CalculatorWidthClass { compact, medium, wide }

enum CalculatorHeightClass { cramped, short, regular }

enum CalculatorControlDensity { dense, compact, comfortable }

/// Central responsive policy for the calculator surface.
///
/// Width decides whether the scientific and main keypads can sit side-by-side.
/// Height decides density and whether the body needs a bounded scroll fallback.
/// Keeping these decisions in one immutable spec prevents individual widgets
/// from accumulating unrelated breakpoint checks.
class CalculatorLayoutSpec {
  static const double splitKeypadBreakpoint = 760;
  static const double mediumWidthBreakpoint = 420;
  static const double crampedHeightBreakpoint = 520;
  static const double shortHeightBreakpoint = 680;

  final CalculatorWidthClass widthClass;
  final CalculatorHeightClass heightClass;
  final CalculatorControlDensity controlDensity;
  final bool splitKeypad;
  final bool scrollBody;
  final bool compactDisplay;
  final bool showModeStatus;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double displayToModeGap;
  final double modeToKeypadGap;
  final double keypadGap;
  final double modeStripHeight;
  final double modeButtonWidth;
  final double scrollKeypadHeight;

  const CalculatorLayoutSpec({
    required this.widthClass,
    required this.heightClass,
    required this.controlDensity,
    required this.splitKeypad,
    required this.scrollBody,
    required this.compactDisplay,
    required this.showModeStatus,
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.displayToModeGap,
    required this.modeToKeypadGap,
    required this.keypadGap,
    required this.modeStripHeight,
    required this.modeButtonWidth,
    required this.scrollKeypadHeight,
  });

  factory CalculatorLayoutSpec.resolve(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : 900.0;
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : 760.0;

    final widthClass = width >= splitKeypadBreakpoint
        ? CalculatorWidthClass.wide
        : width >= mediumWidthBreakpoint
        ? CalculatorWidthClass.medium
        : CalculatorWidthClass.compact;

    final heightClass = height < crampedHeightBreakpoint
        ? CalculatorHeightClass.cramped
        : height < shortHeightBreakpoint
        ? CalculatorHeightClass.short
        : CalculatorHeightClass.regular;

    final splitKeypad = widthClass == CalculatorWidthClass.wide;
    final controlDensity = switch (heightClass) {
      CalculatorHeightClass.cramped => CalculatorControlDensity.dense,
      CalculatorHeightClass.short => CalculatorControlDensity.compact,
      CalculatorHeightClass.regular => CalculatorControlDensity.comfortable,
    };

    // A stacked keypad needs more vertical room than the split desktop form.
    // The fallback is deliberately based on available geometry rather than on
    // platform, so Windows free-form resizing behaves exactly like any other
    // constrained surface.
    final scrollBody =
        heightClass == CalculatorHeightClass.cramped ||
        (!splitKeypad && height < 620);

    final horizontalPadding = width >= 1200
        ? 24.0
        : width >= 800
        ? 18.0
        : width >= mediumWidthBreakpoint
        ? 12.0
        : 8.0;

    final modeButtonWidth = width < 350
        ? 56.0
        : width < 430
        ? 62.0
        : width < 620
        ? 68.0
        : 72.0;

    final modeStripHeight = switch (controlDensity) {
      CalculatorControlDensity.dense => 38.0,
      CalculatorControlDensity.compact => 42.0,
      CalculatorControlDensity.comfortable => 44.0,
    };

    final scrollKeypadHeight = splitKeypad
        ? switch (controlDensity) {
            CalculatorControlDensity.dense => 248.0,
            CalculatorControlDensity.compact => 276.0,
            CalculatorControlDensity.comfortable => 304.0,
          }
        : switch (controlDensity) {
            CalculatorControlDensity.dense => 352.0,
            CalculatorControlDensity.compact => 400.0,
            CalculatorControlDensity.comfortable => 448.0,
          };

    return CalculatorLayoutSpec(
      widthClass: widthClass,
      heightClass: heightClass,
      controlDensity: controlDensity,
      splitKeypad: splitKeypad,
      scrollBody: scrollBody,
      compactDisplay: heightClass != CalculatorHeightClass.regular,
      showModeStatus: width >= 520,
      horizontalPadding: horizontalPadding,
      topPadding: heightClass == CalculatorHeightClass.cramped ? 4 : 6,
      bottomPadding: heightClass == CalculatorHeightClass.cramped ? 8 : 12,
      displayToModeGap: heightClass == CalculatorHeightClass.regular ? 10 : 7,
      modeToKeypadGap: heightClass == CalculatorHeightClass.regular ? 8 : 6,
      keypadGap: splitKeypad ? 10 : 6,
      modeStripHeight: modeStripHeight,
      modeButtonWidth: modeButtonWidth,
      scrollKeypadHeight: scrollKeypadHeight,
    );
  }

  String get debugKey =>
      'calculator-layout-${widthClass.name}-${heightClass.name}-'
      '${splitKeypad ? 'split' : 'stacked'}-'
      '${scrollBody ? 'scroll' : 'fixed'}';
}
