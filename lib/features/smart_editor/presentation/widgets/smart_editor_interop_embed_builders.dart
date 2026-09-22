import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class SmartEditorInteropImagePayload {
  const SmartEditorInteropImagePayload({
    required this.bytes,
    this.widthPoints = 160,
    this.heightPoints = 120,
    this.altText,
    this.hyperlink,
  });

  final Uint8List bytes;
  final double widthPoints;
  final double heightPoints;
  final String? altText;
  final String? hyperlink;

  String encode() => jsonEncode(<String, dynamic>{
        'bytes': base64Encode(bytes),
        'widthPoints': widthPoints,
        'heightPoints': heightPoints,
        if (altText != null) 'altText': altText,
        if (hyperlink != null) 'hyperlink': hyperlink,
      });

  factory SmartEditorInteropImagePayload.fromData(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) throw const FormatException('Invalid image payload');
      final map = Map<String, dynamic>.from(raw);
      return SmartEditorInteropImagePayload(
        bytes: Uint8List.fromList(base64Decode(map['bytes']?.toString() ?? '')),
        widthPoints: _double(map['widthPoints'], 160),
        heightPoints: _double(map['heightPoints'], 120),
        altText: _nullableString(map['altText']),
        hyperlink: _nullableString(map['hyperlink']),
      );
    } catch (_) {
      return SmartEditorInteropImagePayload(bytes: Uint8List(0));
    }
  }
}

class SmartEditorInteropTablePayload {
  const SmartEditorInteropTablePayload({
    required this.rows,
    this.showBorders = true,
  });

  final List<SmartEditorInteropTableRow> rows;
  final bool showBorders;

  String encode() => jsonEncode(<String, dynamic>{
        'showBorders': showBorders,
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
      });

  factory SmartEditorInteropTablePayload.fromData(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) throw const FormatException('Invalid table payload');
      final map = Map<String, dynamic>.from(raw);
      return SmartEditorInteropTablePayload(
        showBorders: map['showBorders'] != false,
        rows: (map['rows'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((row) => SmartEditorInteropTableRow.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList(growable: false),
      );
    } catch (_) {
      return const SmartEditorInteropTablePayload(rows: <SmartEditorInteropTableRow>[]);
    }
  }
}

class SmartEditorInteropTableRow {
  const SmartEditorInteropTableRow({
    required this.cells,
    this.header = false,
  });

  final List<SmartEditorInteropTableCell> cells;
  final bool header;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'header': header,
        'cells': cells.map((cell) => cell.toJson()).toList(growable: false),
      };

  factory SmartEditorInteropTableRow.fromJson(Map<String, dynamic> json) {
    return SmartEditorInteropTableRow(
      header: json['header'] == true,
      cells: (json['cells'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((cell) => SmartEditorInteropTableCell.fromJson(
                Map<String, dynamic>.from(cell),
              ))
          .toList(growable: false),
    );
  }
}

class SmartEditorInteropTableCell {
  const SmartEditorInteropTableCell({
    required this.text,
    this.shadingHex,
    this.widthPoints,
  });

  final String text;
  final String? shadingHex;
  final double? widthPoints;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        if (shadingHex != null) 'shadingHex': shadingHex,
        if (widthPoints != null) 'widthPoints': widthPoints,
      };

  factory SmartEditorInteropTableCell.fromJson(Map<String, dynamic> json) {
    return SmartEditorInteropTableCell(
      text: json['text']?.toString() ?? '',
      shadingHex: _nullableString(json['shadingHex']),
      widthPoints: json['widthPoints'] is num
          ? (json['widthPoints'] as num).toDouble()
          : null,
    );
  }
}

class SmartEditorInteropImageEmbedBuilder extends EmbedBuilder {
  static const keyName = 'smartDocxImage';

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorInteropImagePayload.fromData(
      embedContext.node.value.data,
    );
    if (payload.bytes.isEmpty) {
      return const _InteropPlaceholder(
        icon: Icons.broken_image_outlined,
        label: 'Image unavailable',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = payload.widthPoints.clamp(48.0, maxWidth).toDouble();
        final sourceHeight = payload.heightPoints <= 0 ? 120.0 : payload.heightPoints;
        final sourceWidth = payload.widthPoints <= 0 ? 160.0 : payload.widthPoints;
        final height = (sourceHeight * (width / sourceWidth))
            .clamp(36.0, 640.0)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.memory(
              payload.bytes,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _InteropPlaceholder(
                icon: Icons.broken_image_outlined,
                label: 'Unsupported Word image',
              ),
            ),
          ),
        );
      },
    );
  }
}

class SmartEditorInteropTableEmbedBuilder extends EmbedBuilder {
  static const keyName = 'smartDocxTable';

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorInteropTablePayload.fromData(
      embedContext.node.value.data,
    );
    if (payload.rows.isEmpty) {
      return const _InteropPlaceholder(
        icon: Icons.table_chart_outlined,
        label: 'Empty Word table',
      );
    }
    final theme = Theme.of(context);
    final border = payload.showBorders
        ? TableBorder.all(color: theme.colorScheme.outlineVariant)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Table(
          border: border,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final row in payload.rows)
              TableRow(
                decoration: row.header
                    ? BoxDecoration(color: theme.colorScheme.surfaceContainerHighest)
                    : null,
                children: [
                  for (final cell in row.cells)
                    Container(
                      color: _hexColor(cell.shadingHex),
                      padding: const EdgeInsets.all(7),
                      child: Text(
                        cell.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: row.header ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InteropPlaceholder extends StatelessWidget {
  const _InteropPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

Color? _hexColor(String? value) {
  if (value == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return null;
  }
  return Color(0xFF000000 | int.parse(value, radix: 16));
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _double(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
