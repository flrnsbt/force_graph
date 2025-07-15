import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:force_graph/src/graph_builder/mds.dart';
import 'package:force_graph/src/graph_builder/spring_embedder.dart';
import 'package:isolate_manager/isolate_manager.dart';

import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';
import 'package:forge2d/forge2d.dart';

class ForceDirectedGraphBuilder {
  final Map<String, Vector2> _positions = {};
  final List<ForceGraphEdgeData> edges = [];
  final List<ForceGraphNodeData> _nodes = [];
  int iterations;
  double repulsion;
  double attraction;

  final bool debugLogs;

  AlgorithmType algorithmType;

  ForceDirectedGraphBuilder({
    required this.iterations,
    required this.repulsion,
    required this.attraction,
    this.algorithmType = AlgorithmType.springEmbedder,
    this.debugLogs = false,
  });

  IsolateManager? _isolate;

  FutureOr<void> stop() async {
    await _isolate?.stop();
  }

  Future<void> performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
    _positions.clear();
    edges.clear();
    _nodes.clear();
    _nodes.addAll(nodes);
    final isolate = _isolate = algorithmType.createIsolate(debugLogs);
    try {
      final nodesJSON = <Map>[];
      for (final node in nodes) {
        final edgesJSON = <Map>[];
        for (final edge in node.edges) {
          edges.add(edge);
          edgesJSON.add({
            'source': edge.source,
            'target': edge.target,
            'similarity': edge.similarity,
          });
        }
        nodesJSON.add({'id': node.id, 'edges': edgesJSON});
      }
      final inputData = ImMap.wrap({
        'nodes': nodesJSON,
        'width': size.width,
        'height': size.height,
        'iterations': iterations,
        'repulsion': repulsion,
        'attraction': attraction,
      });
      final Map result = await isolate.compute(
        inputData,
        callback: (value) {
          if (value is Map) {
            if (value.containsKey('final')) {
              return true;
            }
            final progress = value['progress'];
            if (progress != null) {
              progressCallback?.call(progress);
              return false;
            }
          }
          return false;
        },
      );
      final positions = result['positions'] as Map;
      for (final e in positions.entries) {
        final iD = e.key as String;
        final value = e.value as Map;
        _positions[iD] = Vector2(value['x'], value['y']);
      }

      final minimumSpacing = result['minimumSpacing'] as double;
      if (minimumSpacing.isFinite) {
        this.minimumSpacing = minimumSpacing;
      }
    } catch (e) {
      debugPrint('error: $e');
      rethrow;
    } finally {
      await isolate.stop();
    }
  }

  Map<ForceGraphNodeData, Vector2> get nodes {
    final result = <ForceGraphNodeData, Vector2>{};
    for (final node in _nodes) {
      result[node] = _positions[node.id]!;
    }
    return UnmodifiableMapView(result);
  }

  double minimumSpacing = 5;
}

enum AlgorithmType {
  springEmbedder('performSpringEmbedderLayoutIsolate'),
  mds('performMDSLayoutIsolate');

  final String functionName;

  const AlgorithmType(this.functionName);

  IsolateManager createIsolate([bool enableDebugLogs = false]) {
    FutureOr<void> Function(dynamic) function;
    if (this == springEmbedder) {
      function = performSpringEmbedderLayoutIsolate;
    } else {
      function = performMDSLayoutIsolate;
    }
    return IsolateManager.createCustom(
      function,
      isDebug: enableDebugLogs,
      converter: (value) {
        if (value is ImType) {
          return value.unwrap;
        }
        return value;
      },
      workerName: 'assets/packages/force_graph/web/$functionName',
    );
  }
}
