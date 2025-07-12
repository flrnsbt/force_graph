import 'package:flutter/material.dart';

class ZoomControllerWidget extends StatelessWidget {
  final double zoom;
  final void Function(double zoom, bool fromSlider, bool fromLongPress)
  onZoomChanged;
  final double minZoom;
  final double maxZoom;
  final double step;

  const ZoomControllerWidget({
    super.key,
    required this.zoom,
    required this.onZoomChanged,
    this.minZoom = 0.1,
    this.maxZoom = 2.0,
    this.step = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPressStart: (details) {
            onZoomChanged(maxZoom, false, true);
          },
          onLongPressEnd: (details) {
            onZoomChanged(zoom, false, true);
          },
          child: IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            color: Colors.white,

            onPressed: () {
              final newZoom = (zoom + step).clamp(minZoom, maxZoom);
              onZoomChanged(newZoom, false, false);
            },
          ),
        ),
        SizedBox(
          height: 200,
          child: RotatedBox(
            quarterTurns: -1,
            child: Slider(
              value: zoom,
              min: minZoom,
              max: maxZoom,
              divisions: ((maxZoom - minZoom) / step).round(),
              // label: zoom.toStringAsFixed(2),
              onChanged: (value) => onZoomChanged(value, true, false),
            ),
          ),
        ),
        GestureDetector(
          onLongPressStart: (details) {
            onZoomChanged(minZoom, false, true);
          },
          onLongPressEnd: (details) {
            onZoomChanged(zoom, false, true);
          },
          child: IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            color: Colors.white,

            onPressed: () {
              final newZoom = (zoom - step).clamp(minZoom, maxZoom);
              onZoomChanged(newZoom, false, false);
            },
          ),
        ),
      ],
    );
  }
}
