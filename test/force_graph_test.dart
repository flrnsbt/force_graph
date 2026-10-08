import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  test('ForceGraphNodeData and EdgeData creation', () {
    final edge = ForceGraphEdgeData.from(
      source: '1',
      target: '2',
      similarity: 0.8,
    );
    expect(edge.source, '1');
    expect(edge.target, '2');
    expect(edge.similarity, 0.8);
    expect(edge.weight, 1.0);

    final node = ForceGraphNodeData.from(
      id: '1',
      title: 'Node 1',
      edges: [edge],
    );
    expect(node.iD, '1');
    expect(node.title, 'Node 1');
    expect(node.edges.length, 1);
  });
}
