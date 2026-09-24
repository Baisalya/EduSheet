import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// WM7/WM8 inline bridge for Word objects that must remain structured inside
/// paragraph flow instead of being flattened to placeholder text.
///
/// The payload intentionally stores both editable/display data and preservation
/// metadata (for example raw OMML). A caller may edit the friendly fields while
/// an unchanged object can round-trip the original Word intent.
class SmartEditorWordAdvancedPayload {
  const SmartEditorWordAdvancedPayload({
    required this.kind,
    required this.objectId,
    this.referenceId,
    this.name,
    this.instruction,
    this.resultText = '',
    this.contentText = '',
    this.author,
    this.initials,
    this.dateIso,
    this.rawXml,
    this.featureKind,
    this.ooxmlScope = 'inline',
    this.relationshipIds = const <String>[],
    this.display = false,
    this.locked = false,
    this.dirty = false,
  });

  static const String fieldKind = 'field';
  static const String equationKind = 'equation';
  static const String footnoteKind = 'footnote';
  static const String endnoteKind = 'endnote';
  static const String bookmarkStartKind = 'bookmarkStart';
  static const String bookmarkEndKind = 'bookmarkEnd';
  static const String commentStartKind = 'commentStart';
  static const String commentEndKind = 'commentEnd';
  static const String commentReferenceKind = 'commentReference';
  static const String opaqueOoxmlKind = 'opaqueOoxml';

  final String kind;
  final String objectId;
  final String? referenceId;
  final String? name;
  final String? instruction;
  final String resultText;
  final String contentText;
  final String? author;
  final String? initials;
  final String? dateIso;
  final String? rawXml;
  final String? featureKind;
  final String ooxmlScope;
  final List<String> relationshipIds;
  final bool display;
  final bool locked;
  final bool dirty;

  bool get isMarker =>
      kind == bookmarkStartKind ||
      kind == bookmarkEndKind ||
      kind == commentStartKind ||
      kind == commentEndKind;

  bool get isNote => kind == footnoteKind || kind == endnoteKind;

  String get fieldName {
    final value = instruction?.trim() ?? '';
    if (value.isEmpty) return '';
    return value.split(RegExp(r'\s+')).first.toUpperCase();
  }

  String get visibleText {
    switch (kind) {
      case fieldKind:
        if (resultText.isNotEmpty) return resultText;
        return '{${fieldName.isEmpty ? 'FIELD' : fieldName}}';
      case equationKind:
        return resultText.isNotEmpty ? resultText : '∑';
      case footnoteKind:
      case endnoteKind:
        return referenceId ?? '*';
      case commentReferenceKind:
        return contentText;
      case bookmarkStartKind:
      case bookmarkEndKind:
        return name ?? 'bookmark';
      case commentStartKind:
      case commentEndKind:
        return contentText;
      case opaqueOoxmlKind:
        if (contentText.trim().isNotEmpty) return contentText;
        return '[Word ${featureKind ?? 'object'} preserved]';
      default:
        return resultText.isNotEmpty ? resultText : contentText;
    }
  }

