
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
      final rand = Random();
      final rawNodes = unwrappedInput['nodes'];
      final rawPreserved =
          unwrappedInput['positionsToPreserve'] as Map<String, dynamic>? ?? {};
      final correctionIterations =
          unwrappedInput['correctionIterations'] as int;
      final correctionFactor = unwrappedInput['correctionFactor'] as double;


      const minDistance = 0.01;
      const maxDisplacement = 1000.0;

      final positions = <String, Point<double>>{};
      final edges = <ForceGraphEdgeDataMap>{};

      Point<double> safeAdd(Point<double> a, Point<double> b) {
        double clampVal(double v) {
          if (v.isNaN || v.isInfinite) return 0;
          return v.clamp(-maxDisplacement, maxDisplacement);
        }

        return Point(clampVal(a.x + b.x), clampVal(a.y + b.y));
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
            final dist = sqrt(
              dx * dx + dy * dy,
            ).clamp(minDistance, double.infinity);
            final diff = edge.distance - dist;
            final ratio = (diff / dist) * correctionFactor;

            final offsetX = dx * ratio / 2;
            final offsetY = dy * ratio / 2;

            positions[edge.source] = Point(a.x - offsetX, a.y - offsetY);
            positions[edge.target] = Point(b.x + offsetX, b.y + offsetY);
          }
          controller.sendResult(ImMap.wrap({'progress': i + iterations}));
        }
      }

      // Restore preserved
      rawPreserved.forEach((key, value) {
        final point = value as Map<String, dynamic>;
        positions[key] = Point<double>(
          point['x'] as double,
          point['y'] as double,
        );
      });

      if (rawNodes is Iterable) {
        for (final n in rawNodes) {
          final node = ForceGraphNodeDataMap.from(n);
          positions.putIfAbsent(
            node.id,
            () => Point(rand.nextDouble() * width, rand.nextDouble() * height),
          );
          edges.addAll(node.edges);
        }
      }

      for (int i = 0; i < iterations; i++) {
        final disp = <String, Point<double>>{
          for (final key in positions.keys) key: const Point(0, 0),
        };

        for (final v in positions.entries) {
          for (final u in positions.entries) {
            if (v.key == u.key) continue;
            double dx = v.value.x - u.value.x;
            double dy = v.value.y - u.value.y;
            double dist = sqrt(
              dx * dx + dy * dy,
            ).clamp(minDistance, double.infinity);
            double force = repulsion / (dist * dist);

            disp[v.key] = safeAdd(
              disp[v.key]!,
              Point(dx / dist * force, dy / dist * force),
            );
          }
        }

        for (final edge in edges) {
          final source = positions[edge.source];
          final target = positions[edge.target];
          if (source == null || target == null) continue;

          double dx = source.x - target.x;
          double dy = source.y - target.y;
          double dist = sqrt(
            dx * dx + dy * dy,
          ).clamp(minDistance, double.infinity);
          final edgeLength =  edge.distance;
          double force = attraction * (dist - edgeLength);

          double fx = dx / dist * force;
          double fy = dy / dist * force;

          disp[edge.source] = safeAdd(disp[edge.source]!, Point(-fx, -fy));
          disp[edge.target] = safeAdd(disp[edge.target]!, Point(fx, fy));
        }

        for (final id in positions.keys) {
          final pos = positions[id]!;
          final d = disp[id]!;
          positions[id] = safeAdd(pos, d);
        }

        controller.sendResult(ImMap.wrap({'progress': i}));
      }

      correctEdgeDistances(positions, edges);

      return ImMap.wrap({
        'positions': {
          for (final e in positions.entries)
            e.key: {
              'x': e.value.x.isFinite ? e.value.x : 0.0,
              'y': e.value.y.isFinite ? e.value.y : 0.0,
            },
        },
        'final': true,
      });
    },
  );
}
