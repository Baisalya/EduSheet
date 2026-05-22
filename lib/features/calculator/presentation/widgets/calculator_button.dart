import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CalculatorButtonShape { round, pill, rect }

class CalculatorButton extends StatelessWidget {
  final String label;
  final String? secondaryLabel; // Yellow label above
  final String? alphaLabel; // Red label above
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;
  final CalculatorButtonShape shape;
  final IconData? icon;
  final bool isActive;
  final double? width;
  final double? height;

  const CalculatorButton({
    super.key,
    required this.label,
    this.secondaryLabel,
    this.alphaLabel,
    required this.onTap,
    this.bgColor = const Color(0xFF3E3E3E),
    this.textColor = Colors.white,
    this.shape = CalculatorButtonShape.rect,
    this.icon,
    this.isActive = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    double borderRadius;
    switch (shape) {
      case CalculatorButtonShape.round:
        borderRadius = 25;
        break;
      case CalculatorButtonShape.pill:
        borderRadius = 10;
        break;
      case CalculatorButtonShape.rect:
      default:
        borderRadius = 6;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryLabel != null)
                  Text(
                    secondaryLabel!,
                    style: const TextStyle(
                      color: Color(0xFFFFD700), // Gold/Yellow
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (secondaryLabel != null && alphaLabel != null)
                  const SizedBox(width: 8),
                if (alphaLabel != null)
                  Text(
                    alphaLabel!,
                    style: const TextStyle(
                      color: Color(0xFFFF5252), // Red/Alpha
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // Button Body
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Container(
                height: height ?? (shape == CalculatorButtonShape.rect ? 38 : 30),
                width: width ?? (shape == CalculatorButtonShape.round ? 45 : 60),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withAlpha(50) : bgColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(150),
                      offset: const Offset(0, 2),
                      blurRadius: 1,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 0.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColor.withAlpha(255),
                      bgColor.withAlpha(200),
                    ],
                  ),
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: textColor, size: 18)
                      : Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: shape == CalculatorButtonShape.rect ? 16 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
