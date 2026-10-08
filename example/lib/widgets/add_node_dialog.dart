import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

class AddNodeDialog extends StatefulWidget {
  final ForceGraphController controller;
  final Vector2? position;

  const AddNodeDialog({
    super.key,
    required this.controller,
    this.position,
  });

  @override
  State<AddNodeDialog> createState() => _AddNodeDialogState();
}

class _AddNodeDialogState extends State<AddNodeDialog> {
  final _titleController = TextEditingController();
  final _idController = TextEditingController();
  Color _selectedColor = const Color(0xFF3B82F6);
  String? _connectToId;
  double _similarity = 0.8;
  bool _pinned = false;

  final _colorOptions = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFEF4444), // Red
    const Color(0xFFF97316), // Orange
  ];

  @override
  void initState() {
    super.initState();
    final count = widget.controller.nodes.length + 1;
    _idController.text = 'node_$count';
    _titleController.text = 'New Node $count';
    if (widget.controller.nodes.isNotEmpty) {
      _connectToId = widget.controller.nodes.first.iD;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _idController.text.trim();
    final title = _titleController.text.trim();
    if (id.isEmpty) return;

    final edges = <ForceGraphEdgeData>[];
    if (_connectToId != null) {
      edges.add(
        ForceGraphEdgeData.from(
          source: id,
          target: _connectToId!,
          similarity: _similarity,
          weight: 1.5,
          style: GraphComponentStyle.from(
            color: _selectedColor.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final newNodeData = ForceGraphNodeData.from(
      id: id,
      title: title.isNotEmpty ? title : id,
      pinned: _pinned,
      radius: 0.35,
      style: GraphComponentStyle.from(
        color: _selectedColor,
        hoverColor: _selectedColor.withValues(alpha: 0.85),
        selectedColor: Colors.white,
        selectedColorBorder: _selectedColor,
        selectedBorderWidth: 3.5,
        borderWidth: 1.5,
      ),
      edges: edges,
    );

    widget.controller.addNode(
      newNodeData,
      position: widget.position,
      select: true,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existingNodes = widget.controller.nodes.toList();

    return AlertDialog(
      title: const Text('Add Node to Graph'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Node Title',
                hintText: 'e.g. Graph Database',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Node ID (unique)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            Text('Color', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((c) {
                final isSelected = c == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Connect to existing node
            if (existingNodes.isNotEmpty) ...[
              Text('Connect to Node', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _connectToId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('(None - Isolated)')),
                  ...existingNodes.map((n) {
                    return DropdownMenuItem(
                      value: n.iD,
                      child: Text(n.data.title.isNotEmpty ? n.data.title : n.iD),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _connectToId = val),
              ),
              if (_connectToId != null) ...[
                const SizedBox(height: 12),
                Text('Connection Similarity: ${(_similarity * 100).toInt()}%'),
                Slider(
                  value: _similarity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (val) => setState(() => _similarity = val),
                ),
              ],
            ],

            CheckboxListTile(
              title: const Text('Pin in place (Static)'),
              subtitle: const Text('Node will not be moved by physics forces'),
              value: _pinned,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _pinned = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('Add Node'),
        ),
      ],
    );
  }
}
