import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
    this.defaultControlBarAutoHide,
    this.defaultControlBarOpacityChangesEnabled = true,
    this.selectionOverlayColor,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    this.loadingBuilder = _kDefaultLoadingBuilder,
  }) : errorBuilder = errorBuilder ?? _kDefaultErrorBuilder;
  final Color? selectionOverlayColor;
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
    int? progressStep,
    int? total,
    double? progress,
  )?
  loadingBuilder;
  final bool? defaultControlBarAutoHide;
  final bool defaultControlBarOpacityChangesEnabled;
  final Widget Function(BuildContext context, Object error) errorBuilder;

  static Widget _kDefaultLoadingBuilder(
    BuildContext context,
    int? progressStep,
    int? total,
    double? progress,
  ) => SafeArea(
    child: Column(
      children: [
        if (progress == null || progress.isFinite)
          LinearProgressIndicator(value: progress),
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
    final worldPos = _screenToWorld(screenPos);
    final node = widget.controller.findBodyAt(worldPos);
    if (node != null) {
      node.onTap();
    } else {
      widget.controller.clearSelection();
    }
  }

  MouseCursor getCursor() {
    if (widget.controller.isSelecting) {
      return SystemMouseCursors.click;
    }
    if (widget.controller.isPanning) {
      return SystemMouseCursors.move;
    }
    if (widget.controller.isDraggingNode) {
      return SystemMouseCursors.grabbing;
    }
    if (widget.controller.isPhysicallyHovering) {
      return SystemMouseCursors.grab;
    }
    return SystemMouseCursors.basic;
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = widget.controller.isReady;
    final error = widget.controller.error;
    final bool hasError = error != null;
    final nodes = widget.controller.nodes;
    final joints = widget.controller.joints;
    Widget child = ClipRect(
      child: CustomPaint(
        foregroundPainter: GraphForegroundPainter(
          widget.controller.screenSelectionRect,
          widget.selectionOverlayColor,
        ),
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
          context,
        ),
      ),
    );
    if (isReady) {
      child = KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: widget.controller.onKeyEvent,
        child: MouseRegion(
          cursor: getCursor(),
          onExit: (event) {
            widget.controller.updateHover(null);
            for (final node in nodes) {
              node.hovered = false;
            }
            for (final joint in joints) {
              joint.hovered = false;
            }
          },
          onEnter: (event) {
            widget.controller.updateHover(event.localPosition);
          },
          onHover: (event) {
            widget.controller.updateHover(event.localPosition);
          },
          child: Listener(
            onPointerSignal: widget.controller.onPointerSignal,
            child: GestureDetector(
              supportedDevices: {...PointerDeviceKind.values},
              onTapUp: (details) => _tapUp(details.localPosition),
              onScaleStart: widget.controller.onScaleStart,
              onScaleUpdate: widget.controller.onScaleUpdate,
              onScaleEnd: widget.controller.onScaleEnd,

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
    final bool enableAutoHide = widget.defaultControlBarAutoHide ?? smallScreen;
    final bool opacityChanges = widget.defaultControlBarOpacityChangesEnabled;
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
                    enableOpacityChange: opacityChanges,
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
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    widget.controller.disposeTicker();
    widget.controller.removeListener(_refreshUI);

    super.dispose();
  }

  Widget _buildTooltips() {
    final edge = widget.controller.hoveredEdge;
    if (edge != null && widget.edgeTooltipBuilder != null) {
      // final positionBodyA = viewportController.worldToScreen(
      //   edge.joint.anchorA,
      // );
      // final positionBodyB = viewportController.worldToScreen(
      //   edge.joint.anchorB,
      // );
      // final offset = (positionBodyA + positionBodyB) / 2;
      Offset? offset = widget.controller.hoverPosition;
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
    final node = widget.controller.hoveredNode;
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
}

class GraphForegroundPainter extends CustomPainter {
  final Rect? selectionRect;
  final Color? selectionColor;

  GraphForegroundPainter(this.selectionRect, this.selectionColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect != null) {
      final paint = Paint()
        ..color = selectionColor ?? Colors.blue.withValues(alpha: 0.1);
      canvas.drawRect(selectionRect!, paint);
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = selectionColor?.withValues(alpha: 1) ?? Colors.blue
        ..strokeWidth = 0.8;
      canvas.drawRect(selectionRect!, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphForegroundPainter oldDelegate) {
    return selectionRect != oldDelegate.selectionRect ||
        selectionColor != oldDelegate.selectionColor;
  }
}

class GraphPainter extends CustomPainter {
  final Iterable<ForceGraphNode> nodes;
  final Iterable<ForceGraphEdge> joints;
  final ValueChanged<Size> onCanvasSizeChanged;
  final void Function(Canvas canvas) transform;
  final BuildContext context;

  GraphPainter(
    this.nodes,
    this.joints,
    this.onCanvasSizeChanged,
    this.transform,
    this.context,
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
      joint.draw(canvas, context);
    }

    for (final node in nodes) {
      node.draw(canvas, context);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
