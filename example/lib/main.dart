import 'dart:math';

import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.light(),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mockGraphNodes = generateMockGraph(
      maxEdgesPerNode: 6,
      minEdgesPerNode: 1,
      nodeCount: 30,
    );

    // final mockGraphNodes = [
    //   ForceGraphNodeData.from(
    //     id: 'doc1',
    //     title: 'Document 1',
    //     style: GraphComponentStyle(color: Colors.blue),
    //     edges: [
    //       ForceGraphEdgeData.from(
    //         source: 'doc1',
    //         target: 'doc12',
    //         similarity: 1,
    //         weight: 1,
    //       ),
    //     ],
    //   ),
    //   ForceGraphNodeData.from(
    //     id: 'doc2',
    //     title: 'Document 2',
    //     edges: [
    //       ForceGraphEdgeData.from(
    //         source: 'doc2',
    //         target: 'doc13',
    //         similarity: 1,
    //         weight: 1,
    //       ),
    //     ],
    //   ),
    //   // ForceGraphNodeData.from(id: 'doc12', title: 'Document 12'),
    //   // ForceGraphNodeData.from(id: 'doc13', title: 'Document 13'),
    // ];

    return Scaffold(
      body: ForceGraphWidget(
        controller: ForceGraphController(
          nodes: mockGraphNodes,
          uniformEdgeWeight: true,
        ),
        edgeTooltipBuilder: (context, edge) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  edge.data.similarity.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
        nodeTooltipBuilder: (context, node) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(node.data.title),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<ForceGraphNodeData> generateMockGraph({
  int nodeCount = 10,
  int minEdgesPerNode = 5,
  int maxEdgesPerNode = 1,
}) {
  final rand = Random();
  final List<ForceGraphNodeData> nodes = [];
  final List<String> ids = List.generate(nodeCount, (i) => 'doc${i + 1}');
  final List<Color> palette = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
  ];

  for (int i = 0; i < nodeCount; i++) {
    final color = palette[i % palette.length];
    nodes.add(
      ForceGraphNodeData.from(
        id: ids[i],
        title: 'Document ${i + 1}',
        style: GraphComponentStyle.from(color: color),
        edges: [],
      ),
    );
  }

  for (final node in nodes) {
    final edgeCount =
        rand.nextInt(maxEdgesPerNode - minEdgesPerNode + 1) + minEdgesPerNode;
    final Set<String> connected = {};

    while (node.edges.length < edgeCount) {
      final targetIndex = rand.nextInt(nodeCount);
      final targetId = ids[targetIndex];

      if (targetId == node.id || connected.contains(targetId)) continue;
      connected.add(targetId);

      final similarity = rand.nextDouble() * 0.9 + 0.1; // 0.4 - 1.0
      final weight = rand.nextDouble() * 0.8 + 0.2;

      node.edges.add(
        ForceGraphEdgeData.from(
          source: node.id,
          target: targetId,
          similarity: similarity,
          weight: weight,
          style: GraphComponentStyle.from(
            color: Colors.black.withValues(alpha: 0.2),
          ),
        ),
      );
    }
  }

  return nodes;
}
