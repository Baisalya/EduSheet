import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../domain/models/math_symbol.dart';

class MathKey extends StatelessWidget {
  final MathSymbol symbol;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MathKey({
    super.key,
    required this.symbol,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Math.tex(
              symbol.tex.replaceAll('{}', ''), // Clean up for display
              mathStyle: MathStyle.display,
              textStyle: TextStyle(
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
