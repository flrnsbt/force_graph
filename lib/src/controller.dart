// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:force_graph/src/data.dart';
import 'package:force_graph/src/extension.dart';
import 'package:force_graph/src/graph_builder/graph_builder.dart';
import 'package:forge2d/forge2d.dart';

class ForceGraphController extends ChangeNotifier {
  final ViewportController viewportController;

  final List<ForceGraphNodeData> _rawData = [];

  final bool enableNodesAutoMove;
  final bool animateBorders;
  final bool animateBorderOnlyIfSelected;
  final Duration animateBordersDuration;

  final bool enableAutoCenterOnNodeSelection;

  final bool staticNodes;

  final bool uniformEdgeWeight;

  final bool enableSelection;

  final bool disableHoverOnHiddenComponents;

  final Duration hoverEnterDebounceDuration;
  final Duration hoverExitDebounceDuration;

  final double? nodeMinimumSpacing;

  final double? nodeDragMaxForce;
  final double nodeDragDamping;

  final LinkedHashSet<String> _selectedNodeIds = LinkedHashSet();

  final double jointDamping;
  final double jointFrequency;

  final bool removeNodeCascade;

  double _nodeLinearDamping = 3.5;

  double get nodeLinearDamping => _nodeLinearDamping;

  set nodeLinearDamping(double value) {
    if (_nodeLinearDamping != value) {
      _nodeLinearDamping = value;
      for (final node in _nodes.values) {
        node.body.linearDamping = value;
      }
    }
  }

  NodeLabelVisibility nodeLabelVisibility;

  ForceGraphController({
    bool graphBuilderDebugLogs = kDebugMode,
    this.enableSelection = true,
    this.animateBorders = false,
    this.animateBorderOnlyIfSelected = false,
    this.animateBordersDuration = const Duration(milliseconds: 5000),
    double nodeLinearDamping = 3.5,
    this.nodeDragMaxForce,
    this.staticNodes = false,
    this.nodeDragDamping = 1,
    this.nodeMinimumSpacing = 0,
    this.removeNodeCascade = true,
    List<ForceGraphNodeData> nodes = const [],
    this.enableNodesAutoMove = false, // experimental
    this.maxSelection = 1,
    this.jointDamping = 1,
    this.jointFrequency = 1,
    this.uniformEdgeWeight = false,
    ForceDirectedGraphBuilder? graphBuilder,
    this.enableAutoCenterOnNodeSelection = true,
    Color? edgeHighlightColor,
    this.edgeHightlightColor,
    this.edgeHiddenOpacity,
    this.nodeHiddenOpacity,
    this.disableHoverOnHiddenComponents = true,
    this.nodeLabelVisibility = NodeLabelVisibility.hoveredOrSelected,
    this.hoverEnterDebounceDuration = const Duration(milliseconds: 10),
    this.hoverExitDebounceDuration = const Duration(milliseconds: 200),
    double scale = 10,
    double minZoom = 0.1,
    double maxZoom = 2,
    double? initialZoom,
  }) : _edgeHighlightColor = edgeHighlightColor ?? edgeHightlightColor,
       viewportController = ViewportController(
         zoom: initialZoom,
         scale: scale,
         minZoom: minZoom,
         maxZoom: maxZoom,
       ),
       _nodeLinearDamping = nodeLinearDamping,
       _graphBuilder =
           graphBuilder ??
           SpringEmbedderGraphBuilder(
             debugLogs: graphBuilderDebugLogs,
             iterations: 800,
             repulsion: 10,
             attraction: 0.1,
           ) {
    world.destroyListener = _DestroyListener(this);
    // world.setContactListener(_ContactListener(this));
    if (nodes.isNotEmpty) {
      _rawData.addAll(nodes);
    }
  }

  int? maxSelection = 1;

  void recenter([bool adjustZoom = true]) {
    double minX = double.maxFinite;
    double minY = double.maxFinite;
    double maxX = -double.maxFinite;
    double maxY = -double.maxFinite;
    for (final node in _nodes.values) {
      final pos =
          node.position.toOffset() *
          viewportController.zoom *
          viewportController.scale;
      minX = min(minX, pos.dx);
      minY = min(minY, pos.dy);
      maxX = max(maxX, pos.dx);
      maxY = max(maxY, pos.dy);
    }

    if (minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite) {
      final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
      final shift = viewportController.screenCenter - rect.center;
      viewportController.setPan(shift);

      if (adjustZoom && (rect.width > 0 || rect.height > 0)) {
        final currentCanvasSize = viewportController.screenSize * 0.85;

        final double m;
        if (rect.width > 0 && rect.height > 0) {
          m = min(
            currentCanvasSize.width / rect.width,
            currentCanvasSize.height / rect.height,
          );
        } else if (rect.width > 0) {
          m = currentCanvasSize.width / rect.width;
        } else {
          m = currentCanvasSize.height / rect.height;
        }
        if (m.isFinite && m > 0) {
          viewportController.multiplyZoom(m, animationDuration: Duration.zero);
        }
      }
    }
  }

  void _onSizeSet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Ticker? _ticker;

  Body? _ground;

  Ticker get ticker => _ticker!;

  Body get ground {
    if (_ground == null) {
      final bodyDef = BodyDef()..type = BodyType.static;
      _ground = world.createBody(bodyDef);
    }
    return _ground!;
  }

  void initWorld(TickerProvider vsync) {
    disposeTicker();
    _elapsedMs = 0;

    scheduleMicrotask(() {
      if (vsync is State && !(vsync as State).mounted) return;

      final newTicker = vsync.createTicker(_stepWorld);
      // if (_ticker == null) {
      //   _ticker = newTicker;
      // } else {
      //   try {
      //     if (_ticker!.isActive) {
      //       _ticker!.stop(canceled: true);
      //     }
      //     _ticker!.absorbTicker(newTicker);
      //   } catch (e) {
      //     _ticker = newTicker;
      //   }
      // }
      _ticker = newTicker;

      if (isReady) {
        _startTicker();
      }
    });
  }

  void _startTicker() {
    if (_ticker != null && !_ticker!.isActive) {
      _ticker!.start();
    }
  }

  int _elapsedMs = 0;

  bool _isReady = false;

  bool get isReady => _isReady;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _isReadyCallback() {
    recenter();
  }

