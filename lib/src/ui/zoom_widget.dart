import 'package:flutter/material.dart';

class ZoomControllerWidget extends StatelessWidget {
  final double zoom;
  final void Function(double zoom, bool fromSlider, bool fromLongPress)
  onZoomChanged;
  final double minZoom;
  final double maxZoom;
  final double step;
  final Axis direction;
  final Color? foregroundColor;
  final ButtonStyle? buttonStyle;
  final EdgeInsets buttonPadding;
  final BoxConstraints? buttonConstraints;
  final double? buttonIconSize;
  final String zoomInTooltip;
  final String zoomOutTooltip;
  final double sliderSize;

  const ZoomControllerWidget({
    super.key,
    required this.zoom,
    required this.onZoomChanged,
    this.buttonConstraints,
    this.buttonPadding = EdgeInsets.zero,
    this.buttonStyle,
    this.minZoom = 0.1,
    this.buttonIconSize,
    this.maxZoom = 2.0,
    this.foregroundColor,
    this.step = 0.1,
    this.sliderSize = 200,
    this.zoomInTooltip = 'Zoom in',
    this.zoomOutTooltip = 'Zoom out',
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    Widget slider = Slider(
      padding: EdgeInsets.zero,
      value: zoom.clamp(minZoom, maxZoom),
      min: minZoom,
      max: maxZoom,
      divisions: ((maxZoom - minZoom) / step).round(),
      // label: zoom.toStringAsFixed(2),
      onChanged: (value) => onZoomChanged(value, true, false),
    );
    if (direction == Axis.vertical) {
      slider = SizedBox(
        height: sliderSize,
        child: RotatedBox(quarterTurns: -1, child: slider),
      );
    } else {
      slider = Flexible(
        child: SizedBox(width: sliderSize, child: slider),
      );
    }
    List<Widget> children = [
      GestureDetector(
        onLongPressStart: (details) {
          onZoomChanged(maxZoom, false, true);
        },
        onLongPressEnd: (details) {
          onZoomChanged(zoom, false, true);
        },
        child: IconButton(
          padding: buttonPadding,
          style: buttonStyle,
          constraints: buttonConstraints,
          iconSize: buttonIconSize,
          tooltip: zoomInTooltip,
          icon: const Icon(Icons.zoom_in),
          color: foregroundColor,

          onPressed: () {
            final newZoom = (zoom + step).clamp(minZoom, maxZoom);
            onZoomChanged(newZoom, false, false);
          },
        ),
      ),
      slider,
      GestureDetector(
        onLongPressStart: (details) {
          onZoomChanged(minZoom, false, true);
        },
        onLongPressEnd: (details) {
          onZoomChanged(zoom, false, true);
        },
        child: IconButton(
          padding: buttonPadding,
          style: buttonStyle,
          constraints: buttonConstraints,
          iconSize: buttonIconSize,
          tooltip: zoomOutTooltip,
          icon: const Icon(Icons.zoom_out),
          color: foregroundColor,

          onPressed: () {
            final newZoom = (zoom - step).clamp(minZoom, maxZoom);
            onZoomChanged(newZoom, false, false);
          },
        ),
      ),
    ];
    if (direction == Axis.horizontal) {
      children = children.reversed.toList();
    }
    return Flex(
      spacing: 6,
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
