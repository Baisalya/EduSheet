import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/geometry_controller.dart';
import '../services/geometry_export_service.dart';
import '../services/geometry_svg_service.dart';

class ExportPanel extends StatefulWidget {
  final GeometryController controller;
  final GlobalKey repaintKey;

  const ExportPanel({
    super.key,
    required this.controller,
    required this.repaintKey,
  });

  @override
  State<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends State<ExportPanel> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              dense: true,
              value: widget.controller.diagram.transparentBackground,
              onChanged: (_) => widget.controller.toggleTransparentBackground(),
              title: const Text('Transparent background'),
            ),
            const SizedBox(height: 8),
            _ExportButton(
              icon: Icons.image_outlined,
              label: 'Save as PNG',
              busy: _isBusy,
              onTap: () => _savePng(context),
            ),
            _ExportButton(
              icon: Icons.code,
              label: 'Save as SVG',
              busy: _isBusy,
              onTap: () => _saveSvg(context),
            ),
            _ExportButton(
              icon: Icons.content_copy,
              label: 'Copy SVG',
              busy: _isBusy,
              onTap: () => _copyText(
                context,
                GeometrySvgService().toSvg(widget.controller.diagram),
                'SVG copied',
              ),
            ),
            _ExportButton(
              icon: Icons.functions,
              label: 'Copy TikZ',
              busy: _isBusy,
              onTap: () => _copyText(
                context,
                GeometrySvgService().toTikz(widget.controller.diagram),
                'TikZ copied',
              ),
            ),
            _ExportButton(
              icon: Icons.short_text,
              label: 'Copy placeholder',
              busy: _isBusy,
              onTap: () => _copyText(
                context,
                widget.controller.diagram.placeholderToken,
                'Placeholder copied',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePng(BuildContext context) async {
    await _run(context, () async {
      final bytes = await GeometryExportService().capturePng(widget.repaintKey);
      final file = await GeometryExportService().savePng(
        widget.controller.diagram,
        bytes,
      );
      if (context.mounted) _showSnack(context, 'PNG saved: ${file.path}');
    });
  }

  Future<void> _saveSvg(BuildContext context) async {
    await _run(context, () async {
      final file = await GeometryExportService().saveSvg(
        widget.controller.diagram,
      );
      if (context.mounted) _showSnack(context, 'SVG saved: ${file.path}');
    });
  }

  Future<void> _copyText(
    BuildContext context,
    String text,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _showSnack(context, message);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (error) {
      if (context.mounted) _showSnack(context, 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        onPressed: busy ? null : onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
