import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_object_commands.dart';
import 'package:edusheet/features/smart_editor/data/smart_document_repository.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expression = MathExpression(
    id: 'math-w3',
    latex: r'x^2 + y^2 = r^2',
    plainText: 'x squared plus y squared equals r squared',
  );
  const diagram = GeometryDiagram(
    id: 'geometry-w3',
    name: 'Circle diagram',
  );

  test('W3 object commands keep math and geometry inside the document delta', () {
    final quill = Document()..insert(0, 'Equation: ');
    final controller = QuillController(
      document: quill,
      selection: const TextSelection.collapsed(offset: 10),
    );
    addTearDown(controller.dispose);

    SmartEditorObjectCommands.insertMath(controller, expression);
    SmartEditorObjectCommands.insertGeometry(controller, diagram);

    final delta = controller.document.toDelta().toJson();
    final source = SmartDocument.blank(title: 'Math & Geometry').copyWith(
      deltaJson: List<dynamic>.from(delta),
    );
    final restored = SmartDocument.fromJson(source.toJson());
    final roundTrip = Document.fromJson(restored.quillOperations);
    final serialized = roundTrip.toDelta().toJson();

    expect(_containsToken(serialized, MathExpression.quillEmbedKey), isTrue);
    expect(_containsToken(serialized, expression.latex), isTrue);
    expect(_containsToken(serialized, 'geometry'), isTrue);
    expect(_containsToken(serialized, diagram.id), isTrue);

    final layout = _findGeometryLayout(serialized);
    expect(layout, isNotNull);
    expect(layout?.diagram?.id, diagram.id);
    expect(layout?.diagram?.name, diagram.name);
  });

  testWidgets('W3 Smart Editor exposes and renders editable academic objects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quill = Document()..insert(0, 'Use ');
    final controller = QuillController(
      document: quill,
      selection: const TextSelection.collapsed(offset: 4),
    );
    SmartEditorObjectCommands.insertMath(controller, expression);
    SmartEditorObjectCommands.insertGeometry(controller, diagram);
    final document = SmartDocument.blank(title: 'W3 Objects').copyWith(
      deltaJson: List<dynamic>.from(controller.document.toDelta().toJson()),
    );
    controller.dispose();
    GeometryDiagramRegistry.instance.remove(diagram.id);

    addTearDown(() => GeometryDiagramRegistry.instance.remove(diagram.id));
    final repository = _MemorySmartDocumentRepository();
    await repository.save(document);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          home: SmartEditorScreen(document: document),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart-editor-academic-object-bar')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-insert-math')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-insert-geometry')), findsOneWidget);
    expect(find.byType(SafeMathExpression), findsOneWidget);
    expect(
      find.byKey(const ValueKey('geometry-embed-geometry-w3')),
      findsOneWidget,
    );

    // Geometry must be recoverable from the saved embed itself even after the
    // transient registry entry is removed before the document is opened.
    expect(GeometryDiagramRegistry.instance.diagramFor(diagram.id), isNotNull);
  });
}

bool _containsToken(Object? value, String token) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key.toString() == token) return true;
      if (_containsToken(entry.value, token)) return true;
    }
    return false;
  }
  if (value is Iterable) {
    for (final item in value) {
      if (_containsToken(item, token)) return true;
    }
    return false;
  }
  return value?.toString().contains(token) == true;
}

GeometryEmbedLayout? _findGeometryLayout(Object? value) {
  if (value is Map) {
    final direct = value['geometry'];
    if (direct != null) {
      final layout = GeometryEmbedLayout.fromData(direct);
      if (layout.id.isNotEmpty) return layout;
    }
    for (final nested in value.values) {
      final layout = _findGeometryLayout(nested);
      if (layout != null) return layout;
    }
    return null;
  }
  if (value is Iterable) {
    for (final nested in value) {
      final layout = _findGeometryLayout(nested);
      if (layout != null) return layout;
    }
    return null;
  }
  if (value is String && value.contains('geometry-w3')) {
    try {
      return _findGeometryLayout(jsonDecode(value));
    } catch (_) {
      final layout = GeometryEmbedLayout.fromData(value);
      return layout.id == 'geometry-w3' ? layout : null;
    }
  }
  return null;
}

class _MemorySmartDocumentRepository implements SmartDocumentRepository {
  final Map<String, SmartDocument> _items = <String, SmartDocument>{};

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Future<List<SmartDocument>> getAll() async => _items.values.toList();

  @override
  Future<SmartDocument?> getById(String id) async => _items[id];

  @override
  Future<void> save(SmartDocument document) async {
    _items[document.id] = document;
  }
}
