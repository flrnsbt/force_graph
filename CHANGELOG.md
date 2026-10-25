## 0.6.0

### New Features

- **Dynamic node and edge management**: Added `addNode()` and `addEdge()` methods on `ForceGraphController` for runtime graph manipulation, with optional auto-select on node creation.
- **Node search**: Added `searchNodes()` method to search nodes by title, ID, or custom data.
- **Node highlighting**: Added `highlightNodes()` and `resetHighlights()` to dim non-matching nodes and emphasize a subset.
- **Directed edges**: `ForceGraphEdgeData` now supports `directed` flag for one-way edges, rendered with arrowheads.
- **Edge labels**: Edges can now display optional text labels via `label` and `labelStyle` properties.
- **Custom edge painters**: Added `EdgePainter` typedef and `customPainter` on `ForceGraphEdgeData` for fully custom edge rendering.
- **Node label visibility control**: Added `NodeLabelVisibility` enum (`always`, `hoveredOrSelected`, `selectedOnly`, `never`) and `showLabel` / `labelStyle` per-node overrides.
- **Pinned nodes**: `ForceGraphNodeData` now supports `pinned` property to fix node positions in the physics simulation.
- **Secondary tap (right-click) support**: Added `onNodeSecondaryTap` and `onSecondaryTap` callbacks with tooltip builder for context menus on nodes and empty space.
- **Circular layout**: New `CircularGraphBuilder` arranges nodes in a circle or concentric rings.
- **Node data immutability helpers**: Added `copyWith()` and `deepCopy()` to both `ForceGraphNodeData` and `ForceGraphEdgeData`.
- **`clear()` method**: Added `ForceGraphController.clear()` to reset the entire graph state.
- **`Vector2` re-export**: Re-exported `forge2d.Vector2` for convenience.
- **Example app overhaul**: Complete rewrite as `ForceGraphShowcaseApp` with Material 3 theming, dark mode, dataset switching, layout algorithm selection, search, settings dialog, multi-node inspector, and add-node dialog.

### Improvements

- **Force-directed layout**: Refactored `SpringEmbedder` to use Fruchterman-Reingold algorithm with temperature-based cooling and displacement clamping for more stable layouts.
- **Disconnected node handling**: Nodes without edges are now placed at random positions instead of being ignored.
- **Auto `minDistance`**: `ForceDirectedGraphBuilder` now calculates `minDistance` from node radii if not explicitly set.
- **Edge weight rendering**: Edge stroke width now scales properly with zoom level using world-space coordinates.
- **Hit detection tolerance**: Node hit detection now uses zoom-aware tolerance for better accuracy at different zoom levels.
- **Node linear damping**: Default damping increased from `2.5` to `3.5` for more stable simulations.
- **Listener safety**: Callback lists are now copied before iteration to prevent concurrent modification errors.
- **Graph builder type safety**: Numeric map inputs are now cast via `num.toDouble()` / `num.toInt()` instead of direct cast, preventing type errors.

### Bug Fixes

- **Shift+click selection**: Added Shift+click support for toggling individual nodes without clearing existing selection.

## 0.3.9

Remove unecessary null check in removeNode


