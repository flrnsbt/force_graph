import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

class NodeInspectorPanel extends StatelessWidget {
  final ForceGraphNode node;
  final ForceGraphController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onFocusNeighbor;
  final VoidCallback onDelete;

  const NodeInspectorPanel({
    super.key,
    required this.node,
    required this.controller,
    required this.onClose,
    required this.onFocusNeighbor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = node.data;
    final color = data.style.fromContext(context).color ?? theme.colorScheme.primary;

    // Find connected edges
    final connectedEdges = controller.joints
        .where((j) => j.data.source == node.iD || j.data.target == node.iD)
        .toList();

    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 520),
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
                color: color.withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(
                    color: color.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.title.isNotEmpty ? data.title : node.iD,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                    tooltip: 'Close Inspector',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  // Meta info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text('ID: ${node.iD}'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      if (data.data is Map && (data.data as Map)['category'] != null)
                        Chip(
                          avatar: const Icon(Icons.label, size: 14),
                          label: Text('${(data.data as Map)['category']}'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                      if (node.isPinned)
                        Chip(
                          avatar: const Icon(Icons.push_pin, size: 14, color: Colors.amber),
                          label: const Text('Pinned'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            controller.focusNode(node.iD);
                          },
                          icon: const Icon(Icons.center_focus_strong, size: 16),
                          label: const Text('Focus'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            node.togglePinned();
                            (context as Element).markNeedsBuild();
                          },
                          icon: Icon(
                            node.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                            size: 16,
                            color: node.isPinned ? Colors.amber : null,
                          ),
                          label: Text(node.isPinned ? 'Unpin' : 'Pin'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Delete Node', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                  const Divider(height: 24),

                  // Connections list
                  Text(
                    'Connected Neighbors (${connectedEdges.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (connectedEdges.isEmpty)
                    const Text('No connections', style: TextStyle(fontStyle: FontStyle.italic))
                  else
                    ...connectedEdges.map((edge) {
                      final neighborId = edge.data.source == node.iD
                          ? edge.data.target
                          : edge.data.source;
                      final neighborNode = controller.getNodeOrNull(neighborId);
                      final neighborTitle = neighborNode?.data.title ?? neighborId;
                      final isOutgoing = edge.data.source == node.iD;

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          edge.data.directed
                              ? (isOutgoing ? Icons.arrow_forward : Icons.arrow_back)
                              : Icons.linear_scale,
                          size: 16,
                          color: color,
                        ),
                        title: Text(
                          neighborTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Similarity: ${(edge.data.similarity * 100).toInt()}% • Weight: ${edge.data.weight.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          tooltip: 'Focus neighbor',
                          onPressed: () => onFocusNeighbor(neighborId),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
