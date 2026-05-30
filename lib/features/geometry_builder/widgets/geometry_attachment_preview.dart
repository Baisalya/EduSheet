import 'package:flutter/material.dart';

import '../models/geometry_diagram.dart';
import '../painters/geometry_painter.dart';
import '../services/geometry_diagram_registry.dart';

class GeometryAttachmentPreview extends StatefulWidget {
  final Listenable listenable;
  final String Function() textProvider;
  final void Function(String token)? onRemoveToken;

  const GeometryAttachmentPreview({
    super.key,
    required this.listenable,
    required this.textProvider,
    this.onRemoveToken,
  });

  factory GeometryAttachmentPreview.textController({
    Key? key,
    required TextEditingController controller,
  }) {
    return GeometryAttachmentPreview(
      key: key,
      listenable: controller,
      textProvider: () => controller.text,
      onRemoveToken: (token) {
        controller.value = controller.value.copyWith(
          text: controller.text.replaceAll(token, ''),
          selection: TextSelection.collapsed(
            offset: controller.text.replaceAll(token, '').length,
          ),
        );
      },
    );
  }

  @override
  State<GeometryAttachmentPreview> createState() =>
      _GeometryAttachmentPreviewState();
}

class _GeometryAttachmentPreviewState extends State<GeometryAttachmentPreview> {
  final Map<String, double> _heights = {};

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_refresh);
    GeometryDiagramRegistry.instance.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant GeometryAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable == widget.listenable) return;
    oldWidget.listenable.removeListener(_refresh);
    widget.listenable.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_refresh);
    GeometryDiagramRegistry.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _extractTokens(widget.textProvider());
    if (tokens.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        for (final token in tokens)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PreviewCard(
              token: token,
              diagram: GeometryDiagramRegistry.instance.diagramFor(token.id),
              height: _heights[token.id] ?? 150,
              onDecrease: () => _resize(token.id, -24),
              onIncrease: () => _resize(token.id, 24),
              onRemove: widget.onRemoveToken == null
                  ? null
                  : () => widget.onRemoveToken!(token.raw),
            ),
          ),
      ],
    );
  }

  void _resize(String id, double delta) {
    setState(() {
      _heights[id] = ((_heights[id] ?? 150) + delta).clamp(90.0, 320.0);
    });
  }

  List<_GeometryToken> _extractTokens(String text) {
    final matches = RegExp(r'\{\{geometry:([^}]+)\}\}').allMatches(text);
    final seen = <String>{};
    return [
      for (final match in matches)
        if (seen.add(match.group(1)!))
          _GeometryToken(raw: match.group(0)!, id: match.group(1)!),
    ];
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}

class _PreviewCard extends StatelessWidget {
  final _GeometryToken token;
  final GeometryDiagram? diagram;
  final double height;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback? onRemove;

  const _PreviewCard({
    required this.token,
    required this.diagram,
    required this.height,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final title = Row(
                  children: [
                    Icon(
                      Icons.architecture,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        diagram?.name ?? 'Geometry diagram',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: compact ? WrapAlignment.start : WrapAlignment.end,
                  children: [
                    _MiniAction(
                      icon: Icons.remove,
                      tooltip: 'Decrease size',
                      onTap: onDecrease,
                    ),
                    _MiniAction(
                      icon: Icons.add,
                      tooltip: 'Increase size',
                      onTap: onIncrease,
                    ),
                    if (onRemove != null)
                      _MiniAction(
                        icon: Icons.close,
                        tooltip: 'Remove diagram token',
                        onTap: onRemove!,
                      ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 8), actions],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: diagram == null
                  ? Center(
                      child: Text(
                        token.raw,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : CustomPaint(
                      painter: GeometryPainter(
                        diagram: diagram!.copyWith(showGrid: false),
                        showPointHandles: false,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 36,
        child: IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _GeometryToken {
  final String raw;
  final String id;

  const _GeometryToken({required this.raw, required this.id});
}
