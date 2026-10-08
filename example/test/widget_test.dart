import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';
import 'package:example/datasets.dart';

void main() {
  testWidgets('ForceGraphShowcaseApp smoke test, dataset switching and layouts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ForceGraphShowcaseApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('force_graph'), findsOneWidget);
    expect(find.text('AI Knowledge Graph'), findsWidgets);

    // Switch dataset to Package Dependencies
    await tester.tap(find.text('AI Knowledge Graph').first);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Package Dependencies').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Package Dependencies'), findsWidgets);

    // Switch dataset to Team & Social Network
    await tester.tap(find.text('Package Dependencies').first);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Team & Social Network').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Team & Social Network'), findsWidgets);

    // Switch dataset to Interactive Playground
    await tester.tap(find.text('Team & Social Network').first);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Interactive Playground').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Interactive Playground'), findsWidgets);

    // Switch layout algorithm to Circular Layout
    await tester.tap(find.text('Spring Embedder').first);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Circular Layout').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Switch layout algorithm to Hierarchical
    await tester.tap(find.text('Circular Layout').first);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Hierarchical').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Toggle Label Visibility button
    final labelToggle = find.byTooltip('Labels: hoveredOrSelected');
    expect(labelToggle, findsOneWidget);
    await tester.tap(labelToggle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byTooltip('Labels: always'), findsOneWidget);
  });

  test('All ExampleDatasets generate non-empty nodes with correct radius range', () {
    for (final dataset in ExampleDatasets.all) {
      final nodes = dataset.generator();
      expect(nodes.isNotEmpty, isTrue, reason: 'Dataset ${dataset.id} should have nodes');

      for (final node in nodes) {
        expect(node.radius, greaterThanOrEqualTo(9.0),
            reason: 'Node ${node.iD} in ${dataset.id} radius too small');
        expect(node.radius, lessThanOrEqualTo(20.0),
            reason: 'Node ${node.iD} in ${dataset.id} radius too large');

        for (final edge in node.edges) {
          expect(edge.weight, greaterThanOrEqualTo(1.5),
              reason: 'Edge ${edge.source}->${edge.target} in ${dataset.id} weight too thin');
        }
      }
    }
  });
}
