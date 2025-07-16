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

  final bool uniformEdgeWeight;

  final bool enableSelection;

  final LinkedHashSet<String> _selectedNodeIds = LinkedHashSet();

  final double jointDamping;
  final double jointFrequency;

  ForceGraphController({
    bool graphBuilderDebugLogs = kDebugMode,
    this.enableSelection = true,
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

  void updateGraphBuilder(ForceDirectedGraphBuilder graphBuilder) {
    _graphBuilder = graphBuilder;
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

  Future<void> _onSizeSet() {
    return _init();
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

  void focusNode(String nodeID) {
    final node = _nodes[nodeID]!;
    node._animateCenter();
  }

  Future<void> _init({bool notifyReadyStatusChange = true}) async {
    try {
      _clear();
      _error = null;
      _ticker?.stop();
      _loadingProgressStep = 0;
      _loadingTotalStep = _graphBuilder.totalStep;

      if (_rawData.isNotEmpty) {
        if (notifyReadyStatusChange) {
          _isReady = false;
          _isLoading = true;
          notifyListeners();
        }
        await _loadData(_rawData);

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

  ForceGraphNode? findBodyAt(Vector2 worldPoint) {
    for (final node in _nodes.values) {
      final fixture = node.body.fixtures.firstOrNull;
      if (fixture != null && fixture.testPoint(worldPoint)) return node;
    }
    return null;
  }

  ForceGraphEdge? findJointAt(Vector2 mouseWorldPosition) {
    for (final j in joints) {
      final anchorA = j.joint.anchorA;
      final anchorB = j.joint.anchorB;

      final delta = anchorB - anchorA;

      final start = anchorA + delta * 0.2;
      final end = anchorA + delta * 0.8;

      final perp = Vector2(-delta.y, delta.x)..normalize();
      final thickness = 0.1;
      perp.scale(thickness);

      final p1 = start + perp;
      final p2 = start - perp;
      final p3 = end - perp;
      final p4 = end + perp;

      if (_pointInQuad(mouseWorldPosition, [p1, p2, p3, p4])) {
        return j;
      }
    }
    return null;
  }

  bool _pointInQuad(Vector2 p, List<Vector2> quad) {
    assert(quad.length == 4);
    int sign(Vector2 a, Vector2 b, Vector2 c) {
      return ((a.x - c.x) * (b.y - c.y) - (b.x - c.x) * (a.y - c.y)).sign
          .toInt();
    }

    final s1 = sign(p, quad[0], quad[1]);
    final s2 = sign(p, quad[1], quad[2]);
    final s3 = sign(p, quad[2], quad[3]);
    final s4 = sign(p, quad[3], quad[0]);

    return (s1 == s2 && s2 == s3 && s3 == s4);
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

  void Function(ForceGraphNode)? _onTap;

  set onTap(void Function(ForceGraphNode)? onTap) => _onTap = onTap;

  final __onSelectionChangeds = <void Function(List<ForceGraphNode>)>[];

  void _onSelectionChanged() {
    final s = _nodes.values.where((node) => node.selected).toList();
    for (final f in __onSelectionChangeds) {
      f(s);
    }
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

  void _clear() {
    for (final node in _nodes.values) {
      world.destroyBody(node.body);
    }

    _selectedNodeIds.clear();
    _joints.clear();
    _nodes.clear();
    _onSelectionChanged();
  }

  @override
  void dispose() {
    _scheduleAutoMove?.cancel();
    _graphBuilder.stop();
    super.dispose();
    disposeTicker();
    _clear();
    world.clearForces();
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
    return _completer!.future.whenComplete(() => null);
  }

  ForceDirectedGraphBuilder _graphBuilder;

  double? nodeHiddenOpacity;

  double? edgeHiddenOpacity;

  Color? edgeHightlightColor;

  List<ForceGraphNode> get selectedNodes {
    return [for (final id in _selectedNodeIds) _nodes[id]!];
  }

  Future<void> _loadData(List<ForceGraphNodeData> nodes) async {
    final worldSize = viewportController.worldSize;
    await _graphBuilder.performLayout(nodes, worldSize, (progress) {
      _loadingProgressStep = progress;
      notifyListeners();
    });

    for (final e in _graphBuilder.nodes.entries) {
      final body = ForceGraphNode._fromForceGraphNodeData(
        e.key,
        this,
        position: e.value,
        linearDamping: 2.5,
        enableNodesAutoMove: enableNodesAutoMove,
      );
      _nodes[e.key.id] = body;
    }
    double minSpacing = double.infinity;
    for (final edge in _graphBuilder.edges) {
      try {
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
    final shape = CircleShape(radius: minSpacing / 2);
    for (final node in _nodes.values) {
      node.body.createFixtureFromShape(shape);
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
  bool get isPanning => _controlKeyPressed;
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
      ..maxForce = body.mass * 60
      ..dampingRatio = 1;
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

  bool get isPhysicallyHovering => isHovering && !_programaticalHover;

  bool _programaticalHover = false;

  bool get canAutoMove =>
      isHovering && !isDraggingNode && !isPanning && !isSelecting;

  void hoverNode(
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
        final node = _nodes[nodeID]!;
        node.hovered = true;
        if (animateToCenter) {
          node._animateCenter();
        }
      }
      _programaticalHover = programatical;
      $_hoveredNodeID = nodeID;
    }
  }

  int? $_hoveredEdgeID;

  ForceGraphEdge? get hoveredEdge => _joints[$_hoveredEdgeID];

  void hoverEdge(int? edgeID, {bool programatical = true}) {
    if (edgeID != $_hoveredEdgeID) {
      if ($_hoveredEdgeID != null) {
        final edge = _joints[$_hoveredEdgeID]!;
        edge.hovered = false;
      }
      if (edgeID != null) {
        final edge = _joints[edgeID]!;
        edge.hovered = true;
      }
      _programaticalHover = programatical;
      $_hoveredEdgeID = edgeID;
    }
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
    } else if (!isPanning) {
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

  void onKeyEvent(KeyEvent event) {
    final ctrlPressed = _controlKeyPressed;
    const factor = 10.0;
    switch (event.physicalKey) {
      case PhysicalKeyboardKey.arrowUp:
        if (ctrlPressed) {
          viewportController.zoomIn();
        } else {
          viewportController.moveBy(Offset(0, factor));
        }
        break;
      case PhysicalKeyboardKey.arrowDown:
        if (ctrlPressed) {
          viewportController.zoomOut();
        } else {
          viewportController.moveBy(Offset(0, -factor));
        }
        break;
      case PhysicalKeyboardKey.arrowLeft:
        viewportController.moveBy(Offset(factor, 0));
        break;
      case PhysicalKeyboardKey.arrowRight:
        viewportController.moveBy(Offset(-factor, 0));
        break;
    }
  }

  void updateHover(Offset? position) {
    _scheduleAutoMove?.cancel();

    _hoverPosition = position;
    if (position != null) {
      final worldPos = viewportController.screenToWorld(position);
      final node = findBodyAt(worldPos);
      hoverNode(node?.iD, programatical: false);

      final joint = findJointAt(worldPos);
      hoverEdge(joint?.data.iD, programatical: false);
      _updateAutoMoveStatus();
    }
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
    if (zoom == this.zoom) return;
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

  String get iD => data.id;

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
      throw 'Invalid position for node ${node.id}: $position';
    }
    final world = controller.world;
    final nodeDef = BodyDef(type: BodyType.dynamic, position: position);

    nodeDef.userData = node;

    final body = world.createBody(nodeDef);

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
    _controller._onTap?.call(this);
    selected = !selected;
    if (selected) {
      _animateCenter();
    }
  }

  bool hovered = false;

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
        if (_controller._selectedNodeIds.isEmpty) {
          for (final node in _controller._nodes.values) {
            node._opacity = _controller.nodeHiddenOpacity ?? 0.8;
          }
        }
        if (_controller._selectedNodeIds.add(iD)) {
          final selectionCount = _controller._selectedNodeIds.length;
          if (_controller.maxSelection != null &&
              selectionCount >= _controller.maxSelection!) {
            _controller._selectedNodeIds.remove(
              _controller._selectedNodeIds.first,
            );
          }
        }

        for (final edge in data.edges) {
          if (edge.target == iD) {
            _controller._nodes[edge.source]!._opacity = 1;
          } else if (edge.source == iD) {
            _controller._nodes[edge.target]!._opacity = 1;
          }
        }
        _opacity = 1;
      } else {
        _controller._selectedNodeIds.remove(iD);
        if (_controller._selectedNodeIds.isNotEmpty) {
          _opacity = _controller.nodeHiddenOpacity ?? 0.8;
        } else {
          for (final node in _controller._nodes.values) {
            node._opacity = 1;
          }
        }
      }
      _controller._onSelectionChanged();
    }
  }

  void draw(Canvas canvas, BuildContext context) {
    final style = data.style.fromContext(context);
    final pos = position.toOffset();
    final paint = Paint()..color = style.color ?? Colors.blue;

    double radius = data.radius;

    if (hovered) {
      radius *= 1.5;
    }
    final bool selected = this.selected;
    bool hasBorder = selected || style.colorBorder != null;
    if (selected) {
      if (style.selectedColor != null) {
        paint.color = style.selectedColor!;
      }
    } else if (hovered) {
      if (style.hoverColor != null) {
        paint.color = style.hoverColor!;
      }
    }
    if (hasBorder) {
      final newPaint = Paint.from(paint);
      newPaint.strokeWidth = style.borderWidth;
      newPaint.style = PaintingStyle.stroke;
      newPaint.color =
          (selected ? style.selectedColorBorder : style.colorBorder) ??
          Colors.redAccent;

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
    final bodyAID = (joint.bodyA.userData as ForceGraphNodeData).id;
    final bodyBID = (joint.bodyB.userData as ForceGraphNodeData).id;
    final iD = ForceGraphEdgeData.getID(bodyAID, bodyBID);
    controller._joints.remove(iD);
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