  SmartEditorWordAdvancedPayload copyWith({
    String? kind,
    String? objectId,
    String? referenceId,
    String? name,
    String? instruction,
    String? resultText,
    String? contentText,
    String? author,
    String? initials,
    String? dateIso,
    String? rawXml,
    String? featureKind,
    String? ooxmlScope,
    List<String>? relationshipIds,
    bool? display,
    bool? locked,
    bool? dirty,
  }) {
    return SmartEditorWordAdvancedPayload(
      kind: kind ?? this.kind,
      objectId: objectId ?? this.objectId,
      referenceId: referenceId ?? this.referenceId,
      name: name ?? this.name,
      instruction: instruction ?? this.instruction,
      resultText: resultText ?? this.resultText,
      contentText: contentText ?? this.contentText,
      author: author ?? this.author,
      initials: initials ?? this.initials,
      dateIso: dateIso ?? this.dateIso,
      rawXml: rawXml ?? this.rawXml,
      featureKind: featureKind ?? this.featureKind,
      ooxmlScope: ooxmlScope ?? this.ooxmlScope,
      relationshipIds: relationshipIds ?? this.relationshipIds,
      display: display ?? this.display,
      locked: locked ?? this.locked,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'objectId': objectId,
        if (referenceId != null) 'referenceId': referenceId,
        if (name != null) 'name': name,
        if (instruction != null) 'instruction': instruction,
        if (resultText.isNotEmpty) 'resultText': resultText,
        if (contentText.isNotEmpty) 'contentText': contentText,
        if (author != null) 'author': author,
        if (initials != null) 'initials': initials,
        if (dateIso != null) 'dateIso': dateIso,
        if (rawXml != null) 'rawXml': rawXml,
        if (featureKind != null) 'featureKind': featureKind,
        if (ooxmlScope != 'inline') 'ooxmlScope': ooxmlScope,
        if (relationshipIds.isNotEmpty) 'relationshipIds': relationshipIds,
        if (display) 'display': true,
        if (locked) 'locked': true,
        if (dirty) 'dirty': true,
      };

  String encode() => jsonEncode(toJson());

  factory SmartEditorWordAdvancedPayload.fromData(Object? data) {
    if (data is String) {
      return _advancedPayloadCache.resolve(
        data,
        () => SmartEditorWordAdvancedPayload._parse(data),
      );
    }
    return SmartEditorWordAdvancedPayload._parse(data);
  }

  static SmartEditorWordAdvancedPayload _parse(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) throw const FormatException('Invalid Word object payload');
      final map = Map<String, dynamic>.from(raw);
      return SmartEditorWordAdvancedPayload(
        kind: map['kind']?.toString() ?? fieldKind,
        objectId: map['objectId']?.toString() ?? 'word-object',
        referenceId: _nullableString(map['referenceId']),
        name: _nullableString(map['name']),
        instruction: _nullableString(map['instruction']),
        resultText: map['resultText']?.toString() ?? '',
        contentText: map['contentText']?.toString() ?? '',
        author: _nullableString(map['author']),
        initials: _nullableString(map['initials']),
        dateIso: _nullableString(map['dateIso']),
        rawXml: _nullableString(map['rawXml']),
        featureKind: _nullableString(map['featureKind']),
        ooxmlScope: _nullableString(map['ooxmlScope']) ?? 'inline',
        relationshipIds: (map['relationshipIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false),
        display: map['display'] == true,
        locked: map['locked'] == true,
        dirty: map['dirty'] == true,
      );
    } catch (_) {
      return const SmartEditorWordAdvancedPayload(
        kind: fieldKind,
        objectId: 'invalid-word-object',
        resultText: '[Word object]',
      );
    }
  }
}

class _AdvancedPayloadCache<T> {
  _AdvancedPayloadCache(this.maxEntries);

  final int maxEntries;
  final LinkedHashMap<String, T> _values = LinkedHashMap<String, T>();

  T resolve(String key, T Function() create) {
    final cached = _values.remove(key);
    if (cached != null) {
      _values[key] = cached;
      return cached;
    }
    final value = create();
    _values[key] = value;
    while (_values.length > maxEntries) {
      _values.remove(_values.keys.first);
    }
    return value;
  }
}

final _advancedPayloadCache =
    _AdvancedPayloadCache<SmartEditorWordAdvancedPayload>(48);

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class SmartEditorWordAdvancedEmbed extends Embeddable {
  SmartEditorWordAdvancedEmbed(SmartEditorWordAdvancedPayload payload)
      : super(SmartEditorWordAdvancedEmbedBuilder.keyName, payload.encode());
}

typedef SmartEditorWordAdvancedEditCallback =
    Future<SmartEditorWordAdvancedPayload?> Function(
      BuildContext context,
      SmartEditorWordAdvancedPayload payload,
    );

class SmartEditorWordAdvancedEmbedBuilder extends EmbedBuilder {
  const SmartEditorWordAdvancedEmbedBuilder({this.onEdit});

  static const keyName = 'smartWordObject';
  final SmartEditorWordAdvancedEditCallback? onEdit;

  @override
  String get key => keyName;

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) {
    final payload = SmartEditorWordAdvancedPayload.fromData(node.value.data);
    if (payload.isMarker) return '';
    if (payload.kind == SmartEditorWordAdvancedPayload.commentReferenceKind) {
      return '';
    }
    return payload.visibleText;
  }

