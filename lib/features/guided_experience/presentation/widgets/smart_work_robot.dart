import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SmartWorkRobot extends StatelessWidget {
  const SmartWorkRobot({super.key, this.size = 68});

  final double size;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.smart_toy_outlined,
            size: size * .55,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return Semantics(
      image: true,
      label: 'Smart Work Assistant',
      child: SizedBox.square(
        dimension: size,
        child: Lottie.asset(
          'assets/lottie/guided_helper.json',
          // Play once when the assistant appears. A continuously looping robot
          // is distracting for teachers and also keeps the frame scheduler
          // active forever. The final frame remains visible afterward.
          repeat: false,
          animate: true,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
