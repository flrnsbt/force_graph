import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  group('ForceGraphNodeData tests', () {
    test('creates node with default and custom values', () {
      final node = ForceGraphNodeData.from(
        id: 'node-1',
        title: 'Alpha',
        radius: 0.5,
        pinned: true,
        showLabel: true,
        labelStyle: const TextStyle(fontSize: 14),
      );

      expect(node.iD, 'node-1');
      expect(node.title, 'Alpha');
      expect(node.radius, 0.5);
      expect(node.pinned, isTrue);
      expect(node.showLabel, isTrue);
      expect(node.labelStyle?.fontSize, 14);
      expect(node.removable, isTrue);
    });

    test('copyWith preserves and overrides values', () {
      final original = ForceGraphNodeData.from(
        id: 'node-1',
        title: 'Original',
        pinned: false,
      );

      final modified = original.copyWith(
        title: 'Modified',
        pinned: true,
      );

      expect(modified.iD, 'node-1');
      expect(modified.title, 'Modified');
      expect(modified.pinned, isTrue);
      expect(original.title, 'Original');
      expect(original.pinned, isFalse);
    });

    test('deepCopy duplicates edge list', () {
      final edge = ForceGraphEdgeData.from(
        source: 'node-1',
        target: 'node-2',
        similarity: 0.9,
      );
      final original = ForceGraphNodeData.from(
        id: 'node-1',
        edges: [edge],
      );

      final copy = original.deepCopy();
      expect(copy.edges.length, 1);
      expect(copy.edges.first.source, 'node-1');
      expect(copy.edges.first.target, 'node-2');

      copy.removeEdge(edge.iD);
      expect(copy.edges, isEmpty);
      expect(original.edges.length, 1);
    });
  });

  group('ForceGraphEdgeData tests', () {
    test('creates edge with directed, label and styles', () {
      final edge = ForceGraphEdgeData.from(
        source: 'A',
        target: 'B',
        similarity: 0.75,
        weight: 2.0,
        directed: true,
        label: 'connects to',
        style: GraphComponentStyle.from(color: Colors.blue),
      );

      expect(edge.source, 'A');
      expect(edge.target, 'B');
      expect(edge.similarity, 0.75);
      expect(edge.weight, 2.0);
      expect(edge.directed, isTrue);
      expect(edge.label, 'connects to');
      expect(edge.style.light.color, Colors.blue);
    });

    test('copyWith works correctly', () {
      final original = ForceGraphEdgeData.from(
        source: 'A',
        target: 'B',
        similarity: 0.5,
        directed: false,
      );

      final copy = original.copyWith(directed: true, similarity: 0.9);
      expect(copy.directed, isTrue);
      expect(copy.similarity, 0.9);
      expect(original.directed, isFalse);
    });
  });

  group('GraphComponentStyle tests', () {
    test('light and dark styles support hover and selected colors', () {
      final style = GraphComponentStyle.from(
        color: Colors.white,
        hoverColor: Colors.amber,
        selectedColor: Colors.purple,
        borderWidth: 2.0,
      );

      expect(style.light.color, Colors.white);
      expect(style.light.hoverColor, Colors.amber);
      expect(style.light.selectedColor, Colors.purple);
      expect(style.light.borderWidth, 2.0);
    });
  });
}
