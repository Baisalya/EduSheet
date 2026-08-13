import 'package:edusheet/features/paper_composer/presentation/screens/paper_composer_screen.dart';
import 'package:flutter/material.dart';

/// Compatibility route for existing navigation.
///
/// The legacy multi-thousand-line create-paper implementation has been
/// replaced by the responsive Paper Composer feature.
class CreatePaperScreen extends StatelessWidget {
  const CreatePaperScreen({super.key});

  @override
  Widget build(BuildContext context) => const PaperComposerScreen();
}
