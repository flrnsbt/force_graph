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
      final iterations = (unwrappedInput['iterations'] as num).toInt();
      double? repulsion = (unwrappedInput['repulsion'] as num?)?.toDouble();
      double? attraction = (unwrappedInput['attraction'] as num?)?.toDouble();
      if (repulsion == -1) repulsion = null;
      if (attraction == -1) attraction = null;
      final width = (unwrappedInput['width'] as num).toDouble();
      final height = (unwrappedInput['height'] as num).toDouble();
      final positions = <String, Point<double>>{};
      final edges = <ForceGraphEdgeDataMap>{};
      final rand = Random();
      final rawNodes = unwrappedInput['nodes'];
      final rawPreserved =
          unwrappedInput['positionsToPreserve'] as Map? ?? {};
      final int correctionIterations =
          (unwrappedInput['correctionIterations'] as num).toInt();
      final correctionFactor =
          (unwrappedInput['correctionFactor'] as num).toDouble();

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

      // Safety constants - scale with canvas size
      const double minSeparation = 0.5;
      final double canvasSize = sqrt(width * height);
      final int nodeCount = max(1, nodeIds.length);

      // Optimal distance between nodes (Fruchterman-Reingold)
      final double k = sqrt((width * height) / nodeCount) * 1.0;
      final double effectiveK = k.clamp(110.0, 350.0);

      // Temperature-based cooling parameters
      final double initialTemperature = min(width, height) * 0.12;
      final double finalTemperature = 0.5;



      // Temperature function - exponential cooling
      double getTemperature(int iteration, int totalIterations) {
        if (totalIterations <= 1) return initialTemperature;

        final progress = iteration / (totalIterations - 1);
        return initialTemperature *
            pow(finalTemperature / initialTemperature, progress);
      }

      // Helper function to safely calculate distance
      double safeDistance(double dx, double dy) {
        final dist = sqrt(dx * dx + dy * dy);
        return max(dist, minSeparation);
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

            if (dist <= minSeparation) continue;

            final distance = edge.distance;
            final diff = distance - dist;
            final ratio = (diff / dist) * correctionFactor;
            final limitedRatio = ratio.clamp(-0.2, 0.2);

            final offsetX = dx * limitedRatio / 2;
            final offsetY = dy * limitedRatio / 2;

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
          final point = entry.value as Map;
          positions[entry.key] = validatePosition(
            Point<double>(
              (point['x'] as num).toDouble(),
              (point['y'] as num).toDouble(),
            ),
          );
        }
      }

      // Initialize positions in a well-spaced circle around the center
      void initializeCircularLayout(
        Map<String, Point<double>> positions,
        List<String> nodeIds,
      ) {
        final center = Point(width / 2, height / 2);
        final radius = min(width, height) * 0.35;

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

      final double repStrength =
          (repulsion != null && repulsion > 0) ? (repulsion * 0.1) : 1.0;
      final double attStrength =
          (attraction != null && attraction > 0) ? (attraction * 5.0) : 0.45;

      for (int i = 0; i < iterations; i++) {
        final temperature = getTemperature(i, iterations);
        final disp = <String, Point<double>>{};

        for (final key in positions.keys) {
          disp[key] = const Point(0, 0);
        }

        // Repulsive forces between all pairs: k^2 / d
        for (var v in positions.entries) {
          for (var u in positions.entries) {
            if (v.key == u.key) continue;

            var dx = v.value.x - u.value.x;
            var dy = v.value.y - u.value.y;
            var dist = safeDistance(dx, dy);

            if (dist < minSeparation) {
              final randomScale = temperature / initialTemperature;
              dx = (rand.nextDouble() - 0.5) * 2.0 * randomScale;
              dy = (rand.nextDouble() - 0.5) * 2.0 * randomScale;
              dist = safeDistance(dx, dy);
            }

            final force = ((effectiveK * effectiveK) / dist) * repStrength;

            disp[v.key] = Point(
              disp[v.key]!.x + (dx / dist) * force,
              disp[v.key]!.y + (dy / dist) * force,
            );
            disp[u.key] = Point(
              disp[u.key]!.x - (dx / dist) * force,
              disp[u.key]!.y - (dy / dist) * force,
            );
          }
        }

        // Attractive forces for edges: (d - desiredDistance) * strength
        for (final edge in edges) {
          final sourceID = edge.source;
          final targetID = edge.target;
          final source = positions[sourceID];
          final target = positions[targetID];
          if (source == null || target == null) continue;

          var dx = source.x - target.x;
          var dy = source.y - target.y;
          var dist = safeDistance(dx, dy);

          if (dist < minSeparation) continue;

          final desiredDistance = edge.distance;
          final force = (dist - desiredDistance) * attStrength;

          disp[sourceID] = Point(
            disp[sourceID]!.x - (dx / dist) * force,
            disp[sourceID]!.y - (dy / dist) * force,
          );
          disp[targetID] = Point(
            disp[targetID]!.x + (dx / dist) * force,
            disp[targetID]!.y + (dy / dist) * force,
          );
        }

        // Update positions capped by current temperature
        for (final e in positions.entries) {
          final node = e.value;
          final id = e.key;
          final displacement = disp[id]!;

          if (displacement.x.isNaN ||
              displacement.x.isInfinite ||
              displacement.y.isNaN ||
              displacement.y.isInfinite) {
            continue;
          }

          final dispMag = sqrt(displacement.x * displacement.x +
              displacement.y * displacement.y);
          if (dispMag > 0.001) {
            final double step = min(dispMag, temperature);
            final double scale = step / dispMag;
            positions[id] = validatePosition(
              Point(node.x + displacement.x * scale, node.y + displacement.y * scale),
            );
          }
        }

        controller.sendResult(ImMap.wrap({'progress': i}));
      }

      if (correctionIterations > 0) {
        correctEdgeDistances(positions, edges);
      }

      return ImMap.wrap({
        'positions': {
          for (final e in positions.entries) e.key: e.value.toMap(),
        },
        'final': true,
      });
    },
  );
}
