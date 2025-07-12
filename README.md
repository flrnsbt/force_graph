# force_graph

A Flutter package for interactive, force-directed graph visualization using physics simulation.

## Features

- Force-directed graph layout with customizable repulsion and attraction.
- Interactive zoom, pan, and recenter controls.
- Node and edge selection with tooltips.
- Animated transitions for viewport movement and zoom.
- Support for custom node and edge styles.
- Optional auto-move for nodes.

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  force_graph: latest
```

Import the main widget and controller:

```dart
import 'package:force_graph/force_graph.dart';
```

## Usage

Create your graph data:

```dart
final nodes = [
  ForceGraphNodeData.from(
    id: 'A',
    edges: [
      ForceGraphEdgeData.from(
        source: 'A',
        target: 'B',
        similarity: 0.8,
      ),
    ],
    title: 'Node A',
  ),
  ForceGraphNodeData.from(
    id: 'B',
    edges: [],
    title: 'Node B',
  ),
];
```

Initialize the controller and widget:

```dart
final controller = ForceGraphController(nodes: nodes);

ForceGraphWidget(
  controller: controller,
  showControlBar: true,
  nodeTooltipBuilder: (context, node) => Text(node.data.title),
  edgeTooltipBuilder: (context, edge) => Text(
    '${edge.data.source} → ${edge.data.target}',
  ),
);
```

## Customization

- Adjust layout parameters via `ForceGraphController` (iterations, repulsion, attraction).
- Provide custom control bar widgets using `customControlBarBuilder`.
- Listen for selection changes with `onSelectionChanged`.

## Example

See the [`example`](example/README.md) directory for a full Flutter app using this package.

## License

See [LICENSE](LICENSE) for details.

## Contributing

Feel free to open issues or pull requests. For questions, contact the maintainer.
