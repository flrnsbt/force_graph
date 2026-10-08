import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  group('GraphBuilder tests', () {
    test('CircularGraphBuilder positions nodes symmetrically', () async {
      final builder = CircularGraphBuilder(radius: 100);
      final nodes = [
        ForceGraphNodeData.from(id: 'n1', title: 'Node 1'),
        ForceGraphNodeData.from(id: 'n2', title: 'Node 2'),
        ForceGraphNodeData.from(id: 'n3', title: 'Node 3'),
        ForceGraphNodeData.from(id: 'n4', title: 'Node 4'),
      ];

      await builder.performLayout(nodes, const Size(400, 400));
      final positionedNodes = builder.getNodes();

      expect(positionedNodes.length, 4);
      for (final pos in positionedNodes.values) {
        expect(pos.x.isFinite, isTrue);
        expect(pos.y.isFinite, isTrue);
      }
    });

    test('HierarchicalGraphBuilder generates layered positions', () async {
      final builder = HierarchicalGraphBuilder(
        horizontalSpacing: 50,
        verticalSpacing: 50,
      );
      final nodes = [
        ForceGraphNodeData.from(
          id: 'root',
          title: 'Root',
          edges: [
            ForceGraphEdgeData.from(source: 'root', target: 'child1', similarity: 1),
            ForceGraphEdgeData.from(source: 'root', target: 'child2', similarity: 1),
          ],
        ),
        ForceGraphNodeData.from(id: 'child1', title: 'Child 1'),
        ForceGraphNodeData.from(id: 'child2', title: 'Child 2'),
      ];

      await builder.performLayout(nodes, const Size(400, 400));
      final positionedNodes = builder.getNodes();

      expect(positionedNodes.length, 3);
      for (final pos in positionedNodes.values) {
        expect(pos.x.isFinite, isTrue);
        expect(pos.y.isFinite, isTrue);
      }
    });
    test('SpringEmbedderGraphBuilder spaces nodes without collapsing', () async {
      final builder = SpringEmbedderGraphBuilder(iterations: 80);
      final nodes = [
        ForceGraphNodeData.from(
          id: 'n1',
          title: 'Node 1',
          radius: 18.0,
          edges: [
            ForceGraphEdgeData.from(source: 'n1', target: 'n2', similarity: 0.8),
            ForceGraphEdgeData.from(source: 'n1', target: 'n3', similarity: 0.8),
          ],
        ),
        ForceGraphNodeData.from(id: 'n2', title: 'Node 2', radius: 18.0),
        ForceGraphNodeData.from(id: 'n3', title: 'Node 3', radius: 18.0),
      ];

      await builder.performLayout(nodes, const Size(800, 600));
      final positionedNodes = builder.getNodes();

      expect(positionedNodes.length, 3);
      final positions = positionedNodes.values.toList();
      for (int i = 0; i < positions.length; i++) {
        for (int j = i + 1; j < positions.length; j++) {
          final dist = positions[i].distanceTo(positions[j]);
          expect(dist, greaterThan(30.0),
              reason: 'Nodes $i and $j should not overlap');
        }
      }
    });
  });
}
