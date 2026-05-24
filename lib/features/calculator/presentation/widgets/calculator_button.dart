import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CalculatorButtonShape { round, pill, rect }

class CalculatorButton extends StatelessWidget {
  final String label;
  final String? secondaryLabel;
  final String? alphaLabel;
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;
  final CalculatorButtonShape shape;
  final IconData? icon;
  final bool isActive;
  final double? width;
  final double? height;
  final double labelSize;

  const CalculatorButton({
    super.key,
    required this.label,
    this.secondaryLabel,
    this.alphaLabel,
    required this.onTap,
    this.bgColor = const Color(0xFFF5F7FA),
    this.textColor = const Color(0xFF111827),
    this.shape = CalculatorButtonShape.rect,
    this.icon,
    this.isActive = false,
    this.width,
    this.height,
    this.labelSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = shape == CalculatorButtonShape.round ? 22.0 : 8.0;
    final foreground = isActive ? Colors.white : textColor;
    final background = isActive ? const Color(0xFF2563EB) : bgColor;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: secondaryLabel == null && alphaLabel == null ? 0 : 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryLabel != null)
                  Flexible(
                    child: Text(
                      secondaryLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 10,
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
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 10,
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
                        color: Colors.black.withAlpha(20),
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
                                fontSize: labelSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          )
                        : Icon(icon, color: foreground, size: labelSize + 4),
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
