import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/calculator_layout_spec.dart';

enum CalculatorButtonShape { round, pill, rect }

class CalculatorButton extends StatelessWidget {
  final String label;
  final String? secondaryLabel;
  final String? alphaLabel;
  final VoidCallback onTap;
  final Color bgColor;
  final Color? textColor;
  final CalculatorButtonShape shape;
  final IconData? icon;
  final bool isActive;
  final double? width;
  final double? height;
  final double labelSize;
  final CalculatorControlDensity density;

  const CalculatorButton({
    super.key,
    required this.label,
    this.secondaryLabel,
    this.alphaLabel,
    required this.onTap,
    this.bgColor = const Color(0xFFF5F7FA),
    this.textColor,
    this.shape = CalculatorButtonShape.rect,
    this.icon,
    this.isActive = false,
    this.width,
    this.height,
    this.labelSize = 18,
    this.density = CalculatorControlDensity.comfortable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = density != CalculatorControlDensity.comfortable;
    final dense = density == CalculatorControlDensity.dense;
    final radius = shape == CalculatorButtonShape.round
        ? 22.0
        : dense
        ? 7.0
        : 8.0;
    final outerPadding = dense
        ? 2.0
        : compact
        ? 2.5
        : 3.0;
    final metaHeight = secondaryLabel == null && alphaLabel == null
        ? 0.0
        : dense
        ? 11.0
        : compact
        ? 12.0
        : 14.0;
    final metaFontSize = dense
        ? 8.5
        : compact
        ? 9.0
        : 10.0;
    final effectiveLabelSize = dense
        ? labelSize - 1.5
        : compact
        ? labelSize - 0.75
        : labelSize;
    final foreground = isActive
        ? theme.colorScheme.onPrimary
        : (textColor ?? theme.colorScheme.onSurface);
    final background = isActive ? theme.colorScheme.primary : bgColor;

    return Padding(
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: metaHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryLabel != null)
                  Flexible(
                    child: Text(
                      secondaryLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFF59E0B),
                        fontSize: metaFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (secondaryLabel != null && alphaLabel != null)
                  const SizedBox(width: 6),
                if (alphaLabel != null)
                  Flexible(
                    child: Text(
                      alphaLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFEF4444),
                        fontSize: metaFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: Ink(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(100),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: icon == null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                color: foreground,
                                fontSize: effectiveLabelSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            color: foreground,
                            size: effectiveLabelSize + 4,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
