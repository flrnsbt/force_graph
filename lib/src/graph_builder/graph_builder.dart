// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'package:force_graph/src/graph_builder/distance.dart';
import 'package:force_graph/src/graph_builder/mds.dart';
import 'package:force_graph/src/graph_builder/spring_embedder.dart';
import 'package:isolate_manager/isolate_manager.dart';

import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';
import 'package:forge2d/forge2d.dart';

class DistanceGraphBuilder extends ForceDirectedGraphBuilder {
  double minDistance;
  double maxDistance;
  double tolerance;
  DistanceGraphBuilder({
    required this.minDistance,
    required this.maxDistance,
    this.tolerance = 1e-3,

    super.debugLogs,
  }) : assert(minDistance < maxDistance, 'minDistance < maxDistance'),
       assert(minDistance > 0, 'minDistance > 0');

  @override
  IsolateManager createIsolate() {
    return IsolateManager.createCustom(
      performDistanceLayoutIsolate,
      isDebug: debugLogs,
      converter: (value) {
        if (value is ImType) {
          return value.unwrap;
        }
        return value;
      },
      workerName:
          'assets/packages/force_graph/web/performDistanceLayoutIsolate',
    );
  }

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
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
    final inputData = <String, dynamic>{
      'nodes': nodesJSON,
      'minDistance': minDistance,
      'maxDistance': maxDistance,
      'tolerance': tolerance,
    };

    final Map result = await isolate.compute(
      ImMap.wrap(inputData),
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
  }
}

class SpringEmbedderGraphBuilder extends ForceDirectedGraphBuilder {
  int iterations;
  double repulsion;
  double attraction;
  int correctionIterations;
  double correctionFactor;
  SpringEmbedderGraphBuilder({
    this.iterations = 800,
    required this.repulsion,
    required this.attraction,
    this.correctionIterations = 300,
    this.correctionFactor = 0.5,
    super.debugLogs,
  }) : assert(iterations > 0, 'iterations must be greater than 0'),
       assert(repulsion > 0, 'repulsion must be greater than 0'),
       assert(attraction > 0, 'attraction must be greater than 0'),
       assert(
         repulsion > attraction,
         'repulsion must be greater than attraction',
       );

  @override
  IsolateManager createIsolate() {
    return IsolateManager.createCustom(
      performSpringEmbedderLayoutIsolate,
      isDebug: debugLogs,
      converter: (value) {
        if (value is ImType) {
          return value.unwrap;
        }
        return value;
      },
      workerName:
          'assets/packages/force_graph/web/performSpringEmbedderLayoutIsolate',
    );
  }

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
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
    final inputData = <String, dynamic>{
      'nodes': nodesJSON,
      'width': size.width,
      'height': size.height,
      'iterations': iterations,
      'repulsion': repulsion,
      'attraction': attraction,
      'correctionIterations': correctionIterations,
      'correctionFactor': correctionFactor
    };

    final Map result = await isolate.compute(
      ImMap.wrap(inputData),
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
  }

  @override
  int? get totalStep => iterations + correctionIterations;
}

class MDSGraphBuilder extends ForceDirectedGraphBuilder {
  int iterations;
  double repulsion;
  double attraction;
  MDSGraphBuilder({
    required this.iterations,
    required this.repulsion,
    required this.attraction,
    super.debugLogs,
  }) : assert(iterations > 0, 'iterations must be greater than 0'),
       assert(repulsion > 0, 'repulsion must be greater than 0'),
       assert(attraction > 0, 'attraction must be greater than 0'),
       assert(
         repulsion > attraction,
         'repulsion must be greater than attraction',
       );

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
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
    final inputData = <String, dynamic>{
      'nodes': nodesJSON,
      'width': size.width,
      'height': size.height,
      'iterations': iterations,
      'repulsion': repulsion,
      'attraction': attraction,
    };

    final Map result = await isolate.compute(
      ImMap.wrap(inputData),
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
  }

  @override
  IsolateManager createIsolate() {
    return IsolateManager.createCustom(
      performMDSLayoutIsolate,
      isDebug: debugLogs,
      converter: (value) {
        if (value is ImType) {
          return value.unwrap;
        }
        return value;
      },
      workerName: 'assets/packages/force_graph/web/performMDSLayoutIsolate',
    );
  }

  @override
  int? get totalStep => iterations;
}

abstract class ForceDirectedGraphBuilder {
  final Map<String, Vector2> _positions = {};
  final List<ForceGraphEdgeData> edges = [];
  final List<ForceGraphNodeData> _nodes = [];

  int? get totalStep => null;

  final bool debugLogs;

  ForceDirectedGraphBuilder({this.debugLogs = false});

  IsolateManager? _isolate;

  IsolateManager get isolate => _isolate ??= createIsolate();

  IsolateManager createIsolate();

  FutureOr<void> stop() async {
    await _isolate?.stop();
    _isolate = null;
  }

  bool ensureReady(double dt, ForceGraphController controller) => true;

  Future<void> $_performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]);

  Future<void> performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
    _positions.clear();
    edges.clear();
    _nodes.clear();
    _nodes.addAll(nodes);
    try {
      await $_performLayout(nodes, size, progressCallback);
    } catch (e) {
      debugPrint('Error during layout: $e');
    } finally {
      await stop();
    }
  }

  Map<ForceGraphNodeData, Vector2> get nodes {
    final result = <ForceGraphNodeData, Vector2>{};
    for (final node in _nodes) {
      result[node] = _positions[node.id]!;
    }
    return UnmodifiableMapView(result);
  }
}
