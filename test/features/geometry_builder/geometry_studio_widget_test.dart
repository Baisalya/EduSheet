import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('teacher Studio uses one contextual workflow instead of old modes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeometryBuilderScreen(
            initialShape: GeometryShapeType.triangle,
            maxHeight: 620,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Geometry Studio'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Insert'), findsOneWidget);
    expect(find.text('Shapes'), findsNothing);
    expect(find.text('Draw'), findsNothing);
    expect(find.text('Labels'), findsNothing);
    expect(find.text('Marks'), findsNothing);
    expect(find.text('Export'), findsNothing);
  });
}