  @override
  WidgetSpan buildWidgetSpan(Widget widget) =>
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: widget);

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorWordAdvancedPayload.fromData(
      embedContext.node.value.data,
    );
    final child = _WordAdvancedInline(
      payload: payload,
      textStyle: embedContext.textStyle,
      showEditingChrome: !embedContext.readOnly,
    );
    if (embedContext.readOnly ||
        onEdit == null ||
        payload.kind == SmartEditorWordAdvancedPayload.opaqueOoxmlKind) {
      return child;
    }
    return Tooltip(
      message: _tooltip(payload),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _edit(context, embedContext, payload),
          child: child,
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    EmbedContext embedContext,
    SmartEditorWordAdvancedPayload payload,
  ) async {
    final callback = onEdit;
    if (callback == null) return;
    final updated = await callback(context, payload);
    if (updated == null || !context.mounted) return;
    final offset = embedContext.node.documentOffset;
    embedContext.controller.replaceText(
      offset,
      1,
      SmartEditorWordAdvancedEmbed(updated),
      null,
    );
    embedContext.controller.updateSelection(
      TextSelection.collapsed(offset: offset + 1),
      ChangeSource.local,
    );
  }

  static String _tooltip(SmartEditorWordAdvancedPayload payload) {
    return switch (payload.kind) {
      SmartEditorWordAdvancedPayload.fieldKind => 'Edit Word field',
      SmartEditorWordAdvancedPayload.equationKind => 'Review Word equation',
      SmartEditorWordAdvancedPayload.footnoteKind => 'Edit footnote',
      SmartEditorWordAdvancedPayload.endnoteKind => 'Edit endnote',
      SmartEditorWordAdvancedPayload.commentReferenceKind => 'Edit comment',
      SmartEditorWordAdvancedPayload.bookmarkStartKind ||
      SmartEditorWordAdvancedPayload.bookmarkEndKind => 'Edit bookmark',
      SmartEditorWordAdvancedPayload.opaqueOoxmlKind =>
        'Preserved Word ${payload.featureKind ?? 'object'} (not editable)',
      _ => 'Edit Word object',
    };
  }
}

class _WordAdvancedInline extends StatelessWidget {
  const _WordAdvancedInline({
    required this.payload,
    required this.textStyle,
    required this.showEditingChrome,
  });

  final SmartEditorWordAdvancedPayload payload;
  final TextStyle textStyle;
  final bool showEditingChrome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (payload.isMarker) {
      if (!showEditingChrome) return const SizedBox.shrink();
      final bookmark = payload.kind.startsWith('bookmark');
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Icon(
          bookmark ? Icons.bookmark_border_rounded : Icons.comment_outlined,
          size: 13,
          color: scheme.outline,
        ),
      );
    }

    if (payload.kind == SmartEditorWordAdvancedPayload.footnoteKind ||
        payload.kind == SmartEditorWordAdvancedPayload.endnoteKind) {
      return Transform.translate(
        offset: const Offset(0, -4),
        child: Text(
          payload.referenceId ?? '*',
          key: ValueKey('smart-word-${payload.kind}-${payload.objectId}'),
          style: textStyle.copyWith(
            fontSize: (textStyle.fontSize ?? 14) * 0.72,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      );
    }

    if (payload.kind == SmartEditorWordAdvancedPayload.commentReferenceKind) {
      return Icon(
        Icons.comment_outlined,
        key: ValueKey('smart-word-comment-${payload.objectId}'),
        size: (textStyle.fontSize ?? 14) * 0.95,
        color: scheme.tertiary,
      );
    }

    final equation = payload.kind == SmartEditorWordAdvancedPayload.equationKind;
    final field = payload.kind == SmartEditorWordAdvancedPayload.fieldKind;
    final opaque = payload.kind == SmartEditorWordAdvancedPayload.opaqueOoxmlKind;
    Widget text = Text(
      payload.visibleText,
      key: ValueKey('smart-word-${payload.kind}-${payload.objectId}'),
      style: textStyle.copyWith(
        fontFamily: equation ? 'Cambria Math' : textStyle.fontFamily,
        fontStyle: opaque || (field && payload.dirty)
            ? FontStyle.italic
            : textStyle.fontStyle,
      ),
    );
    if (!showEditingChrome) return text;
    text = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: text,
      ),
    );
    return text;
  }
}

/// Small editor for WM7/WM8 objects. Editing changes only the friendly fields;
/// preservation metadata such as raw OMML remains attached to the same object.
class SmartEditorWordAdvancedEditorDialog {
  const SmartEditorWordAdvancedEditorDialog._();

