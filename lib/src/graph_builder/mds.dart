import 'dart:math';
import 'package:force_graph/src/graph_builder/data.dart';

import 'package:isolate_manager/isolate_manager.dart';

@pragma('vm:entry-point')
@isolateManagerCustomWorker
void performMDSLayoutIsolate(dynamic input) {
  IsolateManagerFunction.customFunction<ImMap, ImMap>(
    input,

    onEvent: (controller, ImMap input) {
      final unwrappedInput = input.toUnwrappedMap();
      final width = unwrappedInput['width'] as double;
      final height = unwrappedInput['height'] as double;
      final rawNodes = unwrappedInput['nodes'];

      final useHybrid = unwrappedInput['useHybrid'] as bool? ?? false;
      final forceIterations = unwrappedInput['iterations'] as int;
      final repulsion = unwrappedInput['repulsion'] as double;
      final attraction = unwrappedInput['attraction'] as double;

      final nodeList = <ForceGraphNodeDataMap>[];
      final nodeIds = <String>[];
      final edges = <ForceGraphEdgeDataMap>[];

      if (rawNodes is Iterable) {
        for (final n in rawNodes) {
          final node = ForceGraphNodeDataMap.from(n);
          nodeList.add(node);
          nodeIds.add(node.id);
          edges.addAll(node.edges);
        }
      }

      double similarityToDistance(num similarity) {
        const minDist = 0.5;
        const maxDist = 25;
        similarity = similarity.clamp(0.0001, 1.0);
        return maxDist - similarity * (maxDist - minDist);
      }

      final n = nodeIds.length;
      final distances = List.generate(n, (_) => List.filled(n, 0.0));

      for (final edge in edges) {
        final sourceIdx = nodeIds.indexOf(edge.source);
        final targetIdx = nodeIds.indexOf(edge.target);

        if (sourceIdx != -1 && targetIdx != -1) {
          final distance = similarityToDistance(edge.similarity);
          distances[sourceIdx][targetIdx] = distance;
          distances[targetIdx][sourceIdx] = distance;
        }
      }

      controller.sendResult(ImMap.wrap({'progress': 10}));

      _fillMissingDistances(distances, nodeIds);

      controller.sendResult(ImMap.wrap({'progress': 30}));

      final mdsPositions = _classicalMDS(distances, nodeIds, width, height);

      controller.sendResult(ImMap.wrap({'progress': 60}));

      Map<String, Point> finalPositions;

      if (useHybrid) {
        finalPositions = _refineWithForces(
          nodeList,
          mdsPositions,
          forceIterations,
          width,
          height,
          repulsion,
          attraction,
          similarityToDistance,
          controller,
        );
      } else {
        finalPositions = mdsPositions.map(
          (id, pos) => MapEntry(id, Point(pos.x, pos.y)),
        );
      }

      return ImMap.wrap({
        'positions': {
          for (final e in finalPositions.entries)
            e.key: {'x': e.value.x, 'y': e.value.y},
        },
        'final': true,
      });
    },
  );
}

void _fillMissingDistances(List<List<double>> distances, List<String> nodeIds) {
  final n = nodeIds.length;

  // Floyd-Warshall for shortest paths
  for (int k = 0; k < n; k++) {
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i != j && distances[i][j] == 0.0) {
          if (distances[i][k] > 0 && distances[k][j] > 0) {
            final pathDistance = distances[i][k] + distances[k][j];
            if (distances[i][j] == 0.0 || pathDistance < distances[i][j]) {
              distances[i][j] = pathDistance;
            }
          }
        }
      }
    }
  }

  // Fill remaining with large default distance
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      if (i != j && distances[i][j] == 0.0) {
        distances[i][j] = 50.0; // Large default distance
      }
    }
  }
}

Map<String, Point> _classicalMDS(
  List<List<double>> distances,
  List<String> nodeIds,
  double width,
  double height,
) {
  final n = nodeIds.length;

  if (n < 2) {
    // Handle edge case
    final positions = <String, Point>{};
    for (int i = 0; i < nodeIds.length; i++) {
      positions[nodeIds[i]] = Point(width / 2, height / 2);
    }
    return positions;
  }

  // Create squared distance matrix
  final D = List.generate(
    n,
    (i) => List.generate(n, (j) => distances[i][j] * distances[i][j]),
  );

  // Double centering
  // Calculate row means
  final rowMeans = List.generate(n, (i) => D[i].reduce((a, b) => a + b) / n);

  // Calculate grand mean
  final grandMean = rowMeans.reduce((a, b) => a + b) / n;

  // Create centered matrix B
  final B = List.generate(
    n,
    (i) => List.generate(
      n,
      (j) => -0.5 * (D[i][j] - rowMeans[i] - rowMeans[j] + grandMean),
    ),
  );

  // Extract top 2 eigenvectors using power method
  final coords = _extractTopEigenVectors(B, 2);

  // Convert to positions and scale
  final positions = <String, Point>{};
  for (int i = 0; i < nodeIds.length; i++) {
    positions[nodeIds[i]] = Point(coords[i][0], coords[i][1]);
  }

  return _scaleAndCenter(positions, width, height);
}

