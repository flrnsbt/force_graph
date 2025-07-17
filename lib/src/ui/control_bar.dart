import 'dart:async';

import 'package:flutter/material.dart';
import 'package:force_graph/src/controller.dart';
export 'package:force_graph/src/ui/zoom_widget.dart';
import 'package:force_graph/src/ui/zoom_widget.dart';

class ControlBar extends StatefulWidget {
  const ControlBar({
    super.key,
    required this.controller,
    required this.controlBarAlignment,
    required this.controlBarDirection,
    required this.controlBarSpacing,
    this.enableAutoHide = true,
    this.backgroundColor,
    this.foregroundColor,
    this.enableOpacityChange = true,
    this.dividerColor,
    this.dividerSpacing,
    this.borderColor,
  });
  final ForceGraphController controller;
  final Alignment controlBarAlignment;
  final Axis controlBarDirection;
  final EdgeInsets controlBarSpacing;
  final bool enableAutoHide;
  final bool enableOpacityChange;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? dividerColor;
  final double? dividerSpacing;
  final Color? borderColor;

  @override
  State<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<ControlBar> {
  bool _opaque = true;

  bool _hidden = false;

  Timer? _scheduleDisable;
  Timer? _scheduleHide;
  @override
  void dispose() {
    _scheduleHide?.cancel();
    _scheduleDisable?.cancel();
    super.dispose();
  }

  void _scheduleDisableControlBar([
    Duration duration = const Duration(seconds: 1),
  ]) {
    if (!widget.enableOpacityChange) return;

    _scheduleDisable?.cancel();
    _scheduleDisable = Timer(duration, () {
      if (mounted && _opaque) {
        setState(() {
          _opaque = false;
        });
      }
    });
  }

  void _scheduleHideControlBar([
    Duration duration = const Duration(seconds: 1),
  ]) {
    if (!widget.enableAutoHide) return;
    _scheduleHide?.cancel();
    _scheduleHide = Timer(duration, () {
      if (mounted && !_hidden) {
        setState(() {
          _hidden = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewportController = widget.controller.viewportController;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foregroundColor =
        widget.foregroundColor ?? (isDark ? Colors.white : Colors.grey[700])!;
    final dividerColor =
        widget.dividerColor ?? foregroundColor.withValues(alpha: 0.25);
    final backgroundColor =
        widget.backgroundColor ??
        (isDark ? Colors.grey[900] : Colors.grey[300]);
    final bool isHorizontal = widget.controlBarDirection == Axis.horizontal;
    final divider = isHorizontal
        ? VerticalDivider(color: dividerColor, width: widget.dividerSpacing)
        : Divider(color: dividerColor, height: widget.dividerSpacing);
    final hideOffset = _getHideOffset(widget.controlBarAlignment);
    return MouseRegion(
      onEnter: (event) {
        _scheduleDisable?.cancel();
        if (!_opaque) {
          setState(() {
            _opaque = true;
          });
        }
      },
      onExit: (event) {
        _scheduleDisableControlBar();
      },

      child: TapRegion(
        onTapUpOutside: (event) {
          _scheduleDisable?.cancel();
          _scheduleHide?.cancel();
          if (widget.enableOpacityChange) {
            _scheduleDisable = Timer(const Duration(milliseconds: 500), () {
              if (mounted && !_opaque) {
                setState(() {
                  _opaque = true;
                });
              }
            });
          }
          if (widget.enableAutoHide) {
            _scheduleHide = Timer(const Duration(milliseconds: 500), () {
              if (mounted && _hidden) {
                setState(() {
                  _hidden = false;
                });
              }
            });
          }
        },
        onTapOutside: (event) {
          _scheduleDisableControlBar(const Duration(milliseconds: 100));
          _scheduleHideControlBar(const Duration(milliseconds: 100));
        },
        child: AnimatedSlide(
          offset: _hidden ? hideOffset : const Offset(0, 0),
          duration: const Duration(milliseconds: 200),
          child: Opacity(
            opacity: _opaque ? 1 : 0.4,
            child: Container(
              width: isHorizontal ? double.infinity : 50,
              height: isHorizontal ? 50 : double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(
                  color: widget.borderColor ?? dividerColor,
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Flex(
                crossAxisAlignment: CrossAxisAlignment.center,
                direction: widget.controlBarDirection,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Reload',
                    icon: const Icon(Icons.refresh),
                    color: foregroundColor,
                    onPressed: () {
                      widget.controller.reload();
                    },
                  ),

                  divider,
                  IconButton(
                    padding: EdgeInsets.zero,

                    tooltip: 'Recenter',
                    icon: const Icon(Icons.center_focus_strong),
                    color: foregroundColor,
                    onPressed: () {
                      widget.controller.recenter(true);
                    },
                  ),
                  divider,
                  Flexible(
                    child: ZoomControllerWidget(
                      foregroundColor: foregroundColor,
                      direction: widget.controlBarDirection,
                      zoom: viewportController.zoom,
                      minZoom: viewportController.minZoom,
                      maxZoom: viewportController.maxZoom,
                      onZoomChanged: (value, fromSlider, fromLongPress) {
                        if (fromSlider) {
                          viewportController.applyZoom(
                            value,
                            animationDuration: Duration.zero,
                          );
                        } else if (fromLongPress) {
                          viewportController.applyZoom(
                            value,
                            unboundedProgressFactor: 0.2,
                            animationDuration: Duration(milliseconds: 1500),
                          );
                        } else {
                          viewportController.applyZoom(
                            value,
                            animationDuration: Duration(milliseconds: 200),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _getHideOffset(
    Alignment controlBarAlignment, [
    double distance = 1.2,
  ]) {
    if (controlBarAlignment.y.abs() > controlBarAlignment.x.abs()) {
      return Offset(0, distance * controlBarAlignment.y.sign);
    } else {
      return Offset(distance * controlBarAlignment.x.sign, 0);
    }
  }
}
