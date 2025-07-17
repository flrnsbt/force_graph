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
      final repulsion = unwrappedInput['repulsion'] as double;
      final attraction = unwrappedInput['attraction'] as double;
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

      double similarityToDistance(num similarity) {
        const minDist = 2.0;
        final maxDist = 25;

        similarity = similarity.clamp(0.0001, 1.0);
        return maxDist - similarity * (maxDist - minDist);
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
            final dist = sqrt(dx * dx + dy * dy);
            if (dist == 0) continue;
            final distance = similarityToDistance(edge.similarity);
            final diff = distance - dist;
            final ratio = (diff / dist) * correctionFactor;

            final offsetX = dx * ratio / 2;
            final offsetY = dy * ratio / 2;

            positions[edge.source] = Point(a.x - offsetX, a.y - offsetY);
            positions[edge.target] = Point(b.x + offsetX, b.y + offsetY);
          }
          controller.sendResult(ImMap.wrap({'progress': i + iterations}));
        }
      }

      if (rawPreserved.isNotEmpty) {
        for (final entry in rawPreserved.entries) {
          final point = entry.value as Map<String, dynamic>;
          positions[entry.key] = Point<double>(
            point['x'] as double,
            point['y'] as double,
          );
        }
      }

      if (rawNodes is Iterable) {
        for (final n in rawNodes) {
          final node = ForceGraphNodeDataMap.from(n);
          positions.putIfAbsent(
            node.id,
            () => Point(rand.nextDouble() * width, rand.nextDouble() * height),
          );
          for (final edge in node.edges) {
            edges.add(edge);
          }
        }
      }

      for (int i = 0; i < iterations; i++) {
        final disp = <String, Point<double>>{};

        // Initialize displacement
        for (final key in positions.keys) {
          disp[key] = const Point(0, 0);
        }

        // Repulsive forces
        for (var v in positions.entries) {
          for (var u in positions.entries) {
            if (v.key == u.key) continue;

            var dx = v.value.x - u.value.x;
            var dy = v.value.y - u.value.y;
            var dist = sqrt(dx * dx + dy * dy) + 0.01;

            var force = repulsion / (dist * dist);

            disp[v.key] = Point(
              disp[v.key]!.x + dx / dist * force,
              disp[v.key]!.y + dy / dist * force,
            );
          }
        }

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
          var dist = sqrt(dx * dx + dy * dy) + 0.01;
          final edgeLength = similarityToDistance(edge.similarity);

          var force = attraction * (dist - edgeLength);

          var fx = dx / dist * force;
          var fy = dy / dist * force;

          disp[sourceID] = Point(
            disp[sourceID]!.x - fx,
            disp[sourceID]!.y - fy,
          );
          disp[targetID] = Point(
            disp[targetID]!.x + fx,
            disp[targetID]!.y + fy,
          );
        }

        for (final e in positions.entries) {
          final node = e.value;
          final id = e.key;
          positions[id] = Point(node.x + disp[id]!.x, node.y + disp[id]!.y);
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
