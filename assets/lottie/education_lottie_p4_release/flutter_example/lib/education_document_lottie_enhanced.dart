import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EducationDocumentLottieEnhanced extends StatelessWidget {
  const EducationDocumentLottieEnhanced({
    super.key,
    this.size = 260,
    this.repeat = true,
    this.useLite = false,
  });

  final double size;
  final bool repeat;
  final bool useLite;

  @override
  Widget build(BuildContext context) {
    final path = useLite
        ? 'assets/lottie/education_document_final_enhanced_lite_30fps.json'
        : 'assets/lottie/education_document_final_enhanced.json';

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Lottie.asset(
          path,
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
