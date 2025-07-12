import 'dart:math';

import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
      maxEdgesPerNode: 3,
      minEdgesPerNode: 2,
      nodeCount: 50,
    );

    return Scaffold(
      body: ForceGraphWidget(
        controller: ForceGraphController(
          nodes: mockGraphNodes,
          forceDirectedGraphLayoutIteration: 1000,
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

// Assumes your ForceGraphNodeData, ForceGraphEdgeData, GraphComponentStyle are defined

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

  // Generate nodes first
  for (int i = 0; i < nodeCount; i++) {
    final color = palette[i % palette.length];
    nodes.add(
      ForceGraphNodeData.from(
        id: ids[i],
        title: 'Document ${i + 1}',
        style: GraphComponentStyle(color: color),
        edges: [],
      ),
    );
  }

  // Generate edges
  for (final node in nodes) {
    final edgeCount =
        rand.nextInt(maxEdgesPerNode - minEdgesPerNode + 1) + minEdgesPerNode;
    final Set<String> connected = {};

    while (node.edges.length < edgeCount) {
      final targetIndex = rand.nextInt(nodeCount);
      final targetId = ids[targetIndex];

      if (targetId == node.id || connected.contains(targetId)) continue;
      connected.add(targetId);

      final similarity = rand.nextDouble() * 0.6 + 0.4; // 0.4 - 1.0
      final weight = rand.nextDouble() * 0.8 + 0.2;

      node.edges.add(
        ForceGraphEdgeData.from(
          source: node.id,
          target: targetId,
          similarity: similarity,
          weight: weight,
          data: {'rel': 'mock'},
          style: GraphComponentStyle(
            color: Colors.black.withValues(alpha: 0.2),
          ),
        ),
      );
    }
  }

  return nodes;
}
