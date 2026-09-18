import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/paper_composer/presentation/responsive/paper_page_canvas_metrics.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_page_design_surface.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 7 page tools serialize and restore canonically', () {
    const layout = PaperPageLayout(
      pageSize: PaperPageSize.letter,
      orientation: PaperPageOrientation.landscape,
      margins: PaperPageMargins(
        topPoints: 30,
        rightPoints: 32,
        bottomPoints: 34,
        leftPoints: 36,
      ),
      columns: PaperPageColumns.three,
      columnSpacingPoints: 24,
      watermarkText: 'SAMPLE',
      watermarkOpacity: 0.18,
      pageBackgroundArgb: 0xFFFFFDF5,
      showRulers: true,
      showGrid: true,
      gridSpacingPoints: 12,
    );

    final restored = PaperPageLayout.fromJson(layout.toJson());

    expect(restored.pageSize, PaperPageSize.letter);
    expect(restored.orientation, PaperPageOrientation.landscape);
    expect(restored.columns, PaperPageColumns.three);
    expect(restored.columnSpacingPoints, 24);
    expect(restored.watermarkText, 'SAMPLE');
    expect(restored.watermarkOpacity, closeTo(0.18, 0.001));
    expect(restored.pageBackgroundArgb, 0xFFFFFDF5);
    expect(restored.showRulers, isTrue);
    expect(restored.showGrid, isTrue);
    expect(restored.gridSpacingPoints, 12);
  });

  test('legacy page layout remains backward compatible', () {
    final restored = PaperPageLayout.fromJson(const <String, dynamic>{});

    expect(restored.columns, PaperPageColumns.useTemplate);
    expect(restored.columnSpacingPoints, 18);
    expect(restored.watermarkText, isEmpty);
    expect(restored.pageBackgroundArgb, 0xFFFFFFFF);
    expect(restored.showRulers, isFalse);
    expect(restored.showGrid, isFalse);
  });

  test('page canvas resolves template and explicit column intent', () {
    final templateDriven = PaperPageCanvasMetrics.resolve(
      layout: const PaperPageLayout(),
      templatePageSize: PaperSize.a4,
      viewportWidth: 900,
      templateTwoColumn: true,
    );
    final explicit = PaperPageCanvasMetrics.resolve(
      layout: const PaperPageLayout(columns: PaperPageColumns.three),
      templatePageSize: PaperSize.a4,
      viewportWidth: 900,
      templateTwoColumn: false,
    );

    expect(templateDriven.resolvedColumnCount, 2);
    expect(explicit.resolvedColumnCount, 3);
  });

  testWidgets('watermark is document content while grid and rulers are editor only', (
    tester,
  ) async {
    const layout = PaperPageLayout(
      watermarkText: 'DRAFT',
      showGrid: true,
      showRulers: true,
      columns: PaperPageColumns.two,
    );

    Future<void> pump({required bool editorChrome, required bool compact}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 800,
                child: PaperPageDesignSurface(
                  layout: layout,
                  pageScale: 1,
                  pagePadding: const EdgeInsets.all(36),
                  resolvedColumnCount: 2,
                  compact: compact,
                  showEditorChrome: editorChrome,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pump(editorChrome: true, compact: false);
    expect(find.byKey(const Key('paper-page-watermark')), findsOneWidget);
    expect(find.byKey(const Key('word-page-layout-guides')), findsOneWidget);

    await pump(editorChrome: false, compact: false);
    expect(find.byKey(const Key('paper-page-watermark')), findsOneWidget);
    expect(find.byKey(const Key('word-page-layout-guides')), findsNothing);

    await pump(editorChrome: true, compact: true);
    expect(find.byKey(const Key('paper-page-watermark')), findsOneWidget);
    expect(find.byKey(const Key('word-page-layout-guides')), findsNothing);
  });
}