  static Future<SmartEditorWordAdvancedPayload?> show(
    BuildContext context,
    SmartEditorWordAdvancedPayload payload,
  ) async {
    final primary = TextEditingController(
      text: _primaryValue(payload),
    );
    final secondary = TextEditingController(
      text: _secondaryValue(payload),
    );
    final result = await showDialog<SmartEditorWordAdvancedPayload>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_title(payload)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: primary,
                  maxLines: payload.isNote ||
                          payload.kind ==
                              SmartEditorWordAdvancedPayload.commentReferenceKind
                      ? 5
                      : 2,
                  decoration: InputDecoration(labelText: _primaryLabel(payload)),
                ),
                if (_needsSecondary(payload)) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: secondary,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _secondaryLabel(payload),
                    ),
                  ),
                ],
                if (payload.kind == SmartEditorWordAdvancedPayload.equationKind &&
                    payload.rawXml?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Native Word OMML is preserved. Editing the fallback label does not flatten the equation.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  _apply(payload, primary.text, secondary.text),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    primary.dispose();
    secondary.dispose();
    return result;
  }

  static String _title(SmartEditorWordAdvancedPayload payload) => switch (payload.kind) {
        SmartEditorWordAdvancedPayload.fieldKind => 'Word field',
        SmartEditorWordAdvancedPayload.equationKind => 'Word equation',
        SmartEditorWordAdvancedPayload.footnoteKind => 'Footnote',
        SmartEditorWordAdvancedPayload.endnoteKind => 'Endnote',
        SmartEditorWordAdvancedPayload.commentReferenceKind => 'Comment',
        SmartEditorWordAdvancedPayload.bookmarkStartKind ||
        SmartEditorWordAdvancedPayload.bookmarkEndKind => 'Bookmark',
        _ => 'Word object',
      };

  static bool _needsSecondary(SmartEditorWordAdvancedPayload payload) =>
      payload.kind == SmartEditorWordAdvancedPayload.fieldKind ||
      payload.kind == SmartEditorWordAdvancedPayload.commentReferenceKind;

  static String _primaryLabel(SmartEditorWordAdvancedPayload payload) =>
      switch (payload.kind) {
        SmartEditorWordAdvancedPayload.fieldKind => 'Displayed result',
        SmartEditorWordAdvancedPayload.equationKind => 'Readable fallback',
        SmartEditorWordAdvancedPayload.footnoteKind ||
        SmartEditorWordAdvancedPayload.endnoteKind => 'Note text',
        SmartEditorWordAdvancedPayload.commentReferenceKind => 'Comment text',
        SmartEditorWordAdvancedPayload.bookmarkStartKind ||
        SmartEditorWordAdvancedPayload.bookmarkEndKind => 'Bookmark name',
        _ => 'Value',
      };

  static String _secondaryLabel(SmartEditorWordAdvancedPayload payload) =>
      payload.kind == SmartEditorWordAdvancedPayload.fieldKind
          ? 'Field instruction'
          : 'Author';

  static String _primaryValue(SmartEditorWordAdvancedPayload payload) =>
      switch (payload.kind) {
        SmartEditorWordAdvancedPayload.fieldKind ||
        SmartEditorWordAdvancedPayload.equationKind => payload.resultText,
        SmartEditorWordAdvancedPayload.footnoteKind ||
        SmartEditorWordAdvancedPayload.endnoteKind ||
        SmartEditorWordAdvancedPayload.commentReferenceKind =>
          payload.contentText,
        SmartEditorWordAdvancedPayload.bookmarkStartKind ||
        SmartEditorWordAdvancedPayload.bookmarkEndKind => payload.name ?? '',
        _ => payload.visibleText,
      };

  static String _secondaryValue(SmartEditorWordAdvancedPayload payload) =>
      payload.kind == SmartEditorWordAdvancedPayload.fieldKind
          ? payload.instruction ?? ''
          : payload.author ?? '';

  static SmartEditorWordAdvancedPayload _apply(
    SmartEditorWordAdvancedPayload payload,
    String primary,
    String secondary,
  ) {
    switch (payload.kind) {
      case SmartEditorWordAdvancedPayload.fieldKind:
        return payload.copyWith(
          resultText: primary,
          instruction: secondary,
          dirty: true,
        );
      case SmartEditorWordAdvancedPayload.equationKind:
        return payload.copyWith(resultText: primary);
      case SmartEditorWordAdvancedPayload.footnoteKind:
      case SmartEditorWordAdvancedPayload.endnoteKind:
        return payload.copyWith(contentText: primary);
      case SmartEditorWordAdvancedPayload.commentReferenceKind:
        return payload.copyWith(contentText: primary, author: secondary);
      case SmartEditorWordAdvancedPayload.bookmarkStartKind:
      case SmartEditorWordAdvancedPayload.bookmarkEndKind:
        return payload.copyWith(name: primary);
      default:
        return payload;
    }
  }
}
