import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';
import 'package:example/datasets.dart';
import 'package:example/widgets/node_inspector.dart';
import 'package:example/widgets/settings_dialog.dart';
import 'package:example/widgets/add_node_dialog.dart';

void main() {
  runApp(const ForceGraphShowcaseApp());
}

class ForceGraphShowcaseApp extends StatefulWidget {
  const ForceGraphShowcaseApp({super.key});

  @override
  State<ForceGraphShowcaseApp> createState() => _ForceGraphShowcaseAppState();
}

class _ForceGraphShowcaseAppState extends State<ForceGraphShowcaseApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Force Graph Showcase',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: const CardThemeData(
          elevation: 2,
          color: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF818CF8),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: const CardThemeData(
          elevation: 4,
          color: Color(0xFF1E293B),
        ),
      ),
      home: GraphShowcasePage(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class GraphShowcasePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const GraphShowcasePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<GraphShowcasePage> createState() => _GraphShowcasePageState();
}

class _GraphShowcasePageState extends State<GraphShowcasePage> {
  late GraphDataset _currentDataset;
  String _layoutAlgorithm = 'spring';
  late ForceGraphController _controller;

  ForceGraphNode? _inspectedNode;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentDataset = ExampleDatasets.all.first;
    _initController();
  }

  ForceDirectedGraphBuilder _createBuilder() {
    switch (_layoutAlgorithm) {
      case 'circular':
        return CircularGraphBuilder(radius: 200);
      case 'hierarchical':
        return HierarchicalGraphBuilder(
          horizontalSpacing: 120,
          verticalSpacing: 110,
        );
      case 'distance':
        return DistanceGraphBuilder(minDistance: 90, maxDistance: 260);
      case 'spring':
      default:
        return SpringEmbedderGraphBuilder(
          iterations: 400,
        );
    }
  }

  void _initController() {
    final nodes = _currentDataset.generator();

    _controller = ForceGraphController(
      nodes: nodes,
      graphBuilder: _createBuilder(),
      maxSelection: null,
      maxZoom: 5,
      nodeLabelVisibility: NodeLabelVisibility.hoveredOrSelected,
      edgeHighlightColor: const Color(0xFFA855F7),
      enableAutoCenterOnNodeSelection: false,
    );

    _controller.addOnSelectionChangedListener(_handleSelectionChanged);
  }

  void _handleSelectionChanged(List<ForceGraphNode> selectedNodes) {
    if (!mounted) return;
    setState(() {
      if (selectedNodes.isNotEmpty) {
        _inspectedNode = selectedNodes.last;
      } else {
        _inspectedNode = null;
      }
    });
  }

  void _loadDataset(GraphDataset dataset) {
    setState(() {
      _currentDataset = dataset;
      _inspectedNode = null;
      _searchController.clear();
      _layoutAlgorithm = switch (dataset.id) {
        'dependencies' => 'hierarchical',
        'social' => 'circular',
        _ => 'spring',
      };
      _controller.loadDataFrom(
        dataset.generator(),
        graphBuilder: _createBuilder(),
      );
    });
  }

  void _changeLayout(String layout) {
    setState(() {
      _layoutAlgorithm = layout;
      _inspectedNode = null;
      _controller.graphBuilder = _createBuilder();
    });
  }

  void _openAddNodeDialog([Offset? screenPos]) {
    final worldPos = screenPos != null
        ? _controller.viewportController.screenToWorld(screenPos)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AddNodeDialog(
        controller: _controller,
        position: worldPos,
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => GraphSettingsSheet(
        controller: _controller,
        currentLayoutAlgorithm: _layoutAlgorithm,
        onLayoutAlgorithmChanged: _changeLayout,
        onReload: () => _controller.reload(),
      ),
    );
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      _controller.resetHighlights();
      return;
    }
    final matches = _controller.searchNodes(query);
    _controller.highlightNodes(matches.map((n) => n.iD));
    if (matches.isNotEmpty) {
      _controller.zoomOnNode(matches.first.iD, zoom: 0.8);
    }
  }

  @override
  void dispose() {
    _controller.removeOnSelectionChangedListener(_handleSelectionChanged);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 960;

    return Scaffold(
      body: Stack(
        children: [
          // Main Graph
          Positioned.fill(
            child: ForceGraphWidget(
              key: ValueKey(_controller),
              controller: _controller,
              selectionOverlayColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              showControlBar: true,
              controlBarAlignment:
                  isCompact ? Alignment.bottomCenter : Alignment.bottomRight,
              controlBarDirection:
                  isCompact ? Axis.horizontal : Axis.vertical,

              // Rich Node Tooltip
              nodeTooltipBuilder: (context, node) {
                final category = node.data.data is Map
                    ? (node.data.data as Map)['category']?.toString()
                    : null;
                final connected = _controller.joints.where(
                  (j) =>
                      j.data.source == node.iD || j.data.target == node.iD,
                ).length;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: node.data.style
                                        .fromContext(context)
                                        .color ??
                                    theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              node.data.title.isNotEmpty
                                  ? node.data.title
                                  : node.iD,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${node.iD} • $connected connection${connected == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (category != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Category: $category',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },

              // Rich Edge Tooltip
              edgeTooltipBuilder: (context, edge) {
                final sourceNode =
                    _controller.getNodeOrNull(edge.data.source);
                final targetNode =
                    _controller.getNodeOrNull(edge.data.target);
                final sourceName =
                    sourceNode?.data.title ?? edge.data.source;
                final targetName =
                    targetNode?.data.title ?? edge.data.target;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$sourceName ${edge.data.directed ? '→' : '—'} $targetName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Similarity: ${(edge.data.similarity * 100).toInt()}% • Weight: ${edge.data.weight.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (edge.data.label != null)
                          Text(
                            'Label: ${edge.data.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },

              // Right-Click Context Menu on Node
              nodeContextMenuBuilder: (context, controller, node, position, dismiss) {
                return _buildNodeContextMenu(context, node, dismiss);
              },

              // Right-Click Context Menu on Canvas Background
              contextMenuBuilder: (context, controller, position, dismiss) {
                return _buildCanvasContextMenu(context, position, dismiss);
              },
            ),
          ),

          // Top Header & Controls Bar
          Positioned(
            top: 0,
            left: 0,
            right: 48,
            child: _buildTopBar(context, isCompact),
          ),

          // Side Inspector Panel (when node selected)
          if (_inspectedNode != null)
            Positioned(
              top: isCompact ? null : 80,
              bottom: isCompact ? 70 : 20,
              right: isCompact ? 16 : 24,
              left: isCompact ? 16 : null,
              child: NodeInspectorPanel(
                node: _inspectedNode!,
                controller: _controller,
                onClose: () {
                  setState(() {
                    _inspectedNode = null;
                    _controller.clearSelection();
                  });
                },
                onFocusNeighbor: (neighborId) {
                  _controller.selectNode(neighborId);
                  _controller.zoomOnNode(neighborId);
                },
                onDelete: () {
                  final id = _inspectedNode!.iD;
                  setState(() {
                    _inspectedNode = null;
                    _controller.removeNode(id);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isCompact) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isCompact ? _buildCompactTopBar(context) : _buildDesktopTopBar(context),
      ),
    );
  }

  Widget _buildDesktopTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Brand logo & title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.grain_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'force_graph',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),

          // Dataset Switcher Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<GraphDataset>(
              value: _currentDataset,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.arrow_drop_down),
              items: ExampleDatasets.all.map((ds) {
                return DropdownMenuItem(
                  value: ds,
                  child: Row(
                    children: [
                      Icon(ds.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(ds.title),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (ds) {
                if (ds != null) _loadDataset(ds);
              },
            ),
          ),

          const SizedBox(width: 12),

          // Layout Algorithm Selector
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _layoutAlgorithm,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'spring', child: Text('Spring Embedder')),
                DropdownMenuItem(value: 'circular', child: Text('Circular Layout')),
                DropdownMenuItem(value: 'hierarchical', child: Text('Hierarchical')),
                DropdownMenuItem(value: 'distance', child: Text('Distance Layout')),
              ],
              onChanged: (layout) {
                if (layout != null) _changeLayout(layout);
              },
            ),
          ),

          const SizedBox(width: 16),

          // Live Search Bar
          SizedBox(
            width: 220,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search nodes...',
                  hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Quick Stats Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_controller.nodes.length} nodes • ${_controller.joints.length} edges',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Add Node button
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Node',
            onPressed: () => _openAddNodeDialog(),
          ),

          // Label Visibility Toggle
          IconButton(
            icon: Icon(
              _controller.nodeLabelVisibility == NodeLabelVisibility.always
                  ? Icons.label
                  : (_controller.nodeLabelVisibility == NodeLabelVisibility.never
                      ? Icons.label_off
                      : Icons.label_outline),
            ),
            tooltip: 'Labels: ${_controller.nodeLabelVisibility.name}',
            onPressed: () {
              setState(() {
                _controller.nodeLabelVisibility = switch (_controller.nodeLabelVisibility) {
                  NodeLabelVisibility.hoveredOrSelected => NodeLabelVisibility.always,
                  NodeLabelVisibility.always => NodeLabelVisibility.never,
                  NodeLabelVisibility.never => NodeLabelVisibility.hoveredOrSelected,
                  _ => NodeLabelVisibility.hoveredOrSelected,
                };
              });
            },
          ),

          // Settings Dialog Button
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Graph Settings',
            onPressed: _openSettings,
          ),

          // Dark/Light Mode Switch
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'force_graph',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _openAddNodeDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 20),
              onPressed: _openSettings,
            ),
            IconButton(
              icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
              onPressed: widget.onToggleTheme,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<GraphDataset>(
                  value: _currentDataset,
                  isDense: true,
                  isExpanded: true,
                  items: ExampleDatasets.all.map((ds) {
                    return DropdownMenuItem(value: ds, child: Text(ds.title));
                  }).toList(),
                  onChanged: (ds) {
                    if (ds != null) _loadDataset(ds);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _layoutAlgorithm,
                  isDense: true,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'spring', child: Text('Spring')),
                    DropdownMenuItem(value: 'circular', child: Text('Circular')),
                    DropdownMenuItem(value: 'hierarchical', child: Text('Hierarchy')),
                    DropdownMenuItem(value: 'distance', child: Text('Distance')),
                  ],
                  onChanged: (layout) {
                    if (layout != null) _changeLayout(layout);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNodeContextMenu(BuildContext context, ForceGraphNode node, VoidCallback dismiss) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                node.data.title.isNotEmpty ? node.data.title : node.iD,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.center_focus_strong, size: 18),
              title: const Text('Focus Camera'),
              onTap: () {
                dismiss();
                _controller.zoomOnNode(node.iD);
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(
                node.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 18,
                color: node.isPinned ? Colors.amber : null,
              ),
              title: Text(node.isPinned ? 'Unpin Position' : 'Pin in Place'),
              onTap: () {
                dismiss();
                node.togglePinned();
                setState(() {});
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.highlight_alt, size: 18),
              title: const Text('Highlight Neighbors'),
              onTap: () {
                dismiss();
                final neighbors = <String>{node.iD};
                for (final j in _controller.joints) {
                  if (j.data.source == node.iD) neighbors.add(j.data.target);
                  if (j.data.target == node.iD) neighbors.add(j.data.source);
                }
                _controller.highlightNodes(neighbors);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline, size: 18),
              title: const Text('Inspect Details'),
              onTap: () {
                dismiss();
                _controller.selectNode(node.iD);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              title: const Text('Delete Node', style: TextStyle(color: Colors.red)),
              onTap: () {
                dismiss();
                _controller.removeNode(node.iD);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasContextMenu(BuildContext context, Offset position, VoidCallback dismiss) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle_outline, size: 18),
              title: const Text('Add Node Here'),
              onTap: () {
                dismiss();
                _openAddNodeDialog(position);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.center_focus_strong, size: 18),
              title: const Text('Recenter View'),
              onTap: () {
                dismiss();
                _controller.recenter();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.select_all, size: 18),
              title: const Text('Select All Nodes'),
              onTap: () {
                dismiss();
                _controller.selectAllNodes();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.clear_all, size: 18),
              title: const Text('Clear Selection'),
              onTap: () {
                dismiss();
                _controller.clearSelection();
                _controller.resetHighlights();
              },
            ),
          ],
        ),
      ),
    );
  }
}
