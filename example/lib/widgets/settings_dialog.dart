import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

class GraphSettingsSheet extends StatefulWidget {
  final ForceGraphController controller;
  final String currentLayoutAlgorithm;
  final ValueChanged<String> onLayoutAlgorithmChanged;
  final VoidCallback onReload;

  const GraphSettingsSheet({
    super.key,
    required this.controller,
    required this.currentLayoutAlgorithm,
    required this.onLayoutAlgorithmChanged,
    required this.onReload,
  });

  @override
  State<GraphSettingsSheet> createState() => _GraphSettingsSheetState();
}

class _GraphSettingsSheetState extends State<GraphSettingsSheet> {
  late String _layoutAlgorithm;
  late NodeLabelVisibility _labelVisibility;
  late double _damping;
  late bool _autoMove;

  @override
  void initState() {
    super.initState();
    _layoutAlgorithm = widget.currentLayoutAlgorithm;
    _labelVisibility = widget.controller.nodeLabelVisibility;
    _damping = widget.controller.nodeLinearDamping;
    _autoMove = widget.controller.enableNodesAutoMove;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded),
              const SizedBox(width: 10),
              Text(
                'Graph Settings & Physics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Layout Algorithm
          Text('Layout Algorithm', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'spring', label: Text('Spring')),
              ButtonSegment(value: 'circular', label: Text('Circular')),
              ButtonSegment(value: 'hierarchical', label: Text('Hierarchy')),
              ButtonSegment(value: 'distance', label: Text('Distance')),
            ],
            selected: {_layoutAlgorithm},
            onSelectionChanged: (set) {
              final selected = set.first;
              setState(() {
                _layoutAlgorithm = selected;
              });
              widget.onLayoutAlgorithmChanged(selected);
            },
          ),
          const SizedBox(height: 20),

          // Label Visibility
          Text('Node Labels Visibility', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<NodeLabelVisibility>(
            segments: const [
              ButtonSegment(
                value: NodeLabelVisibility.always,
                label: Text('Always'),
              ),
              ButtonSegment(
                value: NodeLabelVisibility.hoveredOrSelected,
                label: Text('Hover/Select'),
              ),
              ButtonSegment(
                value: NodeLabelVisibility.never,
                label: Text('Hidden'),
              ),
            ],
            selected: {_labelVisibility},
            onSelectionChanged: (set) {
              setState(() {
                _labelVisibility = set.first;
                widget.controller.nodeLabelVisibility = _labelVisibility;
              });
            },
          ),
          const SizedBox(height: 20),

          // Linear Damping
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Physics Linear Damping', style: theme.textTheme.labelLarge),
              Text(_damping.toStringAsFixed(1), style: theme.textTheme.bodyMedium),
            ],
          ),
          Slider(
            value: _damping,
            min: 0.5,
            max: 10.0,
            divisions: 19,
            onChanged: (val) {
              setState(() {
                _damping = val;
                widget.controller.nodeLinearDamping = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // Auto Move
          SwitchListTile(
            title: const Text('Physics Auto-Movement'),
            subtitle: const Text('Subtle organic oscillation of graph bodies'),
            value: _autoMove,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() {
                _autoMove = val;
                if (val) {
                  widget.controller.startNodesAutoMove();
                } else {
                  widget.controller.stopNodesAutoMove();
                }
              });
            },
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onReload();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Apply & Recompute Layout'),
          ),
        ],
      ),
    );
  }
}
