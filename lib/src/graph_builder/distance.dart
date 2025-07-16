import 'dart:math';

import 'package:force_graph/src/graph_builder/data.dart';
import 'package:isolate_manager/isolate_manager.dart';

List<Point<double>> _circleIntersections(Point a, num r1, Point b, num r2) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final d = sqrt(dx * dx + dy * dy);

  if (d > r1 + r2 || d < (r1 - r2).abs() || d == 0) return [];

  final aPart = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
  final h = sqrt(r1 * r1 - aPart * aPart);
  final xm = a.x + aPart * dx / d;
  final ym = a.y + aPart * dy / d;
  final rx = -dy * (h / d);
  final ry = dx * (h / d);

  return [Point(xm + rx, ym + ry), Point(xm - rx, ym - ry)];
}

extension PointOps on Point<double> {
  double get magnitude => sqrt(x * x + y * y);
  Point<double> operator -(Point<double> other) =>
      Point(x - other.x, y - other.y);
  double distanceTo(Point<double> other) => (this - other).magnitude;
}

@pragma('vm:entry-point')
@isolateManagerCustomWorker
void performDistanceLayoutIsolate(dynamic input) {
  IsolateManagerFunction.customFunction<ImMap, ImMap>(
    input,
    onEvent: (controller, ImMap input) {
      final unwrappedInput = input.toUnwrappedMap();
      final positions = <String, Point<double>>{};
      final edges = <ForceGraphEdgeDataMap>[];
      final rawNodes = unwrappedInput['nodes'];
      final minimumSpacing = unwrappedInput['minimumSpacing'] as double;
      final maximumSpacing = unwrappedInput['maximumSpacing'] as double;
      final tolerance = unwrappedInput['tolerance'] as double;

      if (rawNodes is Iterable) {
        for (final n in rawNodes) {
          final node = ForceGraphNodeDataMap.from(n);

          for (final edge in node.edges) {
            edges.add(edge);
          }
        }
      }

      final placed = <String>{};

      if (edges.isNotEmpty) {
        final first = edges.removeAt(0);
        positions[first.source] = const Point(0, 0);
        positions[first.target] = Point(
          first.distance(minimumSpacing, maximumSpacing),
          0,
        );
        placed.addAll([first.source, first.target]);

        bool progress = true;

        while (edges.isNotEmpty && progress) {
          progress = false;

          for (int i = 0; i < edges.length;) {
            final edge = edges[i];
            final sourcePlaced = positions.containsKey(edge.source);
            final targetPlaced = positions.containsKey(edge.target);

            if (sourcePlaced && targetPlaced) {
              edges.removeAt(i);
              continue;
            }

            if (sourcePlaced || targetPlaced) {
              final knownId = sourcePlaced ? edge.source : edge.target;
              final unknownId = sourcePlaced ? edge.target : edge.source;
              final knownPos = positions[knownId]!;
              final dist = edge.distance(minimumSpacing, maximumSpacing);

              final otherEdge = edges.firstWhere(
                (e) =>
                    (e.source == unknownId &&
                        positions.containsKey(e.target)) ||
                    (e.target == unknownId && positions.containsKey(e.source)),
                orElse: () => edge,
              );

              final hasSecond = otherEdge != edge;

              if (hasSecond) {
                final known2Id = otherEdge.source == unknownId
                    ? otherEdge.target
                    : otherEdge.source;
                final known2Pos = positions[known2Id]!;
                final dist2 = otherEdge.distance(
                  minimumSpacing,
                  maximumSpacing,
                );

                final points = _circleIntersections(
                  knownPos,
                  dist,
                  known2Pos,
                  dist2,
                );

                if (points.isNotEmpty) {
                  final selected = points.firstWhere(
                    (p) => positions.values.every(
                      (existing) => p.distanceTo(existing) > minimumSpacing,
                    ),
                    orElse: () => points.reduce((a, b) => a.y > b.y ? a : b),
                  );
                  positions[unknownId] = selected;
                  placed.add(unknownId);
                  edges.removeAt(i);
                  progress = true;
                  continue;
                }

                if ((knownPos.distanceTo(known2Pos) - (dist + dist2)).abs() <
                    tolerance) {
                  final fallback = Point(
                    (knownPos.x + known2Pos.x) / 2,
                    (knownPos.y + known2Pos.y) / 2,
                  );
                  positions[unknownId] = fallback;
                  placed.add(unknownId);
                  edges.removeAt(i);
                  progress = true;
                  continue;
                }
              }

              final candidate = Point(knownPos.x, knownPos.y + dist);
              final hasCollision = positions.values.any(
                (existing) => candidate.distanceTo(existing) < minimumSpacing,
              );
              positions[unknownId] = hasCollision
                  ? Point(knownPos.x + dist, knownPos.y)
                  : candidate;

              placed.add(unknownId);
              edges.removeAt(i);
              progress = true;
              continue;
            }

            i++;
          }
        }
      }

      return ImMap.wrap({
        'positions': {
          for (final e in positions.entries)
            e.key: {'x': e.value.x.toDouble(), 'y': e.value.y.toDouble()},
        },
        'final': true,
        'minimumSpacing': minimumSpacing,
      });
    },
  );
}

extension on ForceGraphEdgeDataMap {
  double distance(double minimumSpacing, double maximumSpacing) {
    return (maximumSpacing - minimumSpacing) * (1.0 - similarity) +
        minimumSpacing;
  }
}