List<List<double>> _extractTopEigenVectors(
  List<List<double>> matrix,
  int numVectors,
) {
  final n = matrix.length;
  final vectors = <List<double>>[];
  final List<List<double>> workingMatrix = List.generate(
    n,
    (i) => List.from(matrix[i]),
  );

  for (int v = 0; v < numVectors; v++) {
    var x = List.generate(n, (_) => Random().nextDouble() - 0.5);

    for (int iter = 0; iter < 100; iter++) {
      final newX = List.filled(n, 0.0);
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          newX[i] += workingMatrix[i][j] * x[j];
        }
      }

      final norm = sqrt(newX.fold(0.0, (sum, val) => sum + val * val));
      if (norm > 0) {
        for (int i = 0; i < n; i++) {
          newX[i] /= norm;
        }
      }

      x = newX;
    }

    vectors.add(x);

    final eigenValue = _computeEigenValue(workingMatrix, x);
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        workingMatrix[i][j] -= eigenValue * x[i] * x[j];
      }
    }
  }

  return List.generate(
    n,
    (i) => List.generate(numVectors, (j) => vectors[j][i]),
  );
}

double _computeEigenValue(List<List<double>> matrix, List<double> vector) {
  double numerator = 0.0;
  double denominator = 0.0;

  for (int i = 0; i < matrix.length; i++) {
    double matrixVectorProduct = 0.0;
    for (int j = 0; j < matrix[i].length; j++) {
      matrixVectorProduct += matrix[i][j] * vector[j];
    }
    numerator += vector[i] * matrixVectorProduct;
    denominator += vector[i] * vector[i];
  }

  return denominator != 0 ? numerator / denominator : 0.0;
}

Map<String, Point> _scaleAndCenter(
  Map<String, Point> positions,
  double width,
  double height,
) {
  if (positions.isEmpty) return positions;

  num minX = double.infinity, maxX = double.negativeInfinity;
  num minY = double.infinity, maxY = double.negativeInfinity;

  for (final pos in positions.values) {
    minX = min(minX, pos.x);
    maxX = max(maxX, pos.x);
    minY = min(minY, pos.y);
    maxY = max(maxY, pos.y);
  }

  final padding = 100.0;
  final rangeX = maxX - minX;
  final rangeY = maxY - minY;
  final scaleX = rangeX > 0 ? (width - padding) / rangeX : 1.0;
  final scaleY = rangeY > 0 ? (height - padding) / rangeY : 1.0;
  final scale = min(scaleX, scaleY);

  final centerX = width / 2;
  final centerY = height / 2;
  final offsetX = (minX + maxX) / 2;
  final offsetY = (minY + maxY) / 2;

  final result = <String, Point>{};
  for (final entry in positions.entries) {
    result[entry.key] = Point(
      centerX + (entry.value.x - offsetX) * scale,
      centerY + (entry.value.y - offsetY) * scale,
    );
  }

  return result;
}

Map<String, Point> _refineWithForces(
  List<ForceGraphNodeDataMap> nodeList,
  Map<String, Point> initialPositions,
  int iterations,
  double width,
  double height,
  double repulsion,
  double attraction,
  double Function(num) similarityToDistance,
  controller,
) {
  final positions = <String, Point>{};
  final velocities = <String, Point>{};

  for (final entry in initialPositions.entries) {
    positions[entry.key] = Point(entry.value.x, entry.value.y);
    velocities[entry.key] = const Point(0, 0);
  }

  final edges = <ForceGraphEdgeDataMap>[];
  for (final node in nodeList) {
    edges.addAll(node.edges);
  }

  final baseProgress = 60;
  final progressRange = 40;

  for (int i = 0; i < iterations; i++) {
    final disp = <String, Point<double>>{};

    for (final key in positions.keys) {
      disp[key] = const Point(0, 0);
    }

    for (var v in positions.entries) {
      for (var u in positions.entries) {
        if (v.key == u.key) continue;

        var dx = v.value.x - u.value.x;
        var dy = v.value.y - u.value.y;
        var dist = sqrt(dx * dx + dy * dy) + 0.01;

        if (dist < 30) {
          var force = repulsion * 0.1 / (dist * dist);

          disp[v.key] = Point(
            disp[v.key]!.x + dx / dist * force,
            disp[v.key]!.y + dy / dist * force,
          );
        }
      }
    }

    for (final edge in edges) {
      final sourceID = edge.source;
      final targetID = edge.target;

      if (positions.containsKey(sourceID) && positions.containsKey(targetID)) {
        final source = positions[sourceID];
        final target = positions[targetID];

        if (source == null || target == null) continue;

        var dx = source.x - target.x;
        var dy = source.y - target.y;
        var dist = sqrt(dx * dx + dy * dy) + 0.01;
        final edgeLength = similarityToDistance(edge.similarity);
        var force = attraction * (dist - edgeLength);

        var fx = dx / dist * force;
        var fy = dy / dist * force;

        disp[sourceID] = Point(disp[sourceID]!.x - fx, disp[sourceID]!.y - fy);
        disp[targetID] = Point(disp[targetID]!.x + fx, disp[targetID]!.y + fy);
      }
    }

    for (final e in positions.entries) {
      final node = e.value;
      final id = e.key;
      final dampedDisp = Point(disp[id]!.x * 0.1, disp[id]!.y * 0.1);

      final newPos = Point(node.x + dampedDisp.x, node.y + dampedDisp.y);

      positions[id] = Point(
        max(50, min(width - 50, newPos.x)),
        max(50, min(height - 50, newPos.y)),
      );
    }

    if (i % 10 == 0) {
      final progress = baseProgress + (i / iterations * progressRange).round();
      controller.sendResult(ImMap.wrap({'progress': progress}));
    }
  }

  return positions;
}
