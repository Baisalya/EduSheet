import 'package:flutter/material.dart';

class GeometryCoordinateInput {
  final double x;
  final double y;
  final String label;

  const GeometryCoordinateInput({
    required this.x,
    required this.y,
    required this.label,
  });
}

/// Small input dialogs used by Geometry Studio.
///
/// Keeping these outside the Studio scaffold prevents input-form details from
/// being mixed with canvas/session orchestration and makes the same prompts
/// reusable from compact and desktop layouts.
class GeometryInputDialogs {
  const GeometryInputDialogs._();

  static Future<GeometryCoordinateInput?> coordinatePoint(
    BuildContext context,
  ) async {
    final xController = TextEditingController();
    final yController = TextEditingController();
    final labelController = TextEditingController(text: 'P');
    try {
      return await showDialog<GeometryCoordinateInput>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add coordinate point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: xController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'x',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: yController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'y',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Point name',
                  hintText: 'P',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final x = double.tryParse(xController.text.trim());
                final y = double.tryParse(yController.text.trim());
                if (x == null || y == null || !x.isFinite || !y.isFinite) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  GeometryCoordinateInput(
                    x: x,
                    y: y,
                    label: labelController.text.trim(),
                  ),
                );
              },
              child: const Text('Add point'),
            ),
          ],
        ),
      );
    } finally {
      xController.dispose();
      yController.dispose();
      labelController.dispose();
    }
  }

  static Future<String?> text(
    BuildContext context, {
    required String title,
    required String label,
    required String hint,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool tonalConfirm = false,
  }) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          tonalConfirm
              ? FilledButton.tonal(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmLabel),
                )
              : FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmLabel),
                ),
        ],
      ),
    );
    return value == true;
  }
}
