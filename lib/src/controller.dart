import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  ForceGraphController({
    List<ForceGraphNodeData> nodes = const [],
    this.enableNodesAutoMove = false, // experimental
    int maxSelection = 1,
    this.uniformEdgeWeight = false,
    AlgorithmType algorithmType = AlgorithmType.mds,
    int forceDirectedGraphLayoutIteration = 800,
    double forceDirectedGraphLayoutRepulse = 10,
    double forceDirectedGraphLayoutAttraction = 0.1,
    this.enableAutoCenterOnNodeSelection = true,
    double scale = 25,
    double initialZoom = ViewportController.minZoom,
  }) : maxSelected = maxSelection,
       viewportController = ViewportController(zoom: initialZoom, scale: scale),
       _graphBuilder = ForceDirectedGraphBuilder(
         iterations: forceDirectedGraphLayoutIteration,
         repulsion: forceDirectedGraphLayoutRepulse,
         algorithmType: algorithmType,
         attraction: forceDirectedGraphLayoutAttraction,
       ) {
    world.destroyListener = _DestroyListener(this);
    // world.setContactListener(_ContactListener(this));
    if (nodes.isNotEmpty) {
      _rawData.addAll(nodes);
    }
  }

  void updateForceDirectedGraphLayoutRepulse(double value) {
    _graphBuilder.repulsion = value;
  }

  void updateForceDirectedGraphLayoutAttraction(double value) {
    _graphBuilder.attraction = value;
  }

  void updateAlgorithmType(AlgorithmType algorithmType) {
    _graphBuilder.algorithmType = algorithmType;
  }

  int maxSelected = 1;

  // final _collidingNodes = <String>{};

  // int get nbOfCollisions => _collidingNodes.length;

  void recenter([bool adjustZoom = true]) {
    double minX = double.maxFinite;
    double minY = double.maxFinite;
    double maxX = -double.maxFinite;
    double maxY = -double.maxFinite;
    for (final node in _nodes) {
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
    _init();
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
    if (viewportController.hasSize) {
      _ticker!.start();
    }
  }

  int _elapsedMs = 0;

  bool _isReady = false;

  bool get isReady => _isReady;

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
    for (final node in _nodes) {
      node.update(dt, eMs);
    }

    notifyListeners();
  }

  void clearNodeForces() {
    for (final node in _nodes) {
      node.body.clearForces();
    }
  }

  void stopNodesAutoMove() {
    if (!enableNodesAutoMove) return;
    for (final node in _nodes) {
      node.enableAutoMove = false;
    }
  }

  // void _ensureNoCollision() {
  //   final s = DateTime.now();
  //   Duration lastDuration = Duration.zero;
  //   do {
  //     final d = DateTime.now().difference(s);
  //     final dt = d - lastDuration;
  //     print('Collisions: $nbOfCollisions');

  //     if (dt.inMilliseconds < 16) {
  //       continue;
  //     }
  //     lastDuration = d;
  //     _stepWorld(d);
  //   } while (nbOfCollisions > 0);
  // }

  Future<void> _init({bool notifyReadyStatusChange = true}) async {
    try {
      _clear();
      _error = null;
      _ticker?.stop();
      _loadingProgressStep = 0;
      _loadingTotalStep = _graphBuilder.iterations;
      if (_isReady) {
        _isReady = false;
        if (notifyReadyStatusChange) {
          notifyListeners();
        }
      }
      if (_rawData.isNotEmpty) {
        await _loadData(_rawData);
        _isReady = true;
        _isReadyCallback();
        _ticker?.start();
      }
    } catch (e) {
      _error = e;
    }
  }

  Object? _error;
  Object? get error => _error;

  int _loadingProgressStep = 0;
  int get loadingProgressStep => _loadingProgressStep;

  int _loadingTotalStep = 0;
  int get loadingTotalStep => _loadingTotalStep;

  double get loadingProgress => _loadingProgressStep / _loadingTotalStep;

  void reload() {
    _init();
  }

  ForceGraphNode? findBodyAt(Vector2 worldPoint) {
    for (final node in _nodes) {
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

  final List<ForceGraphNode> _nodes = [];
  final List<ForceGraphEdge> _joints = [];

  UnmodifiableListView<ForceGraphNode> get nodes =>
      UnmodifiableListView(_nodes);

  UnmodifiableListView<ForceGraphEdge> get joints =>
      UnmodifiableListView(_joints);

  void clearSelection() {
    for (final node in _nodes) {
      node.selected = false;
    }
  }

  void Function(ForceGraphNode)? _onTap;

  set onTap(void Function(ForceGraphNode)? onTap) => _onTap = onTap;

  final __onSelectionChangeds = <void Function(List<ForceGraphNode>)>[];

  void _onSelectionChanged() {
    final s = _nodes.where((node) => node.selected).toList();
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
    for (final node in _nodes) {
      world.destroyBody(node.body);
    }
    _joints.clear();
    _nodes.clear();
  }

  @override
  void dispose() {
    super.dispose();
    _ticker?.dispose();
    _clear();
    world.clearForces();
  }

  void loadDataFrom(
    List<ForceGraphNodeData> nodes, {
    bool notifyReadyStatusChange = true,
  }) {
    _rawData.clear();
    _rawData.addAll(nodes);
    _init(notifyReadyStatusChange: notifyReadyStatusChange);
  }

  final ForceDirectedGraphBuilder _graphBuilder;

  Future<void> _loadData(List<ForceGraphNodeData> nodes) async {
    if (!viewportController.hasSize) return;
    _clear();
    final worldSize = viewportController.worldSize;
    final layout = _graphBuilder;
    await layout.performLayout(nodes, worldSize, (progress) {
      _loadingProgressStep = progress;
      notifyListeners();
    });

    for (final e in layout.nodes.entries) {
      final body = ForceGraphNode._fromForceGraphNodeData(
        e.key,
        this,
        position: e.value,
        minimumSpacing: layout.minimumSpacing,
        linearDamping: 2.5,
        enableNodesAutoMove: enableNodesAutoMove,
      );
      _nodes.add(body);
    }

    for (final edge in layout.edges) {
      final (nodeA, nodeB) = _getBodyPair(edge);
      final jointDef = DistanceJointDef()
        ..initialize(nodeA, nodeB, nodeA.position, nodeB.position)
        ..frequencyHz = 2
        ..dampingRatio = 0.7;

      jointDef.userData = edge;
      final e = ForceGraphEdge(DistanceJoint(jointDef), edge, this);
      _joints.add(e);
      world.createJoint(e.joint);
    }
  }

  (Body nodeA, Body nodeB) _getBodyPair(ForceGraphEdgeData edge) {
    final nodeA = _nodes.firstWhere((n) => n.iD == edge.source);
    final nodeB = _nodes.firstWhere((n) => n.iD == edge.target);
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
    for (final node in _nodes) {
      node.enableAutoMove = true;
    }
  }

  void stop() {
    _ticker?.stop();
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
    this.zoom = 0.1,
    this.panOffset = Offset.zero,
    this.scale = 20.0,
  }) : initialZoom = zoom;

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

  static const double minZoom = 0.1;
  static const double maxZoom = 2.0;

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
    if (zoom < minZoom || zoom > maxZoom) return;
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
    Duration? duration = const Duration(milliseconds: 100),
  }) {
    multiplyZoom(1 + factor, animationDuration: duration);
  }

  void zoomOut({
    double factor = .1,
    Duration? duration = const Duration(milliseconds: 100),
  }) {
    multiplyZoom(1 - factor, animationDuration: duration);
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

  bool _highlight = false;
  bool _disable = false;
  bool get highlight => _highlight;
  bool get disable => _disable;

  ForceGraphEdge(this.joint, this.data, this._controller);

  void draw(Canvas canvas) {
    final p1 = joint.bodyA.position.toOffset();
    final p2 = joint.bodyB.position.toOffset();
    final paint = Paint();
    if (data.style.color != null) {
      paint.color = data.style.color!;
    }
    double weight = 0.5;
    if (!_controller.uniformEdgeWeight) {
      weight = data.weight;
    }

    weight /= _controller.viewportController.scale / 2;

    if (disable) {
      paint.color = paint.color.withValues(alpha: 0.05);
    } else {
      if (highlight) {
        paint.color = Colors.purpleAccent;
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
    double minimumSpacing = 0.4,
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

    final shape = CircleShape(radius: minimumSpacing);
    body.createFixture(FixtureDef(shape, friction: 0.1));
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

  bool _selected = false;

  bool get selected => _selected;

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
    if (_selected != value) {
      if (value) {
        int selectedCount = 0;
        for (final node in _controller.nodes) {
          if (node._selected) {
            selectedCount++;
          }

          if (selectedCount >= _controller.maxSelected) {
            node._selected = false;
          }

          node.disable = true;
        }

        for (final edge in _controller._joints) {
          final bool isTarget = edge.data.target == iD;
          final bool isSource = edge.data.source == iD;
          if (isTarget || isSource) {
            edge._highlight = true;
            edge._disable = false;
            if (isTarget) {
              _controller._nodes
                      .firstWhere((n) => n.data.id == edge.data.source)
                      ._opacity =
                  0.8;
            }
            if (isSource) {
              _controller._nodes
                      .firstWhere((n) => n.data.id == edge.data.target)
                      ._opacity =
                  0.8;
            }
          } else {
            edge._disable = true;
            edge._highlight = false;
          }
        }
        disable = false;
        _opacity = 1;
      } else {
        for (final edge in _controller.joints) {
          edge._highlight = false;
          edge._disable = false;
        }
        for (final node in _controller.nodes) {
          node._opacity = 1;
          node.disable = false;
        }
      }
      _selected = value;
      _controller._onSelectionChanged();
    }
  }

  void draw(Canvas canvas) {
    final pos = position.toOffset();
    final paint = Paint()..color = data.style.color ?? Colors.blue;

    double radius = 0.3;

    if (hovered) {
      radius *= 1.5;
    }
    if (_selected) {
      final newPaint = Paint.from(paint);
      newPaint.strokeWidth = 0.075;
      newPaint.style = PaintingStyle.stroke;
      newPaint.color = data.style.selectedColorBorder ?? Colors.redAccent;

      canvas.drawCircle(pos, radius, newPaint);
      if (data.style.selectedColor != null) {
        paint.color = data.style.selectedColor!;
      }
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

  bool _disable = false;

  set disable(bool value) {
    if (_disable != value) {
      _disable = value;
      if (_disable) {
        body.setMassData(MassData()..mass = 0);
        _opacity = 0.1;
      } else {
        body.setMassData(_mass);
        _opacity = 1;
      }
    }
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
    controller._joints.removeWhere((n) => identical(n.joint, joint));
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
