import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EducationDocumentLottie extends StatelessWidget {
  const EducationDocumentLottie({
    super.key,
    this.size = 260,
    this.repeat = true,
  });

  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Lottie.asset(
          'assets/lottie/education_document_final.json',
          repeat: repeat,
          animate: true,
          fit: BoxFit.contain,
          frameRate: FrameRate.composition,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