  void _stepWorld(Duration elapsed) {
    if (!viewportController.hasSize) return;

    final newElapsed = elapsed.inMicroseconds;
    final dt = (newElapsed - _elapsedMs) / Duration.microsecondsPerSecond;
    _elapsedMs = newElapsed;

    world.stepDt(dt);
    viewportController.update(dt);
    for (final node in _nodes.values) {
      node.update(dt, newElapsed);
    }

    if (!_isReady) {
      if (_graphBuilder.ensureReady(dt, this)) {
        _isReady = true;
        _isReadyCallback();
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  void clearNodeForces() {
    for (final node in _nodes.values) {
      node.body.clearForces();
    }
  }

  void stopNodesAutoMove() {
    if (!enableNodesAutoMove) return;
    for (final node in _nodes.values) {
      node.enableAutoMove = false;
    }
  }

  void selectNode(String nodeID, {bool animateToCenter = true}) {
    final node = _nodes[nodeID]!;
    node.selected = true;
    if (animateToCenter) {
      node._animateCenter();
    }
  }

  Future<void> zoomOnNode(
    String nodeID, {
    double? zoom,
    bool force = false,
    Curve curve = Curves.linear,

    Duration? animationDuration,
  }) async {
    zoom ??= (viewportController.maxZoom + viewportController.minZoom) / 2;
    final node = _nodes[nodeID]!;
    final pos =
        node.position.toOffset() *
        viewportController.zoom *
        viewportController.scale;
    final shift = viewportController.screenCenter - pos;
    viewportController.setPan(shift);
    if (zoom > viewportController.zoom || force) {
      await viewportController.applyZoom(
        zoom,
        force: force,
        curve: curve,
        animationDuration: animationDuration,
      );
    }
  }

  void unselectNode(String nodeID) {
    final node = _nodes[nodeID]!;
    node.selected = false;
  }

  void toggleSelectNode(String nodeID, {bool animateToCenterOnSelect = true}) {
    final node = _nodes[nodeID]!;
    node.selected = !node.selected;
    if (animateToCenterOnSelect && node.selected) {
      node._animateCenter();
    }
  }

  void selectNodes(Iterable<String> nodeIDs) {
    for (final nodeID in nodeIDs) {
      selectNode(nodeID, animateToCenter: false);
    }
  }

  void toggleSelectNodes(Iterable<String> nodeIDs) {
    for (final nodeID in nodeIDs) {
      toggleSelectNode(nodeID, animateToCenterOnSelect: false);
    }
  }

  void unselectNodes(Iterable<String> nodeIDs) {
    for (final nodeID in nodeIDs) {
      final node = _nodes[nodeID]!;
      node.selected = false;
    }
  }

  void selectAllNodes() {
    for (final node in _nodes.values) {
      node.selected = true;
    }
  }

  void unselectAllNodes() {
    for (final node in _nodes.values) {
      node.selected = false;
    }
  }

  void focusNode(String nodeID) {
    final node = _nodes[nodeID]!;
    node._animateCenter();
  }

  ForceGraphNode getNode(String nodeID) {
    final node = getNodeOrNull(nodeID);
    if (node == null) {
      throw 'Node $nodeID not found';
    }
    return node;
  }

  ForceGraphNode? getNodeOrNull(String nodeID) {
    return _nodes[nodeID];
  }

  Set<String> removeNode(String nodeID) {
    final node = _nodes[nodeID];
    if (node == null) {
      throw 'Node $nodeID not found';
    }

    if (!node.data.removable) {
      throw 'Node $nodeID is not removable';
    }
    final removedNodeIDs = <String>{};

    _nodes.remove(nodeID);
    final body = node.body;
    final connectedNodes = <ForceGraphNode>{};
    final edges = <int, ForceGraphEdgeData>{};
    for (final edge in node.body.joints) {
      final otherBody = edge.otherBody(body);
      final otherBodyID = (otherBody.userData as ForceGraphNodeData).iD;
      connectedNodes.add(_nodes[otherBodyID]!);
      final int edgeID = ForceGraphEdgeData.getID(nodeID, otherBodyID);
      edges[edgeID] = _joints[edgeID]!.data;
    }

    try {
      world.destroyBody(body);
      if (node.selected) {
        node.selected = false;
      }
      removedNodeIDs.add(nodeID);
      final connectableNodes = [
        for (final node in connectedNodes)
          if (node.body.joints.isNotEmpty) node,
      ];

      for (final node in connectedNodes) {
        if (node.body.joints.isEmpty) {
          if (removeNodeCascade) {
            removedNodeIDs.addAll(removeNode(node.iD));
          } else {
            final oldEdge = edges[ForceGraphEdgeData.getID(nodeID, node.iD)]!;
            final closestNode = _getClosestNode(node, connectableNodes);
            if (closestNode != null) {
              final jointDef = DistanceJointDef()
                ..initialize(
                  node.body,
                  closestNode.body,
                  node.body.position,
                  closestNode.position,
                )
                ..frequencyHz = jointFrequency
                ..dampingRatio = jointDamping;
              final oldClosestNodeEdge =
                  edges[ForceGraphEdgeData.getID(nodeID, closestNode.iD)]!;
              final double similarity =
                  oldEdge.similarity * oldClosestNodeEdge.similarity;
              final weight = min(oldEdge.weight, oldClosestNodeEdge.weight);
              final style = oldEdge.style;
              final joint = DistanceJoint(jointDef);
              final data = ForceGraphEdgeData(
                node.iD,
                closestNode.iD,
                similarity,
                weight,
                style,
              );
              final edge = ForceGraphEdge(joint, data, this);
              _joints[data.iD] = edge;

              world.createJoint(joint);
            } else {
              if (node.data.removable) {
                try {
                  world.destroyBody(node.body);
                  if (node.selected) {
                    node.selected = false;
                  }
                  removedNodeIDs.add(node.iD);
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (_) {}

    return removedNodeIDs;
  }

  ForceGraphNode? _getClosestNode(
    ForceGraphNode node,
    Iterable<ForceGraphNode> connectedNodes,
  ) {
    double minDist = double.maxFinite;
    ForceGraphNode? closestBody;
    for (final otherNode in connectedNodes) {
      if (otherNode == node) continue;
      final dist = node.position.distanceTo(otherNode.position);
      if (dist < minDist) {
        minDist = dist;
        closestBody = otherNode;
      }
    }
    return closestBody;
  }

  Future<void> _init({bool notifyReadyStatusChange = true}) async {
    try {
      clear();
      _error = null;
      _ticker?.stop();
      _loadingProgressStep = 0;
      _loadingTotalStep = _graphBuilder.totalStep;

      if (_rawData.isNotEmpty) {
        final data = <ForceGraphNodeData>[];
        for (final d in _rawData) {
          data.add(d.deepCopy());
        }
        if (!_graphBuilder.hasMinDistance) {
          final nodeBiggestRadius = _getNodeBiggestRadius(data);
          _graphBuilder.minDistance = max(85.0, nodeBiggestRadius * 3.5);
        }
        _isReady = false;
        _isLoading = true;
        if (notifyReadyStatusChange) {
          notifyListeners();
        }
        final processedNodes = await _performLayout(data);
        await _loadData(processedNodes);
        _startTicker();
      }
      if (_completer != null && _completer!.isCompleted == false) {
        _completer!.complete();
      }
    } catch (e) {
      _error = e;
      if (_completer != null && _completer!.isCompleted == false) {
        _completer!.completeError(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Object? _error;
  Object? get error => _error;

  int _loadingProgressStep = 0;
  int get loadingProgressStep => _loadingProgressStep;

  int? _loadingTotalStep = 0;
  int? get loadingTotalStep => _loadingTotalStep;

  double? get loadingProgress {
    if (_loadingTotalStep == null) return null;
    return _loadingProgressStep / _loadingTotalStep!;
  }

  Future<void> reload() {
    return _init();
  }

  ForceGraphNode? findBodyAt(Vector2? worldPoint, {double? touchTolerance}) {
    if (worldPoint == null) return null;
    ForceGraphNode? bestNode;
    double bestDist = double.maxFinite;
    final zoomScale = viewportController.scale * viewportController.zoom;
    final tolerance =
        touchTolerance ?? (zoomScale > 0 ? (12.0 / zoomScale) : 4.0);

    for (final node in _nodes.values) {
      final fixture = node.body.fixtures.firstOrNull;
      if (fixture != null && fixture.testPoint(worldPoint)) {
        return node;
      }
      final dist = (node.position - worldPoint).length;
      if (dist <= node.radius + tolerance && dist < bestDist) {
        bestDist = dist;
        bestNode = node;
      }
    }
    return bestNode;
  }

  ForceGraphEdge? findJointAt(Vector2? mouseWorldPosition) {
    if (mouseWorldPosition == null) return null;
    for (final j in joints) {
      final anchorA = j.joint.anchorA;
      final anchorB = j.joint.anchorB;

      final delta = anchorB - anchorA;

      final start = anchorA;
      final end = anchorB;

      final perp = Vector2(-delta.y, delta.x)..normalize();
      final thickness = 0.75 / viewportController.zoom;
      perp.scale(thickness);

      if (_pointNearLine(mouseWorldPosition, start, end, thickness)) {
        return j;
      }
    }
    return null;
  }

  bool _pointNearLine(Vector2 p, Vector2 a, Vector2 b, double maxDist) {
    final ap = p - a;
    final ab = b - a;
    final abLen = ab.length;
    final proj = ap.dot(ab) / abLen;
    if (proj < 0 || proj > abLen) return false;

    final nearest = a + ab.normalized() * proj;
    final dist = (p - nearest).length;
    return dist <= maxDist;
  }

  final World world = World(Vector2.zero());

  final Map<String, ForceGraphNode> _nodes = {};
  final Map<int, ForceGraphEdge> _joints = {};

  UnmodifiableListView<ForceGraphNode> get nodes =>
      UnmodifiableListView(_nodes.values);

  UnmodifiableListView<ForceGraphEdge> get joints =>
      UnmodifiableListView(_joints.values);

  void clearSelection() {
    for (final node in _nodes.values) {
      node.selected = false;
    }
  }

  final __onTaps = <void Function(ForceGraphNode)>[];

  final __onSelectionChangeds = <void Function(List<ForceGraphNode>)>[];

  final __onHovereds =
      <void Function(ForceGraphNode? node, bool programatical)>[];

  final __onNodeSecondaryTaps = <void Function(ForceGraphNode, Offset)>[];
  final __onSecondaryTaps = <void Function(Offset)>[];

  void _onHover(ForceGraphNode? node, bool programatical) {
    for (final f in List.of(__onHovereds)) {
      f(node, programatical);
    }
  }

  void _onTap(ForceGraphNode node) {
    for (final f in List.of(__onTaps)) {
      f(node);
    }
  }

  void _onNodeSecondaryTap(ForceGraphNode node, Offset screenPos) {
    for (final f in List.of(__onNodeSecondaryTaps)) {
      f(node, screenPos);
    }
  }

  void _onSecondaryTap(Offset screenPos) {
    for (final f in List.of(__onSecondaryTaps)) {
      f(screenPos);
    }
  }

  void _onSelectionChanged() {
    final s = _nodes.values.where((node) => node.selected).toList();
    for (final f in List.of(__onSelectionChangeds)) {
      f(s);
    }
  }

  void _recalculateHighlights() {
    if (_selectedNodeIds.isNotEmpty) {
      // set all to hidden
      for (final node in _nodes.values) {
        node._opacity = nodeHiddenOpacity ?? 0.8;
      }
      // set selected and linked to 1
      Set<String> toHighlight = Set.from(_selectedNodeIds);
      for (final selectedId in _selectedNodeIds) {
        for (final joint in _joints.values) {
          final edge = joint.data;
          if (edge.source == selectedId) {
            toHighlight.add(edge.target);
          } else if (edge.target == selectedId) {
            toHighlight.add(edge.source);
          }
        }
      }
      for (final highlightId in toHighlight) {
        _nodes[highlightId]?._opacity = 1;
      }
    } else {
      // no selection, all to 1
      for (final node in _nodes.values) {
        node._opacity = 1;
      }
    }
  }

  void addOnHoverListener(
    void Function(ForceGraphNode? node, bool programatical) onHover,
  ) {
    __onHovereds.add(onHover);
  }

  void addOnSecondaryTapListener(void Function(Offset offset) onSecondaryTap) {
    __onSecondaryTaps.add(onSecondaryTap);
  }

  void removeOnSecondaryTapListener(
    void Function(Offset offset) onSecondaryTap,
  ) {
    __onSecondaryTaps.remove(onSecondaryTap);
  }

  void addNodeOnSecondaryTapListener(
    void Function(ForceGraphNode, Offset) onSecondaryTap,
  ) {
    __onNodeSecondaryTaps.add(onSecondaryTap);
  }

  void removeNodeOnSecondaryTapListener(
    void Function(ForceGraphNode, Offset) onSecondaryTap,
  ) {
    __onNodeSecondaryTaps.remove(onSecondaryTap);
  }

  void removeOnHoverListener(
    void Function(ForceGraphNode? node, bool programatical) onHover,
  ) {
    __onHovereds.remove(onHover);
  }

  void addOnSelectionChangedListener(
    void Function(List<ForceGraphNode>) onSelectionChanged,
  ) {
    __onSelectionChangeds.add(onSelectionChanged);
  }

  void removeOnSelectionChangedListener(
    void Function(List<ForceGraphNode>) onSelectionChanged,
  ) {
    __onSelectionChangeds.remove(onSelectionChanged);
  }

  void addOnTapListener(void Function(ForceGraphNode) onTap) {
    __onTaps.add(onTap);
  }

  void removeOnTapListener(void Function(ForceGraphNode) onTap) {
    __onTaps.remove(onTap);
  }

  /// Clears all the data in the graph controller. This is useful for when
  /// the data is changed and the graph needs to be rebuilt.
  ///
  /// This will remove all the bodies from the world, clear the node and joint
  /// maps, and reset the selected node ids and the on hover and on selection
  /// changed listeners.
  void clear({bool notify = true}) {
    _hoverDebounceTimer?.cancel();
    _isHovering = false;
    for (final node in _nodes.values) {
      try {
        world.destroyBody(node.body);
      } catch (_) {}
    }
    _selectedNodeIds.clear();
    _joints.clear();
    _nodes.clear();
    if (notify) {
      _onHover(null, true);
      _onSelectionChanged();
    }
  }

  @override
  void dispose() {
    disposeTicker();
    _scheduleAutoMove?.cancel();
    _hoverDebounceTimer?.cancel();
    _graphBuilder.stop();
    clear(notify: false);
    __onTaps.clear();
    __onSelectionChangeds.clear();
    __onHovereds.clear();
    __onNodeSecondaryTaps.clear();
    __onSecondaryTaps.clear();
    super.dispose();
  }

  Completer<void>? _completer;

  Future<void> loadDataFrom(
    List<ForceGraphNodeData> nodes, {
    bool notifyReadyStatusChange = true,
    ForceDirectedGraphBuilder? graphBuilder,
  }) {
    if (graphBuilder != null && _graphBuilder != graphBuilder) {
      _graphBuilder.stop();
      _graphBuilder = graphBuilder;
    }
    _rawData.clear();
    _rawData.addAll(nodes);
    _completer = Completer();
    if (viewportController.hasSize) {
      _init(notifyReadyStatusChange: notifyReadyStatusChange);
    }
    return _completer!.future.whenComplete(() => _completer = null);
  }

  ForceDirectedGraphBuilder _graphBuilder;

  ForceDirectedGraphBuilder get graphBuilder => _graphBuilder;

  set graphBuilder(ForceDirectedGraphBuilder value) {
    if (_graphBuilder != value) {
      _graphBuilder.stop();
      _graphBuilder = value;
      reload();
    }
  }

  double? nodeHiddenOpacity;

  double? edgeHiddenOpacity;

  Color? _edgeHighlightColor;

  Color? get edgeHighlightColor => _edgeHighlightColor ?? edgeHightlightColor;

  set edgeHighlightColor(Color? value) {
    _edgeHighlightColor = value;
    edgeHightlightColor = value;
    notifyListeners();
  }

  Color? edgeHightlightColor;

  /// Dynamically add a node to the graph at runtime.
  ForceGraphNode addNode(
    ForceGraphNodeData nodeData, {
    Vector2? position,
    bool select = false,
  }) {
    if (_nodes.containsKey(nodeData.iD)) {
      throw ArgumentError('Node with ID "${nodeData.iD}" already exists.');
    }
    _rawData.add(nodeData);
    final pos =
        position ??
        (viewportController.hasSize
            ? viewportController.screenToWorld(viewportController.screenCenter)
            : Vector2.zero());

    final node = ForceGraphNode._fromForceGraphNodeData(
      nodeData,
      this,
      position: pos,
      linearDamping: nodeLinearDamping,
      enableNodesAutoMove: enableNodesAutoMove,
    );
    _nodes[nodeData.iD] = node;

    for (final edgeData in nodeData.edges) {
      if (_nodes.containsKey(edgeData.target)) {
        try {
          addEdge(edgeData);
        } catch (_) {}
      }
    }

    if (select) {
      selectNode(node.iD);
    }
    notifyListeners();
    return node;
  }

  /// Dynamically add an edge between two existing nodes.
  ForceGraphEdge? addEdge(ForceGraphEdgeData edgeData) {
    if (edgeData.source == edgeData.target) return null;
    final nodeA = _nodes[edgeData.source];
    final nodeB = _nodes[edgeData.target];
    if (nodeA == null || nodeB == null) return null;

    final edgeID = edgeData.iD;
    if (_joints.containsKey(edgeID)) return _joints[edgeID];

    final jointDef = DistanceJointDef()
      ..initialize(nodeA.body, nodeB.body, nodeA.position, nodeB.position)
      ..frequencyHz = jointFrequency
      ..dampingRatio = jointDamping;
    jointDef.userData = edgeData;

    final joint = DistanceJoint(jointDef);
    final edge = ForceGraphEdge(joint, edgeData, this);
    _joints[edgeID] = edge;
    world.createJoint(joint);

    if (!nodeA.data.edges.any((e) => e.iD == edgeID)) {
      nodeA.data.edges.add(edgeData);
    }
    notifyListeners();
    return edge;
  }

  /// Searches nodes matching the [query] string by id or title.
  List<ForceGraphNode> searchNodes(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _nodes.values.where((node) {
      if (node.iD.toLowerCase().contains(q)) return true;
      if (node.data.title.toLowerCase().contains(q)) return true;
      final dataStr = node.data.data?.toString().toLowerCase();
      if (dataStr != null && dataStr.contains(q)) return true;
      return false;
    }).toList();
  }

  /// Highlights specified nodes and dims all other nodes.
  void highlightNodes(Iterable<String> nodeIDs) {
    final ids = nodeIDs.toSet();
    if (ids.isEmpty) {
      resetHighlights();
      return;
    }
    for (final node in _nodes.values) {
      node._opacity = ids.contains(node.iD) ? 1.0 : (nodeHiddenOpacity ?? 0.2);
    }
    notifyListeners();
  }

  /// Resets opacity of all nodes to normal or selection highlights.
  void resetHighlights() {
    _recalculateHighlights();
    notifyListeners();
  }

  List<ForceGraphNode> get selectedNodes {
    return [for (final id in _selectedNodeIds) _nodes[id]!];
  }

  Future<Map<ForceGraphNodeData, Vector2>> _performLayout(
    List<ForceGraphNodeData> nodes,
  ) async {
    await _graphBuilder.performLayout(nodes, viewportController.screenSize, (
      progress,
    ) {
      _loadingProgressStep = progress;
      notifyListeners();
    });
    return _graphBuilder.getNodes();
  }

  Future<void> _loadData(Map<ForceGraphNodeData, Vector2> nodes) async {
    for (final e in nodes.entries) {
      final body = ForceGraphNode._fromForceGraphNodeData(
        e.key,
        this,
        position: e.value,
        linearDamping: nodeLinearDamping,
        enableNodesAutoMove: enableNodesAutoMove,
      );
      _nodes[e.key.iD] = body;
    }
    double minSpacing = double.infinity;
    for (final edge in _graphBuilder.edges) {
      try {
        if (edge.source == edge.target) {
          continue;
        }
        final (nodeA, nodeB) = _getBodyPair(edge);

        final jointDef = DistanceJointDef()
          ..initialize(nodeA, nodeB, nodeA.position, nodeB.position)
          ..frequencyHz = jointFrequency
          ..dampingRatio = jointDamping;

        jointDef.userData = edge;
        final e = ForceGraphEdge(DistanceJoint(jointDef), edge, this);
        _joints[e.data.iD] = e;

        minSpacing = min(minSpacing, e.joint.distance);
        world.createJoint(e.joint);
      } catch (e) {
        debugPrint('Error creating joint for edge $edge: $e');
      }
    }
    if (nodeMinimumSpacing != 0) {
      final shape = CircleShape(radius: nodeMinimumSpacing ?? (minSpacing / 2));
      for (final node in _nodes.values) {
        node.body.createFixtureFromShape(shape);
      }
    }
  }

  (Body nodeA, Body nodeB) _getBodyPair(ForceGraphEdgeData edge) {
    final nodeA = _nodes[edge.source]!;
    final nodeB = _nodes[edge.target]!;
    return (nodeA.body, nodeB.body);
  }

  void updateCanvasSize(Size size) {
    final hadSize = viewportController.hasSize;
    final setSize = viewportController.updateCanvasSize(size);
    if (!hadSize && setSize) {
      _onSizeSet();
    }
  }

  void startNodesAutoMove() {
    if (!enableNodesAutoMove) return;
    for (final node in _nodes.values) {
      node.enableAutoMove = true;
    }
  }

  void stop() {
    _ticker?.stop(canceled: true);
  }

  void disposeTicker() {
    try {
      final t = _ticker;
      _ticker = null;

      if (t != null) {
        t.dispose();
      }
    } catch (_) {}
  }

  bool _isDraggingNode = false;
  Vector2? _selectionStart;
  Vector2? _selectionEnd;
  Offset? _hoverPosition;
  Offset? get hoverPosition => _hoverPosition;
  bool get isDraggingNode => _isDraggingNode;
  bool get isSelecting => _selectionStart != null;
  bool get isPanning {
    if (panningMode) return true;
    return _controlKeyPressed;
  }

  bool _panningMode = false;

  bool get panningMode => _panningMode;

  void setPanningMode() {
    if (_panningMode != true) {
      _panningMode = true;
      notifyListeners();
    }
  }

  void setClickingMode() {
    if (_panningMode != false) {
      _panningMode = false;
      notifyListeners();
    }
  }

  bool get _controlKeyPressed => defaultTargetPlatform == TargetPlatform.macOS
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  MouseJoint? _mouseJoint;

  Rect? get worldSelectionRect {
    if (_selectionStart != null && _selectionEnd != null) {
      return Rect.fromPoints(
        _selectionStart!.toOffset(),
        _selectionEnd!.toOffset(),
      );
    }
    return null;
  }

  Rect? get screenSelectionRect {
    if (_selectionStart != null && _selectionEnd != null) {
      return Rect.fromPoints(
        viewportController.worldToScreen(_selectionStart!),
        viewportController.worldToScreen(_selectionEnd!),
      );
    }
    return null;
  }

  void startSelecting(Vector2 worldTouch) {
    if (!enableSelection) {
      return;
    }
    stopSelecting();
    _selectionStart = worldTouch;
    _selectionEnd = _selectionStart;
  }

  void stopSelecting() {
    _selectionStart = null;
    _selectionEnd = null;
  }

  bool _draggedBodyWasStatic = false;

  void startDragging(Body body, Vector2 targetWorld) {
    stopDragging();
    _isDraggingNode = true;
    _draggedBodyWasStatic = body.bodyType == BodyType.static;
    if (_draggedBodyWasStatic) {
      body.setType(BodyType.dynamic);
    }
    final mouseJointDef = MouseJointDef()
      ..bodyA = ground
      ..bodyB = body
      ..target.setFrom(targetWorld)
      ..frequencyHz = 25.0
      ..dampingRatio = nodeDragDamping
      ..maxForce = nodeDragMaxForce ?? max(5000.0, body.mass * 50000.0);
    _mouseJoint = MouseJoint(mouseJointDef);
    world.createJoint(_mouseJoint!);
  }

  void stopDragging() {
    _isDraggingNode = false;
    if (_mouseJoint != null) {
      final body = _mouseJoint!.bodyB;
      world.destroyJoint(_mouseJoint!);
      _mouseJoint = null;
      if (_draggedBodyWasStatic) {
        body.setType(BodyType.static);
        _draggedBodyWasStatic = false;
      }
    }
  }

  String? $_hoveredNodeID;

  ForceGraphNode? get hoveredNode => _nodes[$_hoveredNodeID];

  bool get isHovering => $_hoveredNodeID != null || $_hoveredEdgeID != null;
  bool get isHoveringNode => $_hoveredNodeID != null;
  bool get isHoveringEdge => $_hoveredEdgeID != null;

  bool get isPhysicallyHoveringNode => isHoveringNode && !_programaticalHover;

  bool _programaticalHover = false;

  Timer? _hoverDebounceTimer;

  bool _isHovering = false;

  bool get canAutoMove =>
      isHovering && !isDraggingNode && !isPanning && !isSelecting;

  bool hoverNode(
    String? nodeID, {
    bool animateToCenter = false,
    bool programatical = true,
  }) {
    if (nodeID != $_hoveredNodeID) {
      if ($_hoveredNodeID != null) {
        final node = _nodes[$_hoveredNodeID]!;
        node._hovered = false;
      }
      if (nodeID != null) {
        final node = _nodes[nodeID];
        if (node == null) {
          return false;
        }
        _onHover(node, programatical);

        node._hovered = true;
        if (animateToCenter) {
          node._animateCenter();
        }
      }
      _programaticalHover = programatical;
      $_hoveredNodeID = nodeID;
      return true;
    }
    return false;
  }

  int? $_hoveredEdgeID;

  ForceGraphEdge? get hoveredEdge => _joints[$_hoveredEdgeID];

  bool hoverEdge(int? edgeID, {bool programatical = true}) {
    if (edgeID != $_hoveredEdgeID) {
      if ($_hoveredEdgeID != null) {
        final edge = _joints[$_hoveredEdgeID];
        if (edge != null) {
          edge.hovered = false;
        }
      }
      if (edgeID != null) {
        final edge = _joints[edgeID];
        if (edge != null) {
          edge.hovered = true;
        }
      }
      _programaticalHover = programatical;
      $_hoveredEdgeID = edgeID;
      return true;
    }
    return false;
  }

  void _updateAutoMoveStatus() {
    if (!enableNodesAutoMove) {
      return;
    }
    if (canAutoMove) {
      _scheduleAutoMove = Timer(const Duration(milliseconds: 500), () {
        startNodesAutoMove();
      });
    } else {
      _scheduleAutoMove?.cancel();
      stopNodesAutoMove();
    }
  }

  Timer? _scheduleAutoMove;

  double _getNodeBiggestRadius(List<ForceGraphNodeData> nodes) {
    double biggestRadius = 0;
    for (final node in nodes) {
      if (node.radius > biggestRadius) {
        biggestRadius = node.radius;
      }
    }
    return biggestRadius;
  }

  void pause() {
    if (_ticker?.isTicking == true) {
      _ticker?.muted = true;
    }
  }

  void resume() {
    if (_ticker?.muted == true) {
      _ticker?.muted = false;
    }
  }
}

extension on Joint {
  double get distance {
    final p1 = bodyA.position;
    final p2 = bodyB.position;
    return p1.distanceTo(p2);
  }
}

extension ForceGraphControllerControlsExtension on ForceGraphController {
  void onScaleStart(ScaleStartDetails details) {
    _scheduleAutoMove?.cancel();
    stopSelecting();
    final worldTouch = viewportController.screenToWorld(
      details.localFocalPoint,
    );
    final node = findBodyAt(worldTouch);

    if (node != null) {
      startDragging(node.body, worldTouch);
    } else if (!isPanning && !isHovering) {
      startSelecting(worldTouch);
    }
    _updateAutoMoveStatus();
  }

  void onPointerSignal(PointerSignalEvent event) {
    _scheduleAutoMove?.cancel();
    if (event is PointerScrollEvent) {
      if (_controlKeyPressed) {
        viewportController.addPan(-event.scrollDelta);
      } else {
        final dy = event.scrollDelta.dy;
        if (dy > 0) {
          viewportController.zoomOut(
            focalPoint: event.localPosition,
            animationDuration: Duration.zero,
          );
        } else {
          viewportController.zoomIn(
            focalPoint: event.localPosition,
            animationDuration: Duration.zero,
          );
        }
      }
    }
    _updateAutoMoveStatus();
  }

  KeyEventResult onKeyEvent(FocusNode _, KeyEvent event) {
    final ctrlPressed = _controlKeyPressed;
    const factor = 10.0;
    switch (event.physicalKey) {
      case PhysicalKeyboardKey.arrowUp:
        if (ctrlPressed) {
          viewportController.zoomIn();
        } else {
          viewportController.moveBy(Offset(0, factor));
        }
        return KeyEventResult.handled;
      case PhysicalKeyboardKey.arrowDown:
        if (ctrlPressed) {
          viewportController.zoomOut();
        } else {
          viewportController.moveBy(Offset(0, -factor));
        }
        return KeyEventResult.handled;
      case PhysicalKeyboardKey.arrowLeft:
        viewportController.moveBy(Offset(factor, 0));
        return KeyEventResult.handled;
      case PhysicalKeyboardKey.arrowRight:
        viewportController.moveBy(Offset(-factor, 0));
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void onTapUp(TapUpDetails details) {
    final screenPos = details.localPosition;
    final worldPos = viewportController.screenToWorld(screenPos);
    final node = findBodyAt(worldPos);
    if (node != null) {
      node.onTap();
    } else {
      clearSelection();
    }
  }

  void onSecondaryTapUp(TapUpDetails details) {
    final screenPos = details.localPosition;
    final worldPos = viewportController.screenToWorld(screenPos);
    final node = findBodyAt(worldPos);
    if (node != null) {
      node.onSecondaryTap(screenPos);
    } else {
      _onSecondaryTap(screenPos);
    }
  }

  void updateHover(Offset? position) {
    _scheduleAutoMove?.cancel();
    _hoverDebounceTimer?.cancel();

    Vector2? worldPos;
    if (position != null) {
      worldPos = viewportController.screenToWorld(position);
    }

    final node = findBodyAt(worldPos);
    final joint = node == null ? findJointAt(worldPos) : null;

    final willBeHovering =
        (node != null && (!disableHoverOnHiddenComponents || node.opaque)) ||
        (joint != null && (!disableHoverOnHiddenComponents || !joint.hidden));

    final isEntering = !_isHovering && willBeHovering;
    final isExiting = _isHovering && !willBeHovering;

    final debounceDuration = isEntering
        ? hoverEnterDebounceDuration
        : isExiting
        ? hoverExitDebounceDuration
        : hoverEnterDebounceDuration; // fallback

    _hoverDebounceTimer = Timer(debounceDuration, () {
      if (node != null && (!disableHoverOnHiddenComponents || node.opaque)) {
        hoverNode(node.iD, programatical: false);
        hoverEdge(null, programatical: false);
        _isHovering = true;
      } else if (joint != null &&
          (!disableHoverOnHiddenComponents || !joint.hidden)) {
        hoverNode(null, programatical: false);
        hoverEdge(joint.data.iD, programatical: false);
        _isHovering = true;
      } else {
        hoverNode(null, programatical: false);
        hoverEdge(null, programatical: false);
        _isHovering = false;
      }
      _updateAutoMoveStatus();
      _hoverPosition = position;
      _hoverDebounceTimer = null;
    });
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    _scheduleAutoMove?.cancel();

    if (isSelecting) {
      final selectionEnd = viewportController.screenToWorld(
        details.localFocalPoint,
      );
      _selectionEnd = selectionEnd;
      if (!viewportController.screenRect.contains(
        details.localFocalPoint + details.focalPointDelta,
      )) {
        viewportController.addPan(-details.focalPointDelta);
      }
      return;
    }

    final scale = details.scale;

    if (_mouseJoint != null) {
      _isDraggingNode = true;
      final worldTarget = viewportController.screenToWorld(
        details.localFocalPoint,
      );
      _mouseJoint?.setTarget(worldTarget);
    } else if (isPanning) {
      _isDraggingNode = false;
      stopSelecting();
      viewportController.addPan(details.focalPointDelta);
    } else if (scale != 1.0) {
      double dt = scale - 1;
      if (dt.isNegative) {
        dt /= 20;
      } else {
        dt /= 40;
      }
      final zoomScale = 1 + dt;
      viewportController.multiplyZoom(
        zoomScale,
        focalPoint: details.localFocalPoint,
        animationDuration: Duration.zero,
      );
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    _scheduleAutoMove?.cancel();

    if (_mouseJoint != null || isDraggingNode) {
      stopDragging();
    }
    if (isSelecting) {
      stopSelecting();
    }
    _isDraggingNode = false;
    _updateAutoMoveStatus();
  }
}

class ViewportController {
  double zoom;

  Offset panOffset;

  final double scale;

  void update(double dt) {
    if (_zoomAnimateElement != null) {
      _zoomAnimateElement!.update(dt, zoom);
    }
    if (_panAnimateElement != null) {
      _panAnimateElement!.update(dt, panOffset.toVector2());
    }
  }

  final double initialZoom;

  ViewportController({
    double? zoom,
    this.maxZoom = 2,
    this.minZoom = 0.1,
    this.panOffset = Offset.zero,
    this.scale = 10.0,
  }) : initialZoom = zoom ?? minZoom,
       zoom = zoom ?? minZoom;

  Size? _screenSize;

  Size get screenSize => _screenSize!;

  Size get worldSize => screenToWorldSize(screenSize);

  bool get hasSize => _screenSize != null;

  Offset get screenCenter => screenSize.center(Offset.zero);

  Rect get worldRect {
    final topLeft = screenToWorld(Offset.zero);
    final bottomRight = screenToWorld(
      Offset(screenSize.width, screenSize.height),
    );
    return Rect.fromLTRB(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);
  }

  Rect get screenRect {
    final topLeft = Offset.zero;
    final bottomRight = Offset(screenSize.width, screenSize.height);
    return Rect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      bottomRight.dx,
      bottomRight.dy,
    );
  }

  bool updateCanvasSize(Size size) {
    if (_screenSize != size) {
      _screenSize = size;
      return true;
    }
    return false;
  }

  Vector2 screenToWorld(Offset screen) {
    return Vector2(
      (screen.dx - panOffset.dx) / (scale * zoom),
      (screen.dy - panOffset.dy) / (scale * zoom),
    );
  }

  Size worldToScreenSize(Size size) {
    return Size(size.width * scale * zoom, size.height * scale * zoom);
  }

  Size screenToWorldSize(Size size) {
    return Size(size.width / (scale * zoom), size.height / (scale * zoom));
  }

  Offset worldToScreen(Vector2 world) {
    return Offset(
      world.x * scale * zoom + panOffset.dx,
      world.y * scale * zoom + panOffset.dy,
    );
  }

  final double minZoom;
  final double maxZoom;

  Future<void> multiplyZoom(
    double scaleDelta, {
    Offset? focalPoint,
    double unboundedProgressFactor = 0.5,
    Duration? animationDuration = const Duration(milliseconds: 500),
  }) {
    return applyZoom(
      zoom * scaleDelta,
      focalPoint: focalPoint,
      animationDuration: animationDuration,
      unboundedProgressFactor: unboundedProgressFactor,
    );
  }

  Future<void> applyZoom(
    double zoom, {
    Offset? focalPoint,
    double unboundedProgressFactor = 0.5,
    Duration? animationDuration = const Duration(milliseconds: 500),
    Curve curve = Curves.linear,
    bool force = false,
  }) async {
    if (!force) {
      zoom = zoom.clamp(minZoom, maxZoom);
    }
    if (zoom == this.zoom) {
      _panAnimateElement?.cancel();
      _zoomAnimateElement?.cancel();
      return;
    }
    focalPoint ??= screenCenter;
    final scale = zoom / this.zoom;
    final Offset newPanOffset = focalPoint - (focalPoint - panOffset) * scale;
    if (animationDuration == null || animationDuration > Duration.zero) {
      await Future.wait([
        animateToPan(
          newPanOffset,
          animationDuration: animationDuration,
          curve: curve,
          unboundedProgressFactor: unboundedProgressFactor,
        ),
        animateZoomTo(
          zoom,
          animationDuration: animationDuration,
          curve: curve,
          unboundedProgressFactor: unboundedProgressFactor,
          force: force,
        ),
      ]);
    } else {
      panOffset = newPanOffset;
      this.zoom = zoom;
    }
  }

  void addPan(Offset delta) {
    panOffset += delta;
  }

  void setPan(Offset offset) {
    panOffset = offset;
  }

  void reset() {
    zoom = initialZoom;
    panOffset = Offset.zero;
  }

  AnimateElement<double>? _zoomAnimateElement;

  Future<void> animateZoomTo(
    double zoom, {
    Duration? animationDuration = const Duration(milliseconds: 500),
    Curve curve = Curves.linear,
    double unboundedProgressFactor = 0.5,
    bool force = false,
  }) async {
    if (!force) {
      zoom = zoom.clamp(minZoom, maxZoom);
    }
    _zoomAnimateElement?.cancel();
    _zoomAnimateElement = AnimateElement.fromNum(
      zoom,
      this.zoom,
      duration: animationDuration,
      curve: curve,
      onUpdate: (newValue) {
        this.zoom = newValue;
      },
      unboundedProgressFactor: unboundedProgressFactor,
      onDone: (target, cancelled) {
        _zoomAnimateElement = null;
      },
    );
    await _zoomAnimateElement!.onDone;
  }

  AnimateElement<Vector2>? _panAnimateElement;

  Future<void> animateToPan(
    Offset target, {
    Duration? animationDuration = const Duration(milliseconds: 500),
    Curve curve = Curves.linear,
    double unboundedProgressFactor = 0.5,
  }) async {
    _panAnimateElement?.cancel();
    _panAnimateElement = AnimateElement.fromVector2(
      target.toVector2(),
      panOffset.toVector2(),
      duration: animationDuration,
      curve: curve,
      unboundedProgressFactor: unboundedProgressFactor,
      onUpdate: (newValue) {
        panOffset = newValue.toOffset();
      },
      onDone: (target, cancelled) {
        _panAnimateElement = null;
      },
    );
    await _panAnimateElement!.onDone;
  }

  void zoomIn({
    double factor = .1,
    Offset? focalPoint,

    Duration? animationDuration = const Duration(milliseconds: 100),
  }) {
    multiplyZoom(
      1 + factor,
      focalPoint: focalPoint,
      animationDuration: animationDuration,
    );
  }

  void zoomOut({
    double factor = .1,
    Offset? focalPoint,

    Duration? animationDuration = const Duration(milliseconds: 100),
  }) {
    multiplyZoom(
      1 - factor,
      focalPoint: focalPoint,
      animationDuration: animationDuration,
    );
  }

  void moveBy(Offset offset, [Duration? animateDuration = Duration.zero]) {
    offset = offset + panOffset;
    if (animateDuration == null || animateDuration > Duration.zero) {
      animateToPan(offset, animationDuration: animateDuration);
    } else {
      panOffset = offset;
    }
  }

  void cancelAnimations() {
    _zoomAnimateElement?.cancel();
    _panAnimateElement?.cancel();
    _zoomAnimateElement = null;
    _panAnimateElement = null;
  }
}

class ForceGraphEdge {
  final Joint joint;
  final ForceGraphEdgeData data;
  final ForceGraphController _controller;

  bool hovered = false;

  bool get highlight {
    final selectedNodeIDs = _controller._selectedNodeIds;
    return selectedNodeIDs.contains(data.source) ||
        selectedNodeIDs.contains(data.target);
  }

  bool get hidden {
    return _controller._selectedNodeIds.isNotEmpty && !highlight;
  }

  ForceGraphEdge(this.joint, this.data, this._controller);

  void draw(Canvas canvas, BuildContext context) {
    if (data.customPainter != null &&
        data.customPainter!(canvas, this, context)) {
      return;
    }

    final style = data.style.fromContext(context);
    final p1 = joint.bodyA.position.toOffset();
    final p2 = joint.bodyB.position.toOffset();
    final paint = Paint();
    if (style.color != null) {
      paint.color = style.color!;
    }
    double pixelWeight = _controller.uniformEdgeWeight ? 1.8 : data.weight;

    if (hidden) {
      paint.color = paint.color.withValues(
        alpha: paint.color.a * (_controller.edgeHiddenOpacity ?? 0.05),
      );
    } else {
      if (highlight) {
        paint.color =
            style.selectedColor ??
            _controller.edgeHighlightColor ??
            Colors.purpleAccent;
        pixelWeight *= 1.6;
      } else if (hovered) {
        paint.color = style.hoverColor ?? Colors.red;
        pixelWeight *= 1.6;
      }
    }

    final zoomScale = _controller.viewportController.scale *
        _controller.viewportController.zoom;
    final double strokeWidthWorld = (zoomScale > 0)
        ? (max(1.0, pixelWeight) / zoomScale)
        : pixelWeight;

    paint.strokeWidth = strokeWidthWorld;
    canvas.drawLine(p1, p2, paint);

    // Draw directed arrow if enabled
    if (data.directed) {
      final delta = p2 - p1;
      final dist = delta.distance;
      if (dist > 0.01) {
        final dir = delta / dist;
        final normal = Offset(-dir.dy, dir.dx);
        final targetNode = _controller.getNodeOrNull(data.target);
        final targetRadius = targetNode?.data.radius ?? 18.0;

        final effectiveZoom = zoomScale > 0 ? zoomScale : 1.0;
        final arrowLength = (11.0 * (highlight || hovered ? 1.3 : 1.0)) / effectiveZoom;
        final arrowWidth = (6.5 * (highlight || hovered ? 1.3 : 1.0)) / effectiveZoom;
        final tip = p2 - dir * (targetRadius + 2.0 / effectiveZoom);
        final base = tip - dir * arrowLength;
        final left = base + normal * arrowWidth;
        final right = base - normal * arrowWidth;

        final arrowPath = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close();

        final arrowPaint = Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill;
        canvas.drawPath(arrowPath, arrowPaint);
      }
    }

    // Draw edge label if provided
    if (data.label != null && data.label!.isNotEmpty && !hidden) {
      final mid = (p1 + p2) / 2;
      final zoomScale =
          _controller.viewportController.scale *
          _controller.viewportController.zoom;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      final labelStyle =
          data.labelStyle ??
          TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          );

      final tp = TextPainter(
        text: TextSpan(text: data.label, style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.scale(1.0 / zoomScale, 1.0 / zoomScale);

      final bgRect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6,
        height: tp.height + 2,
      );
      final bgPaint = Paint()
        ..color = (isDark ? Colors.black87 : Colors.white).withValues(
          alpha: 0.85,
        )
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
        bgPaint,
      );

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

class ForceGraphNode {
  final Body body;
  final ForceGraphController _controller;
  Vector2 get position => body.position;

  ForceGraphNodeData get data => body.userData as ForceGraphNodeData;

  double get radius => data.radius;

  set position(Vector2 pos) => body.setTransform(pos, body.angle);

  String get iD => data.iD;

  ForceGraphNode(this.body, this._controller, this.enableAutoMove);

  static final _mass = MassData()..mass = 0.15;

  bool get isPinned => body.bodyType == BodyType.static;

  void setPinned(bool pinned) {
    body.setType(pinned ? BodyType.static : BodyType.dynamic);
  }

  void togglePinned() {
    setPinned(!isPinned);
  }

  static ForceGraphNode _fromForceGraphNodeData(
    ForceGraphNodeData node,
    ForceGraphController controller, {
    required Vector2 position,
    double linearDamping = 3,
    bool enableNodesAutoMove = false,
  }) {
    if (position.isInfinite || position.isNaN) {
      throw 'Invalid position for node ${node.iD}: $position';
    }
    final world = controller.world;
    final isStatic = controller.staticNodes || node.pinned;
    final nodeDef = BodyDef(
      type: isStatic ? BodyType.static : BodyType.dynamic,
      position: position,
    );

    nodeDef.userData = node;

    final body = world.createBody(nodeDef);

    body.createFixtureFromShape(CircleShape(radius: node.radius));

    // body.setMassData(MassData()..mass = .1 * node.edges.length);
    body.setMassData(_mass);
    body.linearDamping = linearDamping;
    body.angularDamping = 100000;
    return ForceGraphNode(body, controller, enableNodesAutoMove);
  }

  NodeTapResult Function()? __onTap;

  void setOnTap(NodeTapResult Function()? onTap) {
    __onTap = onTap;
  }

  void onTap() {
    NodeTapResult? result;
    if (__onTap != null) {
      result = __onTap!();
    }
    _controller._onTap(this);
    selected = !selected;
    if (selected && result == NodeTapResult.focus) {
      _animateCenter();
    }
  }

  bool _hovered = false;

  bool get hovered => _hovered;

  bool get selected => _controller._selectedNodeIds.contains(iD);

  void _animateCenter() {
    if (!_controller.enableAutoCenterOnNodeSelection) {
      return;
    }
    final viewport = _controller.viewportController;

    final t =
        _controller.viewportController.screenCenter -
        (position * viewport.zoom * viewport.scale).toOffset();

    _controller.viewportController.animateToPan(t);
  }

  set selected(bool value) {
    if (selected != value) {
      if (value) {
        _controller._selectedNodeIds.add(iD);
        final selectionCount = _controller._selectedNodeIds.length;
        if (_controller.maxSelection != null &&
            selectionCount > _controller.maxSelection!) {
          _controller._selectedNodeIds.remove(iD);
          return;
        }
      } else {
        _controller._selectedNodeIds.remove(iD);
      }
      _controller._recalculateHighlights();
      _controller._onSelectionChanged();
    }
  }

  Paint? _paint;

  Color? get currentColor => _paint?.color;

  DefaultNodePainter getDefaultNodePainter(BuildContext context) {
    final style = data.style.fromContext(context);
    final paint = Paint()..color = style.color ?? Colors.blue;

    final bool selected = this.selected;
    if (selected) {
      if (style.selectedColor != null) {
        paint.color = style.selectedColor!;
      }
    } else if (hovered) {
      if (style.hoverColor != null) {
        paint.color = style.hoverColor!;
      }
    }

    if (_opacity != 1) {
      paint.color = paint.color.withValues(alpha: paint.color.a * _opacity);
    }

    double radius = data.radius;

    if (hovered) {
      radius *= 1.25;
    }

    return (paint, radius);
  }

  void draw(Canvas canvas, BuildContext context) {
    final pos = position.toOffset();

    if (data.customPainter == null ||
        !data.customPainter!(canvas, this, pos, context)) {
      final style = data.style.fromContext(context);
      final (paint, radius) = getDefaultNodePainter(context);
      _paint = paint;

      final bool selected = this.selected;
      double borderWidth = style.borderWidth ?? 0;
      Color? borderColor = style.colorBorder;
      if (selected) {
        if (style.selectedBorderWidth != null) {
          borderWidth = style.selectedBorderWidth!;
        }
        if (style.selectedColorBorder != null) {
          borderColor = style.selectedColorBorder;
        }
      }
      if (borderWidth > 0) {
        final zoomScale = _controller.viewportController.scale *
            _controller.viewportController.zoom;
        final double strokeWidthWorld;
        if (style.borderWidthRatio) {
          strokeWidthWorld = borderWidth * radius;
        } else {
          // borderWidth is in screen pixels (e.g. 2.0 or 3.0), convert to world coords
          strokeWidthWorld = (zoomScale > 0) ? (borderWidth / zoomScale) : borderWidth;
        }
        // Cap strokeWidthWorld so it never dominates the node itself (max 25% of radius)
        final effectiveStrokeWidth = min(strokeWidthWorld, radius * 0.25);

        final animateBorder = data.animateBorder ?? _controller.animateBorders;
        final animateBorderOnlyIfSelected =
            data.animateBorderOnlyIfSelected ??
            _controller.animateBorderOnlyIfSelected;
        final newPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStrokeWidth
          ..color = borderColor ?? Colors.transparent;

        double strokeRadius = radius + effectiveStrokeWidth / 2;

        if (animateBorder && (!animateBorderOnlyIfSelected || selected)) {
          final duration =
              (data.animateBorderDuration ?? _controller.animateBordersDuration)
                  .inMicroseconds;
          double r = 2 * (_controller._elapsedMs % duration) / duration;

          if (r > 1) {
            r = 2 - r;
          }

          strokeRadius = radius + (effectiveStrokeWidth / 2) + effectiveStrokeWidth * (r * 0.6 + 0.2);
        }

        if (_opacity != 1) {
          newPaint.color = newPaint.color.withValues(
            alpha: newPaint.color.a * _opacity,
          );
        }

        canvas.drawCircle(pos, strokeRadius, newPaint);
      }

      canvas.drawCircle(pos, radius, paint);

      // Draw subtle pin indicator if node is pinned
      if (isPinned) {
        final pinPaint = Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.fill;
        final pinBorder = Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        final pinCenter = Offset(pos.dx + radius * 0.7, pos.dy - radius * 0.7);
        final pinRadius = max(3.0, radius * 0.25);
        canvas.drawCircle(pinCenter, pinRadius, pinPaint);
        canvas.drawCircle(pinCenter, pinRadius, pinBorder);
      }

      // Draw node text label if enabled
      final shouldDrawLabel =
          data.showLabel ??
          switch (_controller.nodeLabelVisibility) {
            NodeLabelVisibility.always => true,
            NodeLabelVisibility.hoveredOrSelected => hovered || selected,
            NodeLabelVisibility.selectedOnly => selected,
            NodeLabelVisibility.never => false,
          };

      if (shouldDrawLabel && data.title.isNotEmpty) {
        _drawLabel(canvas, context, pos, radius);
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    BuildContext context,
    Offset pos,
    double radius,
  ) {
    final title = data.title;
    if (title.isEmpty) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final zoomScale =
        _controller.viewportController.scale *
        _controller.viewportController.zoom;

    final defaultTextColor =
        isDark ? Colors.white : const Color(0xFF1E293B);
    final effectiveStyle =
        (data.labelStyle ??
            TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: defaultTextColor,
            )).copyWith(
          color: (data.labelStyle?.color ?? defaultTextColor).withValues(
            alpha:
                (data.labelStyle?.color?.a ?? defaultTextColor.a) * _opacity,
          ),
        );

    final span = TextSpan(text: title, style: effectiveStyle);
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(pos.dx, pos.dy + radius + (3.0 / zoomScale));
    canvas.scale(1.0 / zoomScale, 1.0 / zoomScale);

    final bgRect = Rect.fromCenter(
      center: Offset(0, tp.height / 2),
      width: tp.width + 10,
      height: tp.height + 4,
    );

    final bgPaint = Paint()
      ..color = (isDark ? Colors.black87 : Colors.white).withValues(
        alpha: (selected ? 0.95 : 0.8) * _opacity,
      )
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color =
          (selected
                  ? (theme.colorScheme.primary)
                  : (isDark ? Colors.white24 : Colors.black12))
              .withValues(alpha: _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.5 : 0.8;

    final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(4));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(canvas, Offset(-tp.width / 2, 0));
    canvas.restore();
  }

  @override
  bool operator ==(Object other) => other is ForceGraphNode && other.iD == iD;

  @override
  int get hashCode => iD.hashCode;

  bool enableAutoMove = false;

  _ForceDirection _r = _ForceDirection.getRandom();

  int _i = 0;

  int get _j => _r.index;
  int _direction = 1;

  bool get colliding => body.contacts.isNotEmpty;

  void update(double dt, int totalMs) {
    if (enableAutoMove) {
      _handleAutoMove(dt, totalMs);
    }
    final selectionRect = _controller.worldSelectionRect;
    if (selectionRect != null) {
      selected = selectionRect.contains(body.position.toOffset());
    }
  }

  Vector2 _velocity = Vector2.zero();

  void _handleAutoMove(double dt, int totalMs) {
    void updateVelocity(_ForceDirection direction) {
      _r = _ForceDirection.getAt(_j + _direction);
      final direction = _getDirection(_r);
      final velocity = Vector2(
        _forceStrength.x * direction.x,
        _forceStrength.y * direction.y,
      );
      _velocity = velocity;
    }

    final i = totalMs / Duration.microsecondsPerSecond ~/ 5;
    if (i > _i) {
      _i = i;
      if (_j == 0) {
        _direction = 1;
      } else if (_j == 3) {
        _direction = -1;
      }
      updateVelocity(_r);
    }
    body.applyLinearImpulse(_velocity);
  }

  static final Vector2 _forceStrength = Vector2(0.01, .01);

  double _opacity = 1;

  double get opacity => _opacity;

  bool get opaque => _opacity >= 1;

  bool moving([double tolerance = 0.1]) {
    final velocity = body.linearVelocity;
    final vX = velocity.x.abs();
    final vY = velocity.y.abs();
    return vX > tolerance || vY > tolerance;
  }

  Vector2 _getDirection(_ForceDirection direction) {
    switch (direction) {
      case _ForceDirection.up:
        return Vector2(0, -1);
      case _ForceDirection.down:
        return Vector2(0, 1);
      case _ForceDirection.left:
        return Vector2(-1, 0);
      case _ForceDirection.right:
        return Vector2(1, 0);
    }
  }

  void onSecondaryTap(Offset screenPos) {
    if (hovered) {
      _hovered = false;
    }
    _controller._onNodeSecondaryTap(this, screenPos);
  }
}

typedef DefaultNodePainter = (Paint painter, double radius);

enum _ForceDirection {
  up,
  down,
  left,
  right;

  static _ForceDirection getRandom() => values[Random().nextInt(values.length)];

  static _ForceDirection getAt(int i) => values[i % values.length];
}

enum NodeTapResult { focus, none }

class _DestroyListener implements DestroyListener {
  final ForceGraphController controller;

  _DestroyListener(this.controller);
  @override
  void onDestroyFixture(Fixture fixture) {}

  @override
  void onDestroyJoint(Joint joint) {
    final bodyAUserData = joint.bodyA.userData;
    final bodyBUserData = joint.bodyB.userData;
    if (bodyAUserData is ForceGraphNodeData &&
        bodyBUserData is ForceGraphNodeData) {
      final bodyAID = bodyAUserData.iD;
      final bodyBID = bodyBUserData.iD;
      final iD = ForceGraphEdgeData.getID(bodyAID, bodyBID);
      controller._joints.remove(iD);
      controller._nodes[bodyAID]?.data.removeEdge(iD);
      controller._nodes[bodyBID]?.data.removeEdge(iD);
    }
  }
}

// class _ContactListener extends ContactListener {
//   final ForceGraphController controller;

//   _ContactListener(this.controller);
//   @override
//   void beginContact(Contact contact) {
//     final a = (contact.fixtureA.body.userData as ForceGraphNodeData).id;
//     final b = (contact.fixtureB.body.userData as ForceGraphNodeData).id;
//     controller._collidingNodes.add(a);
//     controller._collidingNodes.add(b);
//   }

//   @override
//   void endContact(Contact contact) {
//     final a = (contact.fixtureA.body.userData as ForceGraphNodeData).id;
//     final b = (contact.fixtureB.body.userData as ForceGraphNodeData).id;
//     controller._collidingNodes.remove(a);
//     controller._collidingNodes.remove(b);
//   }
// }
