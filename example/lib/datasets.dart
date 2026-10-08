import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

class GraphDataset {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<ForceGraphNodeData> Function() generator;
  final ForceDirectedGraphBuilder Function() defaultBuilder;

  const GraphDataset({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.generator,
    required this.defaultBuilder,
  });
}

class ExampleDatasets {
  static List<GraphDataset> get all => [
        knowledgeGraph,
        dependencyGraph,
        socialNetwork,
        playground,
      ];

  // Helper to build responsive high-contrast style for dark & light mode
  static GraphComponentStyle _buildNodeStyle(Color color) {
    return GraphComponentStyle(
      light: GraphComponentStyleElement(
        color: color,
        hoverColor: color.withValues(alpha: 0.85),
        selectedColor: color,
        selectedColorBorder: const Color(0xFF0F172A),
        selectedBorderWidth: 3.0,
      ),
      dark: GraphComponentStyleElement(
        color: color,
        hoverColor: color.withValues(alpha: 0.85),
        selectedColor: color,
        selectedColorBorder: Colors.white,
        selectedBorderWidth: 3.0,
      ),
    );
  }

  // 1. AI & Computer Science Knowledge Graph
  static final GraphDataset knowledgeGraph = GraphDataset(
    id: 'knowledge',
    title: 'AI Knowledge Graph',
    description: 'Interconnected concepts in Artificial Intelligence & Machine Learning',
    icon: Icons.hub_rounded,
    defaultBuilder: () => SpringEmbedderGraphBuilder(
      iterations: 400,
    ),
    generator: () {
      final categories = <String, Color>{
        'Core AI': const Color(0xFF6366F1), // Indigo
        'Machine Learning': const Color(0xFF3B82F6), // Blue
        'Deep Learning': const Color(0xFF8B5CF6), // Purple
        'NLP': const Color(0xFFEC4899), // Pink
        'Computer Vision': const Color(0xFFF59E0B), // Amber
        'Infrastructure': const Color(0xFF10B981), // Emerald
      };

      ForceGraphNodeData makeNode({
        required String id,
        required String title,
        required String category,
        double radius = 9.5,
        bool pinned = false,
        List<ForceGraphEdgeData> edges = const [],
      }) {
        final color = categories[category] ?? Colors.blueGrey;
        return ForceGraphNodeData.from(
          id: id,
          title: title,
          radius: radius,
          pinned: pinned,
          data: {'category': category},
          style: _buildNodeStyle(color),
          edges: edges,
        );
      }

      final nodes = <ForceGraphNodeData>[
        makeNode(
          id: 'ai',
          title: 'Artificial Intelligence',
          category: 'Core AI',
          radius: 16.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'ai',
              target: 'ml',
              similarity: 0.65,
              weight: 2.0,
              label: 'includes',
              style: GraphComponentStyle.from(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'ai',
              target: 'knowledge_rep',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
            ),
            ForceGraphEdgeData.from(
              source: 'ai',
              target: 'expert_sys',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(
          id: 'ml',
          title: 'Machine Learning',
          category: 'Machine Learning',
          radius: 13.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'ml',
              target: 'dl',
              similarity: 0.65,
              weight: 1.9,
              label: 'subset',
              style: GraphComponentStyle.from(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'ml',
              target: 'super_learning',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
            ),
            ForceGraphEdgeData.from(
              source: 'ml',
              target: 'unsuper_learning',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
            ),
            ForceGraphEdgeData.from(
              source: 'ml',
              target: 'rl',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(
          id: 'dl',
          title: 'Deep Learning',
          category: 'Deep Learning',
          radius: 12.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'dl',
              target: 'transformers',
              similarity: 0.65,
              weight: 1.9,
              style: GraphComponentStyle.from(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'dl',
              target: 'cnn',
              similarity: 0.6,
              weight: 1.8,
              style: GraphComponentStyle.from(color: const Color(0xFF8B5CF6).withValues(alpha: 0.45)),
            ),
            ForceGraphEdgeData.from(
              source: 'dl',
              target: 'rnn',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
            ),
            ForceGraphEdgeData.from(
              source: 'dl',
              target: 'pytorch',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(
          id: 'transformers',
          title: 'Transformers',
          category: 'NLP',
          radius: 12.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'transformers',
              target: 'llms',
              similarity: 0.65,
              weight: 2.0,
              label: 'powers',
              style: GraphComponentStyle.from(color: const Color(0xFFEC4899).withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'transformers',
              target: 'attention',
              similarity: 0.6,
              weight: 1.8,
              style: GraphComponentStyle.from(color: const Color(0xFFEC4899).withValues(alpha: 0.4)),
            ),
            ForceGraphEdgeData.from(
              source: 'transformers',
              target: 'bert',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFEC4899).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(
          id: 'llms',
          title: 'Large Language Models',
          category: 'NLP',
          radius: 12.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'llms',
              target: 'prompt_eng',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFEC4899).withValues(alpha: 0.35)),
            ),
            ForceGraphEdgeData.from(
              source: 'llms',
              target: 'rlhf',
              similarity: 0.6,
              weight: 1.8,
              style: GraphComponentStyle.from(color: const Color(0xFFEC4899).withValues(alpha: 0.4)),
            ),
          ],
        ),
        makeNode(id: 'attention', title: 'Self-Attention', category: 'NLP', radius: 9.5),
        makeNode(id: 'bert', title: 'BERT', category: 'NLP', radius: 9.5),
        makeNode(id: 'prompt_eng', title: 'Prompt Engineering', category: 'NLP', radius: 9.5),
        makeNode(
          id: 'rlhf',
          title: 'RLHF Alignment',
          category: 'Machine Learning',
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'rlhf',
              target: 'rl',
              similarity: 0.6,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(
          id: 'cnn',
          title: 'Convolutional Nets',
          category: 'Computer Vision',
          radius: 11.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'cnn',
              target: 'obj_detect',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
            ),
            ForceGraphEdgeData.from(
              source: 'cnn',
              target: 'diffusion',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(id: 'obj_detect', title: 'Object Detection', category: 'Computer Vision', radius: 9.5),
        makeNode(
          id: 'diffusion',
          title: 'Diffusion Models',
          category: 'Computer Vision',
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'diffusion',
              target: 'dl',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(id: 'rnn', title: 'Recurrent Nets (LSTM)', category: 'Deep Learning', radius: 9.5),
        makeNode(id: 'super_learning', title: 'Supervised Learning', category: 'Machine Learning', radius: 9.5),
        makeNode(id: 'unsuper_learning', title: 'Unsupervised Learning', category: 'Machine Learning', radius: 9.5),
        makeNode(id: 'rl', title: 'Reinforcement Learning', category: 'Machine Learning', radius: 11.0),
        makeNode(id: 'knowledge_rep', title: 'Knowledge Graphs', category: 'Core AI', radius: 9.5),
        makeNode(id: 'expert_sys', title: 'Expert Systems', category: 'Core AI', radius: 9.5),
        makeNode(
          id: 'pytorch',
          title: 'PyTorch & CUDA',
          category: 'Infrastructure',
          radius: 11.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'pytorch',
              target: 'gpu_clusters',
              similarity: 0.6,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makeNode(id: 'gpu_clusters', title: 'GPU Clusters', category: 'Infrastructure', radius: 9.5),
      ];

      return nodes;
    },
  );

  // 2. Flutter Package Dependency Graph (Directed edges with arrows)
  static final GraphDataset dependencyGraph = GraphDataset(
    id: 'dependencies',
    title: 'Package Dependencies',
    description: 'Directed dependency DAG with arrows & module layers',
    icon: Icons.account_tree_rounded,
    defaultBuilder: () => HierarchicalGraphBuilder(
      horizontalSpacing: 120,
      verticalSpacing: 110,
    ),
    generator: () {
      ForceGraphNodeData makePkg({
        required String id,
        required String title,
        required Color color,
        double radius = 9.5,
        List<ForceGraphEdgeData> edges = const [],
      }) {
        return ForceGraphNodeData.from(
          id: id,
          title: title,
          radius: radius,
          style: _buildNodeStyle(color),
          edges: edges,
        );
      }

      const appColor = Color(0xFF38BDF8); // Sky blue
      const coreColor = Color(0xFF818CF8); // Indigo
      const engineColor = Color(0xFFF472B6); // Rose
      const utilColor = Color(0xFF34D399); // Mint

      return [
        makePkg(
          id: 'app',
          title: 'Flutter App',
          color: appColor,
          radius: 16.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'app',
              target: 'force_graph',
              similarity: 0.65,
              weight: 2.0,
              directed: true,
              label: '^0.6.0',
              style: GraphComponentStyle.from(color: appColor.withValues(alpha: 0.6)),
            ),
            ForceGraphEdgeData.from(
              source: 'app',
              target: 'provider',
              similarity: 0.55,
              weight: 1.6,
              directed: true,
              label: '^6.1.0',
              style: GraphComponentStyle.from(color: appColor.withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'app',
              target: 'flutter_bloc',
              similarity: 0.5,
              weight: 1.6,
              directed: true,
              label: '^8.1.0',
              style: GraphComponentStyle.from(color: appColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
        makePkg(
          id: 'force_graph',
          title: 'force_graph',
          color: coreColor,
          radius: 13.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'force_graph',
              target: 'forge2d',
              similarity: 0.65,
              weight: 1.9,
              directed: true,
              style: GraphComponentStyle.from(color: coreColor.withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'force_graph',
              target: 'isolate_manager',
              similarity: 0.6,
              weight: 1.8,
              directed: true,
              style: GraphComponentStyle.from(color: coreColor.withValues(alpha: 0.5)),
            ),
            ForceGraphEdgeData.from(
              source: 'force_graph',
              target: 'flutter_framework',
              similarity: 0.6,
              weight: 1.8,
              directed: true,
              style: GraphComponentStyle.from(color: coreColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
        makePkg(
          id: 'provider',
          title: 'provider',
          color: utilColor,
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'provider',
              target: 'flutter_framework',
              similarity: 0.55,
              weight: 1.6,
              directed: true,
              style: GraphComponentStyle.from(color: utilColor.withValues(alpha: 0.45)),
            ),
          ],
        ),
        makePkg(
          id: 'flutter_bloc',
          title: 'flutter_bloc',
          color: utilColor,
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'flutter_bloc',
              target: 'bloc',
              similarity: 0.6,
              weight: 1.6,
              directed: true,
              style: GraphComponentStyle.from(color: utilColor.withValues(alpha: 0.45)),
            ),
            ForceGraphEdgeData.from(
              source: 'flutter_bloc',
              target: 'flutter_framework',
              similarity: 0.55,
              weight: 1.6,
              directed: true,
              style: GraphComponentStyle.from(color: utilColor.withValues(alpha: 0.45)),
            ),
          ],
        ),
        makePkg(
          id: 'bloc',
          title: 'bloc core',
          color: utilColor,
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'bloc',
              target: 'rxdart',
              similarity: 0.5,
              weight: 1.6,
              directed: true,
              style: GraphComponentStyle.from(color: utilColor.withValues(alpha: 0.4)),
            ),
          ],
        ),
        makePkg(id: 'rxdart', title: 'rxdart', color: utilColor, radius: 9.5),
        makePkg(
          id: 'forge2d',
          title: 'forge2d physics',
          color: engineColor,
          radius: 11.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'forge2d',
              target: 'vector_math',
              similarity: 0.6,
              weight: 1.8,
              directed: true,
              style: GraphComponentStyle.from(color: engineColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
        makePkg(
          id: 'isolate_manager',
          title: 'isolate_manager',
          color: engineColor,
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'isolate_manager',
              target: 'dart_async',
              similarity: 0.55,
              weight: 1.6,
              directed: true,
              style: GraphComponentStyle.from(color: engineColor.withValues(alpha: 0.45)),
            ),
          ],
        ),
        makePkg(
          id: 'flutter_framework',
          title: 'flutter / widgets',
          color: coreColor,
          radius: 13.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'flutter_framework',
              target: 'flutter_rendering',
              similarity: 0.65,
              weight: 1.9,
              directed: true,
              style: GraphComponentStyle.from(color: coreColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
        makePkg(
          id: 'flutter_rendering',
          title: 'flutter / rendering',
          color: coreColor,
          radius: 11.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'flutter_rendering',
              target: 'dart_ui',
              similarity: 0.65,
              weight: 1.9,
              directed: true,
              style: GraphComponentStyle.from(color: coreColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
        makePkg(id: 'vector_math', title: 'vector_math_64', color: utilColor, radius: 9.5),
        makePkg(id: 'dart_async', title: 'dart:async', color: utilColor, radius: 9.5),
        makePkg(id: 'dart_ui', title: 'dart:ui / engine', color: engineColor, radius: 9.5),
      ];
    },
  );

  // 3. Social Collaboration Network (Circular / Organic)
  static final GraphDataset socialNetwork = GraphDataset(
    id: 'social',
    title: 'Team & Social Network',
    description: 'Cross-functional collaborative teams with connection strengths',
    icon: Icons.groups_rounded,
    defaultBuilder: () => CircularGraphBuilder(radius: 200),
    generator: () {
      final teams = <String, Color>{
        'Design': const Color(0xFFF43F5E), // Rose
        'Eng Frontend': const Color(0xFF06B6D4), // Cyan
        'Eng Backend': const Color(0xFF10B981), // Emerald
        'Product': const Color(0xFFF59E0B), // Amber
      };

      ForceGraphNodeData makePerson({
        required String id,
        required String name,
        required String team,
        double radius = 9.5,
        List<ForceGraphEdgeData> edges = const [],
      }) {
        final color = teams[team] ?? Colors.indigo;
        return ForceGraphNodeData.from(
          id: id,
          title: name,
          radius: radius,
          data: {'team': team},
          style: _buildNodeStyle(color),
          edges: edges,
        );
      }

      return [
        makePerson(
          id: 'u1',
          name: 'Sarah (Lead Design)',
          team: 'Design',
          radius: 13.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u1',
              target: 'u2',
              similarity: 0.65,
              weight: 1.9,
              style: GraphComponentStyle.from(color: const Color(0xFFF43F5E).withValues(alpha: 0.45)),
            ),
            ForceGraphEdgeData.from(
              source: 'u1',
              target: 'u3',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF43F5E).withValues(alpha: 0.4)),
            ),
            ForceGraphEdgeData.from(
              source: 'u1',
              target: 'u5',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF43F5E).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makePerson(
          id: 'u2',
          name: 'Leo (UI/UX Designer)',
          team: 'Design',
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u2',
              target: 'u4',
              similarity: 0.6,
              weight: 1.8,
              style: GraphComponentStyle.from(color: const Color(0xFFF43F5E).withValues(alpha: 0.4)),
            ),
            ForceGraphEdgeData.from(
              source: 'u2',
              target: 'u3',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF43F5E).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makePerson(
          id: 'u3',
          name: 'Maya (Product Manager)',
          team: 'Product',
          radius: 12.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u3',
              target: 'u4',
              similarity: 0.65,
              weight: 1.9,
              style: GraphComponentStyle.from(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
            ),
            ForceGraphEdgeData.from(
              source: 'u3',
              target: 'u6',
              similarity: 0.6,
              weight: 1.8,
              style: GraphComponentStyle.from(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            ForceGraphEdgeData.from(
              source: 'u3',
              target: 'u7',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makePerson(
          id: 'u4',
          name: 'Alex (Frontend Lead)',
          team: 'Eng Frontend',
          radius: 12.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u4',
              target: 'u5',
              similarity: 0.65,
              weight: 1.9,
              style: GraphComponentStyle.from(color: const Color(0xFF06B6D4).withValues(alpha: 0.45)),
            ),
            ForceGraphEdgeData.from(
              source: 'u4',
              target: 'u6',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
            ),
          ],
        ),
        makePerson(
          id: 'u5',
          name: 'Noah (Mobile Dev)',
          team: 'Eng Frontend',
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u5',
              target: 'u6',
              similarity: 0.5,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
            ),
          ],
        ),
        makePerson(
          id: 'u6',
          name: 'Elena (Backend Lead)',
          team: 'Eng Backend',
          radius: 12.0,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u6',
              target: 'u7',
              similarity: 0.65,
              weight: 2.0,
              style: GraphComponentStyle.from(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
            ),
            ForceGraphEdgeData.from(
              source: 'u6',
              target: 'u8',
              similarity: 0.55,
              weight: 1.6,
              style: GraphComponentStyle.from(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
          ],
        ),
        makePerson(
          id: 'u7',
          name: 'Liam (DevOps & SRE)',
          team: 'Eng Backend',
          radius: 9.5,
          edges: [
            ForceGraphEdgeData.from(
              source: 'u7',
              target: 'u8',
              similarity: 0.6,
              weight: 1.8,
              style: GraphComponentStyle.from(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
          ],
        ),
        makePerson(id: 'u8', name: 'Sophia (Data Eng)', team: 'Eng Backend', radius: 9.5),
      ];
    },
  );

  // 4. Interactive Playground (Generated mesh for stress testing & editing)
  static final GraphDataset playground = GraphDataset(
    id: 'playground',
    title: 'Interactive Playground',
    description: 'Dynamic sandbox for editing, adding nodes, and tuning physics',
    icon: Icons.games_rounded,
    defaultBuilder: () => SpringEmbedderGraphBuilder(
      iterations: 400,
    ),
    generator: () => generatePlaygroundNodes(count: 18),
  );

  static List<ForceGraphNodeData> generatePlaygroundNodes({int count = 18}) {
    final palette = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    final nodes = <ForceGraphNodeData>[];
    for (int i = 0; i < count; i++) {
      final color = palette[i % palette.length];
      nodes.add(
        ForceGraphNodeData.from(
          id: 'node_${i + 1}',
          title: 'Node ${i + 1}',
          radius: 9.5 + (i % 3) * 1.5,
          style: _buildNodeStyle(color),
          edges: [],
        ),
      );
    }

    // Connect in ring + cross links
    for (int i = 0; i < count; i++) {
      final next = (i + 1) % count;
      final cross = (i + 4) % count;

      nodes[i].edges.add(
        ForceGraphEdgeData.from(
          source: nodes[i].iD,
          target: nodes[next].iD,
          similarity: 0.6,
          weight: 1.8,
          style: GraphComponentStyle.from(color: Colors.grey.withValues(alpha: 0.35)),
        ),
      );

      if (i % 2 == 0) {
        nodes[i].edges.add(
          ForceGraphEdgeData.from(
            source: nodes[i].iD,
            target: nodes[cross].iD,
            similarity: 0.45,
            weight: 1.6,
            style: GraphComponentStyle.from(color: Colors.grey.withValues(alpha: 0.25)),
          ),
        );
      }
    }

    return nodes;
  }
}
