import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';
import 'package:forge2d/forge2d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForceGraphController tests', () {
    test('dynamic node and edge creation', () {
      final controller = ForceGraphController();
      controller.updateCanvasSize(const Size(800, 600));

      controller.addNode(ForceGraphNodeData.from(id: 'root', title: 'Root Node'));

      // Add dynamic node
      final childNode = controller.addNode(
        ForceGraphNodeData.from(
          id: 'child-1',
          title: 'Child 1',
          pinned: true,
        ),
        position: Vector2(5, 5),
      );

      expect(childNode.iD, 'child-1');
      expect(childNode.isPinned, isTrue);

      // Add dynamic edge
      final edge = controller.addEdge(
        ForceGraphEdgeData.from(
          source: 'root',
          target: 'child-1',
          similarity: 0.8,
          directed: true,
          label: 'parent-of',
        ),
      );

      expect(edge, isNotNull);
      expect(edge!.data.source, 'root');
      expect(edge.data.target, 'child-1');
      expect(edge.data.directed, isTrue);
    });

    test('searchNodes finds by id and title', () {
      final controller = ForceGraphController();
      controller.updateCanvasSize(const Size(800, 600));

      controller.addNode(ForceGraphNodeData.from(id: 'auth_service', title: 'Authentication Service'));
      controller.addNode(ForceGraphNodeData.from(id: 'db_pg', title: 'PostgreSQL Database'));
      controller.addNode(ForceGraphNodeData.from(id: 'cache_redis', title: 'Redis Cache'));
      controller.addNode(ForceGraphNodeData.from(id: 'api_gw', title: 'API Gateway'));

      final searchResults = controller.searchNodes('auth');
      expect(searchResults.any((n) => n.iD == 'auth_service'), isTrue);

      final searchByTitle = controller.searchNodes('postgres');
      expect(searchByTitle.any((n) => n.iD == 'db_pg'), isTrue);

      final noResults = controller.searchNodes('nonexistent_xyz');
      expect(noResults, isEmpty);
    });

    test('node pinning toggles physics body type', () {
      final controller = ForceGraphController();
      controller.updateCanvasSize(const Size(800, 600));

      final node = controller.addNode(
        ForceGraphNodeData.from(id: 'pin_test', title: 'Pin Test'),
      );

      expect(node.isPinned, isFalse);
      expect(node.body.bodyType, BodyType.dynamic);

      node.setPinned(true);
      expect(node.isPinned, isTrue);
      expect(node.body.bodyType, BodyType.static);

      node.togglePinned();
      expect(node.isPinned, isFalse);
      expect(node.body.bodyType, BodyType.dynamic);
    });

    test('highlightNodes and resetHighlights adjust opacities', () {
      final controller = ForceGraphController();
      controller.updateCanvasSize(const Size(800, 600));

      final n1 = controller.addNode(ForceGraphNodeData.from(id: '1', title: 'One'));
      final n2 = controller.addNode(ForceGraphNodeData.from(id: '2', title: 'Two'));

      controller.highlightNodes(['1']);
      expect(n1.opacity, 1.0);
      expect(n2.opacity, lessThan(1.0));

      controller.resetHighlights();
      expect(n1.opacity, 1.0);
      expect(n2.opacity, 1.0);
    });

    test('edgeHighlightColor and nodeLabelVisibility configurable', () {
      final controller = ForceGraphController(
        edgeHighlightColor: Colors.teal,
        nodeLabelVisibility: NodeLabelVisibility.hoveredOrSelected,
      );

      expect(controller.edgeHighlightColor, Colors.teal);
      expect(controller.nodeLabelVisibility, NodeLabelVisibility.hoveredOrSelected);

      controller.nodeLabelVisibility = NodeLabelVisibility.always;
      expect(controller.nodeLabelVisibility, NodeLabelVisibility.always);
    });
  });
}
