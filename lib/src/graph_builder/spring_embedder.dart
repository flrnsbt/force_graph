import 'dart:math';

import 'package:force_graph/src/graph_builder/data.dart';
import 'package:isolate_manager/isolate_manager.dart';

@pragma('vm:entry-point')
@isolateManagerCustomWorker
void performSpringEmbedderLayoutIsolate(dynamic input) {
  IsolateManagerFunction.customFunction<ImMap, ImMap>(
    input,
    onEvent: (controller, ImMap input) {
      final unwrappedInput = input.toUnwrappedMap();
      final iterations = unwrappedInput['iterations'] as int;
      double? repulsion = unwrappedInput['repulsion'] as double?;
      double? attraction = unwrappedInput['attraction'] as double?;
      if (repulsion == -1) repulsion = null;
      if (attraction == -1) attraction = null;
      final width = unwrappedInput['width'] as double;
      final height = unwrappedInput['height'] as double;
      final positions = <String, Point<double>>{};
      final edges = <ForceGraphEdgeDataMap>{};
      final rand = Random();
      final rawNodes = unwrappedInput['nodes'];
      final rawPreserved =
          unwrappedInput['positionsToPreserve'] as Map<String, dynamic>? ?? {};
      final int correctionIterations =
          unwrappedInput['correctionIterations'] as int;
      final correctionFactor = unwrappedInput['correctionFactor'] as double;

      // Safety constants - scale with canvas size
      const double minDistance = 0.01;
      final double canvasSize = sqrt(width * height);
      final double maxForce = canvasSize * 0.1;

      // Temperature-based cooling parameters
      final double initialTemperature = min(width, height) * 0.01;
      final double finalTemperature = 0.1;

      final double repulsionFalloff = 3.0; // How quickly repulsion falls off

      // Calculate node degrees for edge weighting
      Map<String, int> calculateNodeDegrees() {
        final degrees = <String, int>{};
        for (final nodeId in positions.keys) {
          degrees[nodeId] = 0;
        }
        for (final edge in edges) {
          degrees[edge.source] = (degrees[edge.source] ?? 0) + 1;
          degrees[edge.target] = (degrees[edge.target] ?? 0) + 1;
        }
        return degrees;
      }

      // Check if two nodes are connected by an edge
      bool areConnected(String nodeA, String nodeB) {
        return edges.any(
          (edge) =>
              (edge.source == nodeA && edge.target == nodeB) ||
              (edge.source == nodeB && edge.target == nodeA),
        );
      }

      // Temperature function - exponential cooling
      double getTemperature(int iteration, int totalIterations) {
        if (totalIterations <= 1) return initialTemperature;

        final progress = iteration / (totalIterations - 1);
        // Exponential cooling: fast initial cooling, then slower
        return initialTemperature *
            pow(finalTemperature / initialTemperature, progress);
      }

      // // Alternative linear cooling (smoother but slower)
      // double getLinearTemperature(int iteration, int totalIterations) {
      //   if (totalIterations <= 1) return initialTemperature;

      //   final progress = iteration / (totalIterations - 1);
      //   return initialTemperature * (1.0 - progress) +
      //       finalTemperature * progress;
      // }

      // Helper function to safely calculate distance
      double safeDistance(double dx, double dy) {
        final dist = sqrt(dx * dx + dy * dy);
        return max(dist, minDistance);
      }

      // Helper function to limit force magnitude with temperature
      Point<double> limitForce(double fx, double fy, double temperature) {
        final magnitude = sqrt(fx * fx + fy * fy);
        final tempAdjustedMaxForce =
            maxForce * max(0.1, temperature / initialTemperature);

        if (magnitude > tempAdjustedMaxForce) {
          final scale = tempAdjustedMaxForce / magnitude;
          return Point(fx * scale, fy * scale);
        }
        return Point(fx, fy);
      }

      // Helper function to keep nodes within reasonable bounds
      Point<double> keepInBounds(Point<double> pos) {
        final margin = canvasSize * 0.05; // 5% margin
        return Point(
          pos.x.clamp(margin, width - margin),
          pos.y.clamp(margin, height - margin),
        );
      }

      // Helper function to validate and fix position
      Point<double> validatePosition(Point<double> pos) {
        double x = pos.x;
        double y = pos.y;

        // Check for NaN or infinite values
        if (x.isNaN || x.isInfinite) {
          x = width / 2 + (rand.nextDouble() - 0.5) * canvasSize * 0.1;
        }
        if (y.isNaN || y.isInfinite) {
          y = height / 2 + (rand.nextDouble() - 0.5) * canvasSize * 0.1;
        }

        return keepInBounds(Point(x, y));
      }

      void correctEdgeDistances(
        Map<String, Point<double>> positions,
        Set<ForceGraphEdgeDataMap> edges,
      ) {
        for (int i = 0; i < correctionIterations; i++) {
          for (final edge in edges) {
            final a = positions[edge.source]!;
            final b = positions[edge.target]!;

            final dx = b.x - a.x;
            final dy = b.y - a.y;
            final dist = safeDistance(dx, dy);

            // Skip if distance is effectively zero
            if (dist <= minDistance) continue;

            final distance = edge.distance;
            final diff = distance - dist;
            final ratio = (diff / dist) * correctionFactor;

            // Limit the correction ratio to prevent instability
            final limitedRatio = ratio.clamp(-0.2, 0.2);

            final offsetX = dx * limitedRatio / 2;
            final offsetY = dy * limitedRatio / 2;

            // Validate positions before updating
            positions[edge.source] = validatePosition(
              Point(a.x - offsetX, a.y - offsetY),
            );
            positions[edge.target] = validatePosition(
              Point(b.x + offsetX, b.y + offsetY),
            );
          }
          controller.sendResult(ImMap.wrap({'progress': i + iterations}));
        }
      }

      if (rawPreserved.isNotEmpty) {
        for (final entry in rawPreserved.entries) {
          final point = entry.value as Map<String, dynamic>;
          positions[entry.key] = validatePosition(
            Point<double>(point['x'] as double, point['y'] as double),
          );
        }
      }

      // Collect all node IDs first
      final nodeIds = <String>[];

      if (rawNodes is Iterable) {
        for (final n in rawNodes) {
          final node = ForceGraphNodeDataMap.from(n);
          nodeIds.add(node.id);
          for (final edge in node.edges) {
            edges.add(edge);
          }
        }
      }

      repulsion ??= canvasSize / nodeIds.length * 0.05;
      attraction ??= canvasSize / nodeIds.length * 0.5;

      // Initialize positions using circular layout (better than random)
      // Initialize positions using circular layout (better than random)
      void initializeCircularLayout(
        Map<String, Point<double>> positions,
        List<String> nodeIds,
      ) {
        final center = Point(width / 2, height / 2);
        final radius = min(width, height) * 0.1;

        for (int i = 0; i < nodeIds.length; i++) {
          final angle = 2 * pi * i / nodeIds.length;
          positions.putIfAbsent(
            nodeIds[i],
            () => Point(
              center.x + radius * cos(angle),
              center.y + radius * sin(angle),
            ),
          );
        }
      }

      initializeCircularLayout(positions, nodeIds);

      for (int i = 0; i < iterations; i++) {
        // Calculate current temperature
        final temperature = getTemperature(i, iterations);
        final nodeDegrees = calculateNodeDegrees();

        final disp = <String, Point<double>>{};

        // Initialize displacement vectors
        for (final key in positions.keys) {
          disp[key] = const Point(0, 0);
        }

        // Calculate repulsive forces between all pairs
        for (var v in positions.entries) {
          for (var u in positions.entries) {
            if (v.key == u.key) continue;

            var dx = v.value.x - u.value.x;
            var dy = v.value.y - u.value.y;
            var dist = safeDistance(dx, dy);

            // Skip if nodes are too close (prevent infinite forces)
            if (dist <= minDistance) {
              // Add small random displacement to separate overlapping nodes
              // Scale random displacement with temperature
              final randomScale = temperature / initialTemperature;
              dx = (rand.nextDouble() - 0.5) * 0.1 * randomScale;
              dy = (rand.nextDouble() - 0.5) * 0.1 * randomScale;
              dist = safeDistance(dx, dy);
            }

            // Reduce repulsion between connected nodes
            double repulsionMultiplier = 1.0;
            if (areConnected(v.key, u.key)) {
              repulsionMultiplier = 0.15;
            }

            // Distance-based repulsion falloff (more realistic)
            var force =
                (repulsion * repulsionMultiplier) / pow(dist, repulsionFalloff);

            // Apply temperature-aware force limits
            final limitedForce = limitForce(
              (dx / dist) * force,
              (dy / dist) * force,
              temperature,
            );

            disp[v.key] = Point(
              disp[v.key]!.x + limitedForce.x,
              disp[v.key]!.y + limitedForce.y,
            );
            disp[u.key] = Point(
              disp[u.key]!.x - limitedForce.x,
              disp[u.key]!.y - limitedForce.y,
            );
          }
        }

        // Calculate attractive forces for edges with adaptive strength
        for (final edge in edges) {
          final sourceID = edge.source;
          final targetID = edge.target;
          final source = positions[sourceID];
          final target = positions[targetID];
          if (source == null) {
            throw "Invalid Edge: couldn't find node $sourceID";
          }
          if (target == null) {
            throw "Invalid Edge: couldn't find node $targetID";
          }

          var dx = source.x - target.x;
          var dy = source.y - target.y;
          var dist = safeDistance(dx, dy);

          // Skip if nodes are too close
          if (dist <= minDistance) {
            continue;
          }

          // Adaptive attraction based on current distance and desired distance
          final desiredDistance = edge.distance;
          final distanceRatio = dist / desiredDistance;

          // Stronger attraction for nodes that are too far apart
          double attractionMultiplier = 1.0;
          if (distanceRatio > 2.0) {
            attractionMultiplier = min(5.0, distanceRatio);
          }

          // Consider node degrees - high degree nodes get stronger attraction
          final sourceDegree = nodeDegrees[sourceID] ?? 1;
          final targetDegree = nodeDegrees[targetID] ?? 1;
          final degreeMultiplier = 1.0 + (sourceDegree + targetDegree) * 0.1;

          final finalAttraction =
              attraction * attractionMultiplier * degreeMultiplier;
          var force = (finalAttraction) * (dist - desiredDistance);

          var fx = dx / dist * force;
          var fy = dy / dist * force;

          // Apply temperature-aware force limits
          final limitedForce = limitForce(fx, fy, temperature);

          disp[sourceID] = Point(
            disp[sourceID]!.x - limitedForce.x,
            disp[sourceID]!.y - limitedForce.y,
          );
          disp[targetID] = Point(
            disp[targetID]!.x + limitedForce.x,
            disp[targetID]!.y + limitedForce.y,
          );
        }

        // Update positions with temperature-based movement
        for (final e in positions.entries) {
          final node = e.value;
          final id = e.key;
          final displacement = disp[id]!;

          // Validate displacement
          if (displacement.x.isNaN ||
              displacement.x.isInfinite ||
              displacement.y.isNaN ||
              displacement.y.isInfinite) {
            // Skip this update if displacement is invalid
            continue;
          }

          // Apply temperature-based movement scaling
          final movementScale = temperature / initialTemperature;
          final tempAdjustedDisp = Point(
            displacement.x * movementScale,
            displacement.y * movementScale,
          );

          positions[id] = validatePosition(
            Point(node.x + tempAdjustedDisp.x, node.y + tempAdjustedDisp.y),
          );
        }

        controller.sendResult(ImMap.wrap({'progress': i}));
      }

      correctEdgeDistances(positions, edges);

      return ImMap.wrap({
        'positions': {
          for (final e in positions.entries) e.key: e.value.toMap(),
        },
        'final': true,
      });
    },
  );
}
