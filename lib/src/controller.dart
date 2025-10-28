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

  final bool enableAutoCenterOnNodeSelection;

  final bool staticNodes;

  final bool uniformEdgeWeight;

  final bool enableSelection;

  final double? nodeMinimumSpacing;

  final double? nodeDragMaxForce;
  final double nodeDragDamping;

  final LinkedHashSet<String> _selectedNodeIds = LinkedHashSet();

  final double jointDamping;
  final double jointFrequency;

  final bool removeNodeCascade;

  double _nodeLinearDamping = 2.5;

  double get nodeLinearDamping => _nodeLinearDamping;

  set nodeLinearDamping(double value) {
    if (_nodeLinearDamping != value) {
      _nodeLinearDamping = value;
      for (final node in _nodes.values) {
        node.body.linearDamping = value;
      }
    }
  }

  ForceGraphController({
    bool graphBuilderDebugLogs = kDebugMode,
    this.enableSelection = true,
    double nodeLinearDamping = 2.5,
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
    this.edgeHightlightColor,
    this.edgeHiddenOpacity,
    this.nodeHiddenOpacity,
    double scale = 10,
    double minZoom = 0.1,
    double maxZoom = 2,
    double? initialZoom,
  }) : viewportController = ViewportController(
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

    final rect = Rect.fromLTRB(minX, minY, maxX, maxY);

    final shift = viewportController.screenCenter - rect.center;

    viewportController.setPan(shift);

    if (adjustZoom) {
      final currentCanvasSize = viewportController.screenSize * 0.9;

      final m = min(
        currentCanvasSize.width / rect.width,
        currentCanvasSize.height / rect.height,
      );
      viewportController.multiplyZoom(m, animationDuration: Duration.zero);
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

  void initWorld(TickerProvider state) {
    _ticker = state.createTicker(_stepWorld);
    if (isReady) {
      _startTicker();
    }
  }

  void _startTicker() {
    if (_ticker == null) {
      return;
    }
    if (!_ticker!.isActive) {
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

    final eMs = elapsed.inMicroseconds;
    final dt = (eMs - _elapsedMs) / Duration.microsecondsPerSecond;
    _elapsedMs = eMs;

    world.stepDt(dt);
    viewportController.update(dt);
    for (final node in _nodes.values) {
      node.update(dt, eMs);
    }

    if (!_isReady) {
      if (_graphBuilder.ensureReady(dt, this)) {
        _isReady = true;
        _isReadyCallback();
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

  void zoomOnNode(String nodeID, [double? zoom]) {
    zoom ??= (viewportController.maxZoom + viewportController.minZoom) / 2;
    final node = _nodes[nodeID]!;
    final pos =
        node.position.toOffset() *
        viewportController.zoom *
        viewportController.scale;
    final shift = viewportController.screenCenter - pos;
    viewportController.setPan(shift);
    if (zoom > viewportController.zoom) {
      viewportController.applyZoom(zoom);
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
    final node = _nodes[nodeID];
    if (node == null) {
      throw 'Node $nodeID not found';
    }
    return node;
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
            removeNode(node.iD);
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
          _graphBuilder.minDistance = nodeBiggestRadius * 2.5;
        }
        if (notifyReadyStatusChange) {
          _isReady = false;
          _isLoading = true;
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

  ForceGraphNode? findBodyAt(Vector2? worldPoint) {
    if (worldPoint == null) return null;
    for (final node in _nodes.values) {
      final fixture = node.body.fixtures.firstOrNull;
      if (fixture != null && fixture.testPoint(worldPoint)) return node;
    }
    return null;
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

  final __onHovereds = <void Function(ForceGraphNode?)>[];

  final __onNodeSecondaryTaps = <void Function(ForceGraphNode, Offset)>[];
  final __onSecondaryTaps = <void Function(Offset)>[];

  void _onHover(ForceGraphNode? node) {
    for (final f in __onHovereds) {
      f(node);
    }
  }

  void _onTap(ForceGraphNode node) {
    for (final f in __onTaps) {
      f(node);
    }
  }

  void _onNodeSecondaryTap(ForceGraphNode node, Offset screenPos) {
    for (final f in __onNodeSecondaryTaps) {
      f(node, screenPos);
    }
  }

  void _onSecondaryTap(Offset screenPos) {
    for (final f in __onSecondaryTaps) {
      f(screenPos);
    }
  }

  void _onSelectionChanged() {
    final s = _nodes.values.where((node) => node.selected).toList();
    for (final f in __onSelectionChangeds) {
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
        _nodes[highlightId]!._opacity = 1;
      }
    } else {
      // no selection, all to 1
      for (final node in _nodes.values) {
        node._opacity = 1;
      }
    }
  }

  void addOnHoverListener(void Function(ForceGraphNode?) onHover) {
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

  void removeOnHoverListener(void Function(ForceGraphNode?) onHover) {
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
  void clear() {
    _hoverDebounceTimer?.cancel();
    for (final node in _nodes.values) {
      try {
        world.destroyBody(node.body);
      } catch (_) {}
    }
    _selectedNodeIds.clear();
    _joints.clear();
    _nodes.clear();
    _onHover(null);
    _onSelectionChanged();
  }

  @override
  void dispose() {
    _scheduleAutoMove?.cancel();
    _hoverDebounceTimer?.cancel();
    _graphBuilder.stop();
    super.dispose();
    disposeTicker();
    clear();
  }

  Completer<void>? _completer;

  Future<void> loadDataFrom(
    List<ForceGraphNodeData> nodes, {
    bool notifyReadyStatusChange = true,
  }) {
    _rawData.clear();
    _rawData.addAll(nodes);
    _completer = Completer();
    if (viewportController.hasSize) {
      _init(notifyReadyStatusChange: notifyReadyStatusChange);
    }
    return _completer!.future.whenComplete(() => _completer = null);
  }

  final ForceDirectedGraphBuilder _graphBuilder;

  double? nodeHiddenOpacity;

  double? edgeHiddenOpacity;

  Color? edgeHightlightColor;

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
    _ticker?.dispose();
    _ticker = null;
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

  void startDragging(Body body, Vector2 targetWorld) {
    stopDragging();
    final mouseJointDef = MouseJointDef()
      ..bodyA = ground
      ..bodyB = body
      ..target.setFrom(targetWorld)
      ..maxForce = nodeDragMaxForce ?? (body.mass * 60)
      ..dampingRatio = nodeDragDamping;
    _mouseJoint = MouseJoint(mouseJointDef);
    world.createJoint(_mouseJoint!);
  }

  void stopDragging() {
    if (_mouseJoint != null) {
      world.destroyJoint(_mouseJoint!);
      _mouseJoint = null;
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
        node.hovered = false;
      }
      if (nodeID != null) {
        final node = _nodes[nodeID];
        if (node == null) {
          return false;
        }
        node.hovered = true;
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

    _hoverDebounceTimer = Timer(const Duration(milliseconds: 10), () {
      Vector2? worldPos;
      if (position != null) {
        worldPos = viewportController.screenToWorld(position);
      }

      final node = findBodyAt(worldPos);
      hoverNode(node?.iD, programatical: false);

      if (node == null) {
        final joint = findJointAt(worldPos)?.data.iD;
        hoverEdge(joint, programatical: false);
      } else {
        hoverEdge(null, programatical: false);
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

    if (scale != 1.0) {
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
    } else if (isPanning) {
      _isDraggingNode = false;
      stopSelecting();
      viewportController.addPan(details.focalPointDelta);
    } else if (_mouseJoint != null) {
      _isDraggingNode = true;
      final worldTarget = viewportController.screenToWorld(
        details.localFocalPoint,
      );
      _mouseJoint?.setTarget(worldTarget);
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    _scheduleAutoMove?.cancel();

    if (isDraggingNode) {
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

  void multiplyZoom(
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

  void applyZoom(
    double zoom, {
    Offset? focalPoint,
    double unboundedProgressFactor = 0.5,
    Duration? animationDuration = const Duration(milliseconds: 500),
    Curve curve = Curves.linear,
  }) {
    zoom = zoom.clamp(minZoom, maxZoom);
    if (zoom == this.zoom) {
      _panAnimateElement?.cancel();
      _zoomAnimateElement?.cancel();
      return;
    }
    focalPoint ??= screenCenter;
    final scale = zoom / this.zoom;
    final Offset newPanOffset = focalPoint - (focalPoint - panOffset) * scale;
    if (animationDuration == null || animationDuration > Duration.zero) {
      animateToPan(
        newPanOffset,
        animationDuration: animationDuration,
        curve: curve,
        unboundedProgressFactor: unboundedProgressFactor,
      );
      animateZoomTo(
        zoom,
        animationDuration: animationDuration,
        curve: curve,
        unboundedProgressFactor: unboundedProgressFactor,
      );
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
  }) async {
    zoom = zoom.clamp(minZoom, maxZoom);
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

  bool get hide {
    return _controller._selectedNodeIds.isNotEmpty && !highlight;
  }

  ForceGraphEdge(this.joint, this.data, this._controller);

  void draw(Canvas canvas, BuildContext context) {
    final style = data.style.fromContext(context);

    final p1 = joint.bodyA.position.toOffset();
    final p2 = joint.bodyB.position.toOffset();
    final paint = Paint();
    if (style.color != null) {
      paint.color = style.color!;
    }
    double weight = 0.5;
    if (!_controller.uniformEdgeWeight) {
      weight = data.weight;
    }

    weight /= _controller.viewportController.scale / 2;

    if (hide) {
      paint.color = paint.color.withValues(
        alpha: _controller.edgeHiddenOpacity ?? 0.05,
      );
    } else {
      if (highlight) {
        paint.color = _controller.edgeHightlightColor ?? Colors.purpleAccent;
        weight *= 1.4;
      } else if (hovered) {
        paint.color = Colors.red;
        weight *= 1.4;
      }
    }

    paint.strokeWidth = weight;
    canvas.drawLine(p1, p2, paint);
  }
}

class ForceGraphNode {
  final Body body;
  final ForceGraphController _controller;
  Vector2 get position => body.position;

  ForceGraphNodeData get data => body.userData as ForceGraphNodeData;

  set position(Vector2 pos) => body.setTransform(pos, body.angle);

  String get iD => data.iD;

  ForceGraphNode(this.body, this._controller, this.enableAutoMove);

  static final _mass = MassData()..mass = 1;

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
    final nodeDef = BodyDef(
      type: controller.staticNodes ? BodyType.static : BodyType.dynamic,
      position: position,
    );

    nodeDef.userData = node;

    final body = world.createBody(nodeDef);

    body.createFixtureFromShape(CircleShape(radius: node.radius * 2));

    // body.setMassData(MassData()..mass = .1 * node.edges.length);
    body.setMassData(_mass);
    body.linearDamping = linearDamping;
    body.angularDamping = 100000;
    return ForceGraphNode(body, controller, enableNodesAutoMove);
  }

  void Function()? __onTap;

  void setOnTap(void Function()? onTap) {
    __onTap = onTap;
  }

  void onTap() {
    if (__onTap != null) {
      __onTap!();
    }
    _controller._onTap(this);
    selected = !selected;
    if (selected) {
      _animateCenter();
    }
  }

  bool _hovered = false;

  bool get hovered => _hovered;

  set hovered(bool value) {
    if (value != _hovered) {
      _hovered = value;
      _controller._onHover(value ? this : null);
    }
  }

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

  void draw(Canvas canvas, BuildContext context) {
    final style = data.style.fromContext(context);
    final pos = position.toOffset();
    final paint = Paint()..color = style.color ?? Colors.blue;

    double radius = data.radius;

    if (hovered) {
      radius *= 1.25;
    }
    final bool selected = this.selected;
    double borderWidth = style.borderWidth ?? 0;
    if (selected) {
      if (style.selectedBorderWidth != null) {
        borderWidth = style.selectedBorderWidth!;
      }
      if (style.selectedColor != null) {
        paint.color = style.selectedColor!;
      }
    } else if (hovered) {
      if (style.hoverColor != null) {
        paint.color = style.hoverColor!;
      }
    }
    if (borderWidth > 0) {
      final newPaint = Paint.from(paint);
      newPaint.strokeWidth = borderWidth;
      newPaint.style = PaintingStyle.stroke;
      newPaint.color =
          (selected ? style.selectedColorBorder : style.colorBorder) ??
          Colors.redAccent;
      if (_opacity != 1) {
        newPaint.color = newPaint.color.withValues(alpha: _opacity);
      }

      canvas.drawCircle(pos, radius, newPaint);
    }
    if (_opacity != 1) {
      paint.color = paint.color.withValues(alpha: _opacity);
    }

    canvas.drawCircle(pos, radius, paint);
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
      hovered = false;
    }
    _controller._onNodeSecondaryTap(this, screenPos);
  }
}

enum _ForceDirection {
  up,
  down,
  left,
  right;

  static _ForceDirection getRandom() => values[Random().nextInt(values.length)];

  static _ForceDirection getAt(int i) => values[i % values.length];
}

class _DestroyListener implements DestroyListener {
  final ForceGraphController controller;

  _DestroyListener(this.controller);
  @override
  void onDestroyFixture(Fixture fixture) {}

  @override
  void onDestroyJoint(Joint joint) {
    final bodyAID = (joint.bodyA.userData as ForceGraphNodeData).iD;
    final bodyBID = (joint.bodyB.userData as ForceGraphNodeData).iD;
    final iD = ForceGraphEdgeData.getID(bodyAID, bodyBID);
    controller._joints.remove(iD);
    controller._nodes[bodyAID]?.data.removeEdge(iD);
    controller._nodes[bodyBID]?.data.removeEdge(iD);
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
