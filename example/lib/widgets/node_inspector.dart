import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

/// Inspector panel that shows details for multiple selected nodes.
class NodesInspectorPanel extends StatefulWidget {
  final List<ForceGraphNode> nodes;
  final ForceGraphController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onFocusNeighbor;
  final ValueChanged<String> onDelete;

  const NodesInspectorPanel({
    super.key,
    required this.nodes,
    required this.controller,
    required this.onClose,
    required this.onFocusNeighbor,
    required this.onDelete,
  });

  @override
  State<NodesInspectorPanel> createState() => _NodesInspectorPanelState();
}

class _NodesInspectorPanelState extends State<NodesInspectorPanel> {
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    // Expand all by default when first opened
    _expandedIndices.addAll(List.generate(widget.nodes.length, (i) => i));
  }

  @override
  void didUpdateWidget(NodesInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If nodes changed, reset expanded indices
    if (widget.nodes.length != oldWidget.nodes.length) {
      _expandedIndices.clear();
      _expandedIndices.addAll(List.generate(widget.nodes.length, (i) => i));
    }
  }

  void _toggleExpand(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = widget.nodes;
    final controller = widget.controller;

    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 600),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.layers,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nodes.length == 1
                          ? 'Node Inspector'
                          : '${nodes.length} Nodes Selected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                    tooltip: 'Close Inspector',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Node list
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                shrinkWrap: true,
                itemCount: nodes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  return _buildNodeCard(
                    context,
                    node,
                    index,
                    controller,
                    theme,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeCard(
    BuildContext context,
    ForceGraphNode node,
    int index,
    ForceGraphController controller,
    ThemeData theme,
  ) {
    final data = node.data;
    final color =
        data.style.fromContext(context).color ?? theme.colorScheme.primary;
    final isExpanded = _expandedIndices.contains(index);
    final connectedEdges = controller.joints
        .where((j) => j.data.source == node.iD || j.data.target == node.iD)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Node header (always visible)
          InkWell(
            onTap: () => _toggleExpand(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.title.isNotEmpty ? data.title : node.iD,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${connectedEdges.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Meta info chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text('ID: ${node.iD}'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        labelStyle: const TextStyle(fontSize: 11),
                      ),
                      if (data.data is Map &&
                          (data.data as Map)['category'] != null)
                        Chip(
                          avatar: const Icon(Icons.label, size: 12),
                          label: Text('${(data.data as Map)['category']}'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: color.withValues(alpha: 0.15),
                          labelStyle: const TextStyle(fontSize: 11),
                        ),
                      if (node.isPinned)
                        Chip(
                          avatar: const Icon(
                            Icons.push_pin,
                            size: 12,
                            color: Colors.amber,
                          ),
                          label: const Text('Pinned'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            controller.focusNode(node.iD);
                          },
                          icon: const Icon(Icons.center_focus_strong, size: 14),
                          label: const Text('Focus'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            node.togglePinned();
                            (context as Element).markNeedsBuild();
                          },
                          icon: Icon(
                            node.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                            size: 14,
                            color: node.isPinned ? Colors.amber : null,
                          ),
                          label: Text(node.isPinned ? 'Unpin' : 'Pin'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Connections
                  if (connectedEdges.isNotEmpty) ...[
                    Text(
                      'Connections (${connectedEdges.length})',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...connectedEdges.take(5).map((edge) {
                      final neighborId = edge.data.source == node.iD
                          ? edge.data.target
                          : edge.data.source;
                      final neighborNode = controller.getNodeOrNull(neighborId);
                      final neighborTitle =
                          neighborNode?.data.title ?? neighborId;
                      final isOutgoing = edge.data.source == node.iD;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(
                              edge.data.directed
                                  ? (isOutgoing
                                        ? Icons.arrow_forward
                                        : Icons.arrow_back)
                                  : Icons.linear_scale,
                              size: 12,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                neighborTitle,
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(edge.data.similarity * 100).toInt()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => widget.onFocusNeighbor(neighborId),
                              child: Icon(
                                Icons.visibility_outlined,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (connectedEdges.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '... and ${connectedEdges.length - 5} more',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ] else ...[
                    const Text(
                      'No connections',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Delete button
                  OutlinedButton.icon(
                    onPressed: () => widget.onDelete(node.iD),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
