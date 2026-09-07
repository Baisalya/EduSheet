import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

import '../layout/calculator_layout_spec.dart';
import '../widgets/calculator_history_drawer.dart';
import '../widgets/formula_catalog_sheet.dart';
import '../widgets/scientific_calculator.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scientific Calculator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showHistory(context),
          ),
          IconButton(
            tooltip: 'Science formulas',
            icon: const Icon(Icons.science_rounded),
            onPressed: () => _showFormulaCatalog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: const SafeArea(child: ScientificCalculator()),
    );
  }

  void _showFormulaCatalog(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >=
        CalculatorLayoutSpec.splitKeypadBreakpoint;
    if (desktop) {
      showDialog<void>(
        context: context,
        builder: (context) => const Dialog(
          insetPadding: EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 680,
            height: 600,
            child: FormulaCatalogSheet(
              key: ValueKey('calculator-formula-route-dialog'),
              dialogMode: true,
            ),
          ),
        ),
      );
      return;
    }

    showAdaptiveModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FormulaCatalogSheet(
        key: ValueKey('calculator-formula-route-sheet'),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >=
        CalculatorLayoutSpec.splitKeypadBreakpoint;
    if (desktop) {
      showDialog<void>(
        context: context,
        builder: (context) => const Dialog(
          insetPadding: EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 560,
            height: 560,
            child: CalculatorHistoryDrawer(dialogMode: true),
          ),
        ),
      );
      return;
    }

    showAdaptiveModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.72,
        child: CalculatorHistoryDrawer(),
      ),
    );
  }
}
