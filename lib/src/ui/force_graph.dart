import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:force_graph/src/controller.dart';
import 'package:force_graph/src/ui/control_bar.dart';
import 'package:force_graph/src/ui/tooltip.dart';
import 'package:forge2d/forge2d.dart';

class ForceGraphWidget extends StatefulWidget {
  const ForceGraphWidget({
    super.key,
    required this.controller,
    this.showControlBar = true,
    this.controlBarSpacing = const EdgeInsets.all(8),
    this.controlBarAlignment,
    this.controlBarDirection,
    this.nodeTooltipBuilder,
    this.edgeTooltipBuilder,
    this.nodeTooltipSpacing = 15,
    this.offsetUpdater,
    this.edgeTooltipSpacing = 20,
    this.customControlBarBuilder,
    this.focusNode,
    this.onSelectionChanged,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    this.loadingBuilder = _kDefaultLoadingBuilder,
  }) : errorBuilder = errorBuilder ?? _kDefaultErrorBuilder;
  final ForceGraphController controller;
  final Axis? controlBarDirection;
  final bool showControlBar;
  final Alignment? controlBarAlignment;
  final EdgeInsets controlBarSpacing;
  final Widget Function(BuildContext context, ForceGraphNode node)?
  nodeTooltipBuilder;
  final Offset Function(Offset position)? offsetUpdater;
  final Widget Function(BuildContext context, ForceGraphEdge edge)?
  edgeTooltipBuilder;
  final Widget Function(BuildContext context, ForceGraphController controller)?
  customControlBarBuilder;
  final double nodeTooltipSpacing;
  final double edgeTooltipSpacing;
  final FocusNode? focusNode;
  final void Function(List<ForceGraphNode>)? onSelectionChanged;
  final Widget Function(
    BuildContext context,
    int progressStep,
    int total,
    double progress,
  )?
  loadingBuilder;
  final Widget Function(BuildContext context, Object error) errorBuilder;

  static Widget _kDefaultLoadingBuilder(
    BuildContext context,
    int progressStep,
    int total,
    double progress,
  ) => SafeArea(
    child: Column(
      children: [
        if (progress.isFinite) LinearProgressIndicator(value: progress),
        Expanded(child: Center(child: Text('Loading...'))),
      ],
    ),
  );

  static Widget _kDefaultErrorBuilder(BuildContext context, Object error) =>
      Center(child: Text(error.toString()));

  @override
  State<ForceGraphWidget> createState() => _GraphPhysicsViewState();
}

