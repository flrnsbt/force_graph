// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:force_graph/src/graph_builder/data.dart';
import 'package:force_graph/src/graph_builder/distance.dart';
import 'package:force_graph/src/graph_builder/spring_embedder.dart';
import 'package:isolate_manager/isolate_manager.dart';

import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';
import 'package:forge2d/forge2d.dart';

class DistanceGraphBuilder extends ForceDirectedGraphBuilder {
  late double _tolerance;

  double get tolerance => _tolerance;

  set tolerance(double value) {
    assert(value > 0);
    _tolerance = value;
    parametersChanged();
  }

  DistanceGraphBuilder({
    super.minDistance,
    super.maxDistance,
    double tolerance = 1e-3,

    super.debugLogs,
  }) {
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

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeDataMap> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
    Map<String, Point<double>>? positionsToPreserve,
  ]) async {
    final inputData = <String, dynamic>{
      'nodes': nodes,
      'tolerance': tolerance,
      'minDistance': minDistance,
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
  double? get repulsion => _repulsion;
  double? get attraction => _attraction;
  int get correctionIterations => _correctionIterations;
  double get correctionFactor => _correctionFactor;

  set iterations(int value) {
    assert(value > 0, 'iterations > 0');
    _iterations = value;
    parametersChanged();
  }

  set repulsion(double? value) {
    if (value != null) {
      assert(value > 0, 'repulsion > 0');
      assert(
        _attraction == null || value > _attraction!,
        'repulsion must be greater than attraction',
      );
    }
    _repulsion = value;
    parametersChanged();
  }

  set attraction(double? value) {
    if (value != null) {
      assert(value > 0, 'attraction > 0');
      assert(
        _repulsion == null || value < _repulsion!,
        'attraction must be less than repulsion',
      );
    }
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
    double? repulsion,
    double? attraction,
    int correctionIterations = 0,
    double correctionFactor = 0.01,
    super.debugLogs,
    super.maxDistance,
    super.minDistance,
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
    Iterable<ForceGraphNodeDataMap> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
    Map<String, Point<double>>? positionsToPreserve,
  ]) async {
    final inputData = <String, dynamic>{
      'nodes': nodes,
      'width': size.width,
      'height': size.height,
      'iterations': iterations,
      'repulsion': repulsion ?? -1,
      'attraction': attraction ?? -1,
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

class HierarchicalGraphBuilder extends ForceDirectedGraphBuilder {
  /// Horizontal spacing between nodes in the same level
  final double horizontalSpacing;

  /// Vertical spacing between hierarchy levels
  final double verticalSpacing;

  /// Maximum number of nodes per level
  final int? maxNodesPerLevel;

  HierarchicalGraphBuilder({
    this.horizontalSpacing = 100,
    this.verticalSpacing = 100,
    this.maxNodesPerLevel,
    super.debugLogs,
    super.minDistance,
    super.maxDistance,
  });

  @override
  Future<void> $_performLayout(
    Iterable<ForceGraphNodeDataMap> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
    Map<String, Point<double>>? positionsToPreserve,
  ]) async {
    // Convert list to ForceGraphNodeData-like map (id + edges)
    final nodeList = nodes.toList();

    // Compute degree of each node
    final degreeMap = <String, int>{};
    for (final node in nodeList) {
      final edges = node['edges'] as List;
      degreeMap[node['id']] = edges.length;
    }

    // Sort nodes by degree descending (most connected first)
    nodeList.sort(
      (a, b) => (degreeMap[b['id']] ?? 0).compareTo(degreeMap[a['id']] ?? 0),
    );

    // Determine number of levels
    int totalNodes = nodeList.length;
    int levelCount = max(1, sqrt(totalNodes).round());

    // Assign nodes to levels (top-heavy)
    final levels = <int, List<Map>>{};
    for (int i = 0; i < totalNodes; i++) {
      int level = (i / (totalNodes / levelCount)).floor();
      levels.putIfAbsent(level, () => []).add(nodeList[i]);
    }

    // Layout parameters
    double startY = size.height / 2 - (levels.length - 1) * verticalSpacing / 2;

    _positions.clear();
    int processed = 0;
final double verticalVariation =
        verticalSpacing * 0.05; // how strong the zigzag is

    // Assign positions
    for (int l = 0; l < levels.length; l++) {
      final nodesAtLevel = levels[l]!;
      final levelY = startY + l * verticalSpacing;
      final levelWidth = (nodesAtLevel.length - 1) * horizontalSpacing;
      final startX = size.width / 2 - levelWidth / 2;

      for (int i = 0; i < nodesAtLevel.length; i++) {
        final node = nodesAtLevel[i];
        final x = startX + i * horizontalSpacing;
        // Alternate above and below the baseline
        final isEven = i.isEven;
        final y = levelY + (isEven ? -verticalVariation : verticalVariation);

        _positions[node['id']] = Point(x, y);
        processed++;
        progressCallback?.call(((processed / totalNodes) * 100).round());
      }
    }

    // Final progress signal
    progressCallback?.call(100);
  }
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

  //TODO: implement
  bool ensureReady(double dt, ForceGraphController controller) => true;


  double? _minDistance;
  double? _maxDistance;
  double get minDistance => _minDistance!;
  double get maxDistance => _maxDistance!;
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

  int? get totalStep => null;

  final bool debugLogs;

  Size? _size;

  bool _parametersChanged = false;

  void parametersChanged() {
    _parametersChanged = true;
  }

  ForceDirectedGraphBuilder({
    this.debugLogs = false,
    double? minDistance,
    double? maxDistance,
  }) {
    if (minDistance != null) {
      this.minDistance = minDistance;
    }

    if (maxDistance != null) {
      this.maxDistance = maxDistance;
    }
  }

  IsolateManager? _isolate;

  IsolateManager get isolate => _isolate ??= createIsolate();

  bool get hasMinDistance => _minDistance != null;

  IsolateManager createIsolate() => throw UnimplementedError();

  FutureOr<void> stop() async {
    await _isolate?.stop();
    _isolate = null;
  }

  Future<void> $_performLayout(
    Iterable<ForceGraphNodeDataMap> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
    Map<String, Point<double>>? positionsToPreserve,
  ]);

  double _calculateMaxDistance(
    double minDistance,
    int nodeCount,
    double width,
    double height,
  ) {
    double baseDistance = minDistance * (1 + 0.5 * sqrt(nodeCount));
    double maxAllowed = min(width, height) * 0.3;
    return min(baseDistance, maxAllowed);
  }

  Future<void> performLayout(
    Iterable<ForceGraphNodeData> nodes,
    Size size, [
    ValueChanged<int>? progressCallback,
  ]) async {
    try {
      _clear();
      _nodes.addAll(nodes);
      _maxDistance ??= _calculateMaxDistance(
        minDistance,
        nodes.length,
        size.width,
        size.height,
      );

      await $_performLayout(_nodesToMap(nodes), size, progressCallback);
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
    if (nodes.isEmpty) {
      return Future.value();
    }
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
    return $_performLayout(
      _nodesToMap(nodes),
      size,
      progressCallback,
      positionsToPreserve,
    );
  }

  void _clear() {
    _positions.clear();
    edges.clear();
    _nodes.clear();
  }

  Map<ForceGraphNodeData, Vector2> getNodes() {
    final result = <ForceGraphNodeData, Vector2>{};
    for (final node in _nodes) {
      final position = _positions[node.iD];
      if (position == null) {
        throw Exception('No position found for node ${node.iD}');
      }
      result[node] = position.toVector2();
    }
    return UnmodifiableMapView(result);
  }

  // double _similarityToDistance(double sim) {
  //   sim = sim.clamp(0.0, 1.0);
  //   final distance =
  //       minDistance + (maxDistance - minDistance) * pow(1.0 - sim, 2.0);
  //   return distance;
  // }

  double _similarityToDistance(double sim) {
    sim = sim.clamp(0.0, 1.0);
    const double logBase = 5.0;
    final normalized = 1.0 - (log(1.0 + sim * (logBase - 1.0)) / log(logBase));
    return minDistance + (maxDistance - minDistance) * normalized;
  }

  ForceGraphEdgeDataMap _edgeToMap(ForceGraphEdgeData edge) {
    return {
      'source': edge.source,
      'target': edge.target,
      'distance': _similarityToDistance(edge.similarity),
    };
  }

  List<ForceGraphNodeDataMap> _nodesToMap(Iterable<ForceGraphNodeData> nodes) {
    final nodesJSON = <Map>[];
    for (final node in nodes) {
      final edgesJSON = <Map>[];
      for (final edge in node.edges) {
        edges.add(edge);
        edgesJSON.add(_edgeToMap(edge));
      }
      nodesJSON.add({'id': node.iD, 'edges': edgesJSON});
    }
    return nodesJSON;
  }
}

extension on Point<double> {
  Vector2 toVector2() {
    return Vector2(x, y);
  }
}
