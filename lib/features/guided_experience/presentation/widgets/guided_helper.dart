import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class GuidedHelper extends StatelessWidget {
  const GuidedHelper({
    super.key,
    required this.reduceMotion,
    this.size = 56,
  });

  static const assetPath = 'assets/lottie/guided_helper.json';

  final bool reduceMotion;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: reduceMotion
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.18),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: size * 0.56,
                ),
              )
            : Lottie.asset(
                assetPath,
                repeat: true,
                animate: true,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}