class _GraphPhysicsViewState extends State<ForceGraphWidget>
    with TickerProviderStateMixin {
  World get world => widget.controller.world;

  ViewportController get viewportController =>
      widget.controller.viewportController;

  Body get ground => widget.controller.ground;

  late final _focusNode = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.initWorld(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.addListener(_refreshUI);
    });
    if (widget.onSelectionChanged != null) {
      widget.controller.addOnSelectionChangedListener(
        widget.onSelectionChanged!,
      );
    }
  }

  void _refreshUI() {
    if (mounted) {
      setState(() {});
    }
  }

  Vector2 _screenToWorld(Offset pos) {
    return viewportController.screenToWorld(pos);
  }

  void _tapUp(Offset screenPos) {
    _scheduleAutoMove?.cancel();
    final worldPos = _screenToWorld(screenPos);
    final node = widget.controller.findBodyAt(worldPos);
    if (node != null) {
      node.onTap();
    } else {
      widget.controller.clearSelection();
    }
  }

  bool isDraggingNode = false;
  bool isPanning = false;
  Body? draggedBody;
  MouseJoint? mouseJoint;

  void onScaleStart(ScaleStartDetails details) {
    _scheduleAutoMove?.cancel();

    final worldTouch = viewportController.screenToWorld(details.focalPoint);
    final node = widget.controller.findBodyAt(worldTouch);

    if (node != null) {
      startDragging(node.body, worldTouch);
      isDraggingNode = true;
    } else {
      isPanning = true;
    }
    _updateAutoMoveStatus();
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    _scheduleAutoMove?.cancel();

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
        focalPoint: details.focalPoint,
        animationDuration: Duration.zero,
      );
    } else {
      if (isDraggingNode && mouseJoint != null) {
        final worldTarget = viewportController.screenToWorld(
          details.focalPoint,
        );
        mouseJoint?.setTarget(worldTarget);
      } else if (isPanning) {
        viewportController.addPan(details.focalPointDelta);
      }
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    _scheduleAutoMove?.cancel();

    if (isDraggingNode) {
      stopDragging();
    }
    isDraggingNode = false;
    isPanning = false;
    _updateAutoMoveStatus();
  }

  void startDragging(Body body, Vector2 targetWorld) {
    stopDragging();
    final mouseJointDef = MouseJointDef()
      ..bodyA = ground
      ..bodyB = body
      ..target.setFrom(targetWorld)
      ..maxForce = body.mass * 60
      ..dampingRatio = 1;
    mouseJoint = MouseJoint(mouseJointDef);
    world.createJoint(mouseJoint!);

    draggedBody = body;
  }

  void stopDragging() {
    if (mouseJoint != null) {
      world.destroyJoint(mouseJoint!);
      mouseJoint = null;
      draggedBody = null;
    }
  }

  ForceGraphNode? _hoveredNode;
  ForceGraphEdge? _hoveredJoint;

  Offset? _hoverPos;

  void _updateHover(Offset position) {
    _scheduleAutoMove?.cancel();

    _hoverPos = position;
    final worldPos = _screenToWorld(position);
    final node = widget.controller.findBodyAt(worldPos);
    if (_hoveredNode != null && node != _hoveredNode) {
      _hoveredNode!.hovered = false;
      _hoveredNode = null;
    }
    if (node != null) {
      node.hovered = true;
      _hoveredNode = node;
    }

    final joint = widget.controller.findJointAt(worldPos);
    if (_hoveredJoint != null && joint != _hoveredJoint) {
      _hoveredJoint!.hovered = false;
      _hoveredJoint = null;
    }
    if (joint != null) {
      joint.hovered = true;
      _hoveredJoint = joint;
    }
    _updateAutoMoveStatus();
  }

  MouseCursor getCursor() {
    if (isDraggingNode) {
      return SystemMouseCursors.grabbing;
    }
    if (_hoveredNode != null) {
      return SystemMouseCursors.grab;
    }
    return SystemMouseCursors.basic;
  }

  static bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  void _onKeyEvent(KeyEvent event) {
    final ctrlPressed = _isMac
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
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

  Timer? _scheduleAutoMove;

  @override
  Widget build(BuildContext context) {
    final bool isReady = widget.controller.isReady;
    final error = widget.controller.error;
    final bool hasError = error != null;
    final nodes = widget.controller.nodes;
    final joints = widget.controller.joints;
    Widget child = ClipRect(
      child: CustomPaint(
        painter: GraphPainter(
          nodes,
          joints,
          (size) {
            widget.controller.updateCanvasSize(size);
          },
          (canvas) {
            final zoomScale =
                viewportController.scale * viewportController.zoom;
            final matrix = Matrix4.identity()
              ..translate(
                viewportController.panOffset.dx,
                viewportController.panOffset.dy,
              )
              ..scale(zoomScale, zoomScale);
            canvas.transform(matrix.storage);
          },
        ),
      ),
    );
    if (isReady) {
      child = KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          cursor: getCursor(),
          onExit: (event) {
            _hoverPos = null;
            for (final node in nodes) {
              node.hovered = false;
            }
            for (final joint in joints) {
              joint.hovered = false;
            }
          },
          onEnter: (event) {
            _updateHover(event.localPosition);
          },
          onHover: (event) {
            _updateHover(event.localPosition);
          },
          child: Listener(
            onPointerSignal: (event) {
              _scheduleAutoMove?.cancel();
              if (event is PointerScrollEvent) {
                if (HardwareKeyboard.instance.isControlPressed) {
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
            },
            child: GestureDetector(
              supportedDevices: {...PointerDeviceKind.values},
              onTapUp: (details) => _tapUp(details.localPosition),
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onScaleEnd: onScaleEnd,

              child: child,
            ),
          ),
        ),
      );
    }

    final bool isLoading = widget.controller.isLoading;

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: isReady ? 1 : 0.01, child: child),
        if (isReady)
          ..._buildOverlays()
        else if (hasError)
          Positioned.fill(child: widget.errorBuilder(context, error))
        else if (isLoading && widget.loadingBuilder != null)
          Positioned.fill(
            child: widget.loadingBuilder!(
              context,
              widget.controller.loadingProgressStep,
              widget.controller.loadingTotalStep,
              widget.controller.loadingProgress,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildOverlays() {
    final size = viewportController.screenSize;
    final bool moreHeightThanWidth = size.height > size.width;
    final smallScreen = size.width < 600;
    final controlBarAlignment =
        widget.controlBarAlignment ??
        (moreHeightThanWidth ? Alignment.bottomCenter : Alignment.bottomRight);
    final direction =
        widget.controlBarDirection ??
        (moreHeightThanWidth ? Axis.horizontal : Axis.vertical);
    final bool enableAutoHide = smallScreen;
    return [
      _buildTooltips(),
      if (widget.showControlBar)
        Align(
          alignment: controlBarAlignment,
          child: SafeArea(
            minimum: widget.controlBarSpacing,
            child: Material(
              type: MaterialType.transparency,
              child:
                  widget.customControlBarBuilder?.call(
                    context,
                    widget.controller,
                  ) ??
                  ControlBar(
                    enableAutoHide: enableAutoHide,
                    controller: widget.controller,
                    controlBarSpacing: widget.controlBarSpacing,
                    controlBarAlignment: controlBarAlignment,
                    controlBarDirection: direction,
                  ),
            ),
          ),
        ),
    ];
  }

  @override
  void dispose() {
    if (widget.onSelectionChanged != null) {
      widget.controller.removeOnSelectionChangedListener(
        widget.onSelectionChanged!,
      );
    }
    _scheduleAutoMove?.cancel();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    widget.controller.disposeTicker();
    widget.controller.removeListener(_refreshUI);

    super.dispose();
  }

  Widget _buildTooltips() {
    final edge = _hoveredJoint;
    if (edge != null && widget.edgeTooltipBuilder != null) {
      // final positionBodyA = viewportController.worldToScreen(
      //   edge.joint.anchorA,
      // );
      // final positionBodyB = viewportController.worldToScreen(
      //   edge.joint.anchorB,
      // );
      // final offset = (positionBodyA + positionBodyB) / 2;
      Offset? offset = _hoverPos;
      if (offset == null) {
        return const SizedBox.shrink();
      }
      if (widget.offsetUpdater != null) {
        offset = widget.offsetUpdater!(offset);
      }
      return TooltipPositionedWidget(
        target: offset,
        offset: Offset(0, widget.edgeTooltipSpacing),
        child: Material(
          type: MaterialType.transparency,
          child: widget.edgeTooltipBuilder!(context, edge),
        ),
      );
    }
    final node = _hoveredNode;
    if (node != null && widget.nodeTooltipBuilder != null) {
      Offset position = viewportController.worldToScreen(node.position);
      if (widget.offsetUpdater != null) {
        position = widget.offsetUpdater!(position);
      }
      return TooltipPositionedWidget(
        target: position,
        offset: Offset(0, widget.nodeTooltipSpacing),
        child: Material(
          type: MaterialType.transparency,
          child: widget.nodeTooltipBuilder!(context, node),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _updateAutoMoveStatus() {
    if (!widget.controller.enableNodesAutoMove) {
      return;
    }
    final canAutoMove =
        _hoveredJoint == null &&
        _hoveredNode == null &&
        !isDraggingNode &&
        !isPanning;
    if (canAutoMove) {
      _scheduleAutoMove = Timer(const Duration(milliseconds: 500), () {
        widget.controller.startNodesAutoMove();
      });
    } else {
      _scheduleAutoMove?.cancel();
      widget.controller.stopNodesAutoMove();
    }
  }
}

class GraphPainter extends CustomPainter {
  final Iterable<ForceGraphNode> nodes;
  final Iterable<ForceGraphEdge> joints;
  final ValueChanged<Size> onCanvasSizeChanged;
  final void Function(Canvas canvas) transform;

  GraphPainter(
    this.nodes,
    this.joints,
    this.onCanvasSizeChanged,
    this.transform,
  );

  Size? _oldSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (_oldSize != size) {
      _oldSize = size;
      onCanvasSizeChanged(size);
    }
    transform(canvas);

    for (final joint in joints) {
      joint.draw(canvas);
    }

    for (final node in nodes) {
      node.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
