// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:force_graph/src/graph_builder/data.dart';
import 'package:force_graph/src/graph_builder/distance.dart';
import 'package:force_graph/src/graph_builder/mds.dart';
import 'package:force_graph/src/graph_builder/spring_embedder.dart';
import 'package:isolate_manager/isolate_manager.dart';

import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';
import 'package:forge2d/forge2d.dart';

class DistanceGraphBuilder extends ForceDirectedGraphBuilder {
  double? _minDistance;
  double? _maxDistance;
  late double _tolerance;

  double get minDistance => _minDistance!;
  double get maxDistance => _maxDistance!;
  double get tolerance => _tolerance;

  set minDistance(double value) {
    assert(value > 0);
    assert(_maxDistance == null || value < _maxDistance!);
    _minDistance = value;
    parametersChanged();
  }

  set maxDistance(double value) {
    assert(_minDistance == null || value > _minDistance!);
    _maxDistance = value;
    parametersChanged();
  }

  set tolerance(double value) {
    assert(value > 0);
    _tolerance = value;
    parametersChanged();
  }

  DistanceGraphBuilder({
    required double minDistance,
    required double maxDistance,
    double tolerance = 1e-3,

    super.debugLogs,
  }) {
    this.minDistance = minDistance;
    this.maxDistance = maxDistance;
    this.tolerance = tolerance;
  }

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

  //TODO: implement
  @override
  bool ensureReady(double dt, ForceGraphController controller) => true;

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
    Map<String, Point<double>>? positionsToPreserve,
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
      if (positionsToPreserve != null)
        'positionsToPreserve': _jsonifyPoints(positionsToPreserve),
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
    _positions.addAll(_dartifyPoints(result['positions'] as Map));
  }
}

class SpringEmbedderGraphBuilder extends ForceDirectedGraphBuilder {
  late int _iterations;
  double? _repulsion;
  double? _attraction;
  late int _correctionIterations;
  late double _correctionFactor;

  int get iterations => _iterations;
  double get repulsion => _repulsion!;
  double get attraction => _attraction!;
  int get correctionIterations => _correctionIterations;
  double get correctionFactor => _correctionFactor;

  set iterations(int value) {
    assert(value > 0, 'iterations > 0');
    _iterations = value;
    parametersChanged();
  }

  set repulsion(double value) {
    assert(value > 0, 'repulsion > 0');
    assert(
      _attraction == null || value > _attraction!,
      'repulsion must be greater than attraction',
    );
    _repulsion = value;
    parametersChanged();
  }

  set attraction(double value) {
    assert(value > 0, 'attraction > 0');
    assert(
      _repulsion == null || value < _repulsion!,
      'attraction must be less than repulsion',
    );
    _attraction = value;
    parametersChanged();
  }

  set correctionIterations(int value) {
    _correctionIterations = value;
    parametersChanged();
  }

  set correctionFactor(double value) {
    assert(value > 0, 'correctionFactor > 0');
    _correctionFactor = value;
    parametersChanged();
  }

  SpringEmbedderGraphBuilder({
    int iterations = 800,
    required double repulsion,
    required double attraction,
    int correctionIterations = 300,
    double correctionFactor = 0.5,
    super.debugLogs,
  }) {
    this.iterations = iterations;
    this.repulsion = repulsion;
    this.attraction = attraction;
    this.correctionIterations = correctionIterations;
    this.correctionFactor = correctionFactor;
  }

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
    Map<String, Point<double>>? positionsToPreserve,
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
      'correctionFactor': correctionFactor,
      if (positionsToPreserve != null)
        'positionsToPreserve': _jsonifyPoints(positionsToPreserve),
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
    _positions.addAll(_dartifyPoints(result['positions'] as Map));
  }

  @override
  int? get totalStep => iterations + correctionIterations;
}

class MDSGraphBuilder extends ForceDirectedGraphBuilder {
  late int _iterations;
  double? _repulsion;
  double? _attraction;

  int get iterations => _iterations;
  double get repulsion => _repulsion!;
  double get attraction => _attraction!;

  set iterations(int value) {
    assert(value > 0, 'iterations must be greater than 0');
    _iterations = value;
    parametersChanged();
  }

  set repulsion(double value) {
    assert(value > 0, 'repulsion must be greater than 0');
    assert(
      _attraction == null || value > _attraction!,
      'repulsion must be greater than attraction',
    );
    _repulsion = value;
    parametersChanged();
  }

  set attraction(double value) {
    assert(value > 0, 'attraction must be greater than 0');
    assert(
      _repulsion == null || value > _repulsion!,
      'attraction must be greater than repulsion',
    );
    _attraction = value;
    parametersChanged();
  }

  MDSGraphBuilder({
    required int iterations,
    required double repulsion,
    required double attraction,
    super.debugLogs,
  }) {
    this.iterations = iterations;
    this.repulsion = repulsion;
    this.attraction = attraction;
  }

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
    Map<String, Point<double>>? positionsToPreserve,
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
      if (positionsToPreserve != null)
        'positionsToPreserve': _jsonifyPoints(positionsToPreserve),
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
    _positions.addAll(_dartifyPoints(result['positions'] as Map));
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

Map<String, Map<String, double>> _jsonifyPoints(
  Map<String, Point<double>> points,
) {
  final result = <String, Map<String, double>>{};
  for (final e in points.entries) {
    final iD = e.key;
    final value = e.value;
    result[iD] = value.toMap();
  }
  return result;
}

Map<String, Point<double>> _dartifyPoints(Map points) {
  final result = <String, Point<double>>{};
  for (final e in points.entries) {
    final iD = e.key as String;
    final value = e.value as Map;
    result[iD] = Point(value['x'], value['y']);
  }
  return result;
}

abstract class ForceDirectedGraphBuilder {
  final Map<String, Point<double>> _positions = {};
  final List<ForceGraphEdgeData> edges = [];
  final List<ForceGraphNodeData> _nodes = [];

  int? get totalStep => null;

  final bool debugLogs;

  Size? _size;

  bool _parametersChanged = false;

  void parametersChanged() {
    _parametersChanged = true;
  }

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
    Map<String, Point<double>>? positionsToPreserve,
  ]);

  Future<void> performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
    _clear();
    _nodes.addAll(nodes);
    try {
      await $_performLayout(nodes, size, progressCallback);
      _size = size;
      _parametersChanged = false;
    } catch (e) {
      debugPrint('Error during layout: $e');
    } finally {
      await stop();
    }
  }

  Future<void> loadMore(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) {
    if (_size != size) {
      _parametersChanged = true;
    }
    if (_parametersChanged) {
      return performLayout(nodes, size, progressCallback);
    }
    final positionsToPreserve = Map.of(_positions);
    _positions.clear();
    edges.clear();
    _nodes.addAll(nodes);
    return $_performLayout(nodes, size, progressCallback, positionsToPreserve);
  }

  void _clear() {
    _positions.clear();
    edges.clear();
    _nodes.clear();
  }

  Map<ForceGraphNodeData, Vector2> getNodes() {
    final result = <ForceGraphNodeData, Vector2>{};
    for (final node in _nodes) {
      result[node] = _positions[node.id]!.toVector2();
    }
    return UnmodifiableMapView(result);
  }
}

extension on Point<double> {
  Vector2 toVector2() {
    return Vector2(x, y);
  }
}
