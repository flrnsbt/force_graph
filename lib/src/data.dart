import 'dart:async';

import 'package:flutter/material.dart';
import 'package:force_graph/src/controller.dart'
    show ForceGraphNode, ForceGraphEdge;
import 'package:forge2d/forge2d.dart';

// returns true if drawing was handled, false otherwise
// if drawing is marked as not handled, the default painter will be used
// based on the node style provided
typedef NodePainter =
    bool Function(
      Canvas canvas,
      ForceGraphNode node,
      Offset position,
      BuildContext context,
    );

// returns true if drawing was handled, false otherwise
// if drawing is marked as not handled, the default painter will be used
// based on the edge style provided
typedef EdgePainter =
    bool Function(Canvas canvas, ForceGraphEdge edge, BuildContext context);

/// Controls when node text labels should be rendered on the graph canvas.
enum NodeLabelVisibility {
  /// Labels are always rendered for all nodes.
  always,

  /// Labels are rendered only when the node is hovered or selected.
  hoveredOrSelected,

  /// Labels are rendered only when the node is selected.
  selectedOnly,

  /// Labels are never rendered on the canvas.
  never,
}

class ForceGraphNodeData {
  final String iD;
  final List<ForceGraphEdgeData> edges;
  final GraphComponentStyle style;
  final String title;
  final Object? data;
  final double radius;
  final bool removable;
  final bool pinned;
  final bool? showLabel;
  final TextStyle? labelStyle;
  final bool? animateBorder;
  final bool? animateBorderOnlyIfSelected;
  final Duration? animateBorderDuration;
  final NodePainter? customPainter;

  const ForceGraphNodeData(
    this.iD,
    this.edges,
    this.style,
    this.title,
    this.data,
    this.radius,
    this.removable,
    this.animateBorder,
    this.animateBorderOnlyIfSelected,
    this.animateBorderDuration,
    this.customPainter, {
    this.pinned = false,
    this.showLabel,
    this.labelStyle,
  });

  factory ForceGraphNodeData.from({
    required String id,
    List<ForceGraphEdgeData> edges = const [],
    GraphComponentStyle style = GraphComponentStyle.none,
    String title = '',
    Object? data,
    double radius = 18.0,
    bool removable = true,
    bool pinned = false,
    bool? showLabel,
    TextStyle? labelStyle,
    bool? animateBorder,
    bool? animateBorderOnlyIfSelected,
    Duration? animateBorderDuration,
    NodePainter? customPainter,
  }) {
    return ForceGraphNodeData(
      id,
      List<ForceGraphEdgeData>.from(edges),
      style,
      title,
      data,
      radius,
      removable,
      animateBorder,
      animateBorderOnlyIfSelected,
      animateBorderDuration,
      customPainter,
      pinned: pinned,
      showLabel: showLabel,
      labelStyle: labelStyle,
    );
  }

  ForceGraphNodeData deepCopy() {
    return ForceGraphNodeData(
      iD,
      edges.map((e) => e.deepCopy()).toList(),
      style,
      title,
      data,
      radius,
      removable,
      animateBorder,
      animateBorderOnlyIfSelected,
      animateBorderDuration,
      customPainter,
      pinned: pinned,
      showLabel: showLabel,
      labelStyle: labelStyle,
    );
  }

  ForceGraphNodeData copyWith({
    String? iD,
    List<ForceGraphEdgeData>? edges,
    GraphComponentStyle? style,
    String? title,
    Object? data,
    double? radius,
    bool? removable,
    bool? pinned,
    bool? showLabel,
    TextStyle? labelStyle,
    bool? animateBorder,
    bool? animateBorderOnlyIfSelected,
    Duration? animateBorderDuration,
    NodePainter? customPainter,
  }) => ForceGraphNodeData(
    iD ?? this.iD,
    edges ?? this.edges,
    style ?? this.style,
    title ?? this.title,
    data ?? this.data,
    radius ?? this.radius,
    removable ?? this.removable,
    animateBorder ?? this.animateBorder,
    animateBorderOnlyIfSelected ?? this.animateBorderOnlyIfSelected,
    animateBorderDuration ?? this.animateBorderDuration,
    customPainter ?? this.customPainter,
    pinned: pinned ?? this.pinned,
    showLabel: showLabel ?? this.showLabel,
    labelStyle: labelStyle ?? this.labelStyle,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ForceGraphNodeData && iD == other.iD;

  @override
  int get hashCode => iD.hashCode;

  @override
  String toString() {
    return 'ForceGraphNodeData(id: $iD, edges: $edges, style: $style, title: $title, data: $data, radius: $radius, removable: $removable, pinned: $pinned, showLabel: $showLabel, animateBorder: $animateBorder, animateBorderOnlyIfSelected: $animateBorderOnlyIfSelected, animateBorderDuration: $animateBorderDuration, customPainter: $customPainter)';
  }

  void removeEdge(int iD) {
    edges.removeWhere((edge) => edge.iD == iD);
  }
}

class ForceGraphEdgeData {
  final String source;
  final String target;
  final double similarity;
  final double weight;
  final Object? data;
  final GraphComponentStyle style;
  final bool directed;
  final String? label;
  final TextStyle? labelStyle;
  final EdgePainter? customPainter;

  const ForceGraphEdgeData(
    this.source,
    this.target,
    this.similarity,
    this.weight,
    this.style, [
    this.data,
    this.directed = false,
    this.label,
    this.labelStyle,
    this.customPainter,
  ]);

  factory ForceGraphEdgeData.from({
    required String source,
    required String target,
    required double similarity,
    Object? data,
    double weight = 1.0,
    GraphComponentStyle style = GraphComponentStyle.none,
    bool directed = false,
    String? label,
    TextStyle? labelStyle,
    EdgePainter? customPainter,
  }) {
    return ForceGraphEdgeData(
      source,
      target,
      similarity,
      weight,
      style,
      data,
      directed,
      label,
      labelStyle,
      customPainter,
    );
  }

  ForceGraphEdgeData deepCopy() {
    return ForceGraphEdgeData(
      source,
      target,
      similarity,
      weight,
      style,
      data,
      directed,
      label,
      labelStyle,
      customPainter,
    );
  }

  ForceGraphEdgeData copyWith({
    String? source,
    String? target,
    double? similarity,
    double? weight,
    Object? data,
    GraphComponentStyle? style,
    bool? directed,
    String? label,
    TextStyle? labelStyle,
    EdgePainter? customPainter,
  }) {
    return ForceGraphEdgeData(
      source ?? this.source,
      target ?? this.target,
      similarity ?? this.similarity,
      weight ?? this.weight,
      style ?? this.style,
      data ?? this.data,
      directed ?? this.directed,
      label ?? this.label,
      labelStyle ?? this.labelStyle,
      customPainter ?? this.customPainter,
    );
  }

  static int getID(String source, String target) =>
      source.hashCode ^ target.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ForceGraphEdgeData && iD == other.iD;

  int get iD => getID(source, target);

  @override
  int get hashCode => iD;

  @override
  String toString() {
    return 'ForceGraphEdgeData(source: $source, target: $target, similarity: $similarity, weight: $weight, style: $style, data: $data, directed: $directed, label: $label)';
  }
}

class GraphComponentStyle {
  final GraphComponentStyleElement light;
  final GraphComponentStyleElement dark;
  const GraphComponentStyle({
    this.light = const GraphComponentStyleElement(),
    this.dark = const GraphComponentStyleElement(),
  });

  factory GraphComponentStyle.from({
    Color? color,
    Color? selectedColor,
    Color? selectedColorBorder,
    Color? colorBorder,
    double? selectedBorderWidth,
    double? borderWidth,
    bool borderWidthRatio = false,
    Color? hoverColor,
  }) {
    return GraphComponentStyle.fromGraphComponentStyleElement(
      GraphComponentStyleElement(
        color: color,
        selectedColor: selectedColor,
        selectedColorBorder: selectedColorBorder,
        colorBorder: colorBorder,
        borderWidthRatio: borderWidthRatio,
        selectedBorderWidth: selectedBorderWidth,
        borderWidth: borderWidth,
        hoverColor: hoverColor,
      ),
    );
  }

  factory GraphComponentStyle.fromGraphComponentStyleElement(
    GraphComponentStyleElement element,
  ) {
    return GraphComponentStyle(light: element, dark: element);
  }

  static const none = GraphComponentStyle();

  GraphComponentStyleElement fromContext(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  GraphComponentStyle copyWith({
    GraphComponentStyleElement? light,
    GraphComponentStyleElement? dark,
  }) {
    return GraphComponentStyle(
      light: light ?? this.light,
      dark: dark ?? this.dark,
    );
  }

  GraphComponentStyle merge(GraphComponentStyleElement element) {
    return copyWith(light: light.merge(element), dark: dark.merge(element));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphComponentStyle &&
          light == other.light &&
          dark == other.dark;

  @override
  int get hashCode => light.hashCode ^ dark.hashCode;
}

class GraphComponentStyleElement {
  final Color? color;
  final Color? selectedColor;
  final Color? selectedColorBorder;
  final Color? colorBorder;
  final double? selectedBorderWidth;
  final double? borderWidth;
  final bool borderWidthRatio;
  final Color? hoverColor;
  const GraphComponentStyleElement({
    this.color,
    this.selectedColor,
    this.selectedColorBorder,
    this.borderWidthRatio = false,
    this.colorBorder,
    this.hoverColor,
    this.selectedBorderWidth,
    this.borderWidth,
  });

  factory GraphComponentStyleElement.default_(
    Color color, {
    double borderOpacity = 0.25,
    double borderWidth = 1,
    Color? selectedColor,
    Color? selectedColorBorder,
    Color? colorBorder,
    Color? hoverColor,
    bool borderWidthRatio = false,
    double? selectedBorderWidth,
  }) {
    return GraphComponentStyleElement(
      color: color,
      colorBorder: color.withValues(alpha: borderOpacity),
      borderWidth: borderWidth,
      borderWidthRatio: borderWidthRatio,
    );
  }

  GraphComponentStyleElement merge(GraphComponentStyleElement element) {
    return copyWith(
      color: element.color,
      selectedColor: element.selectedColor,
      borderWidthRatio: element.borderWidthRatio,
      selectedColorBorder: element.selectedColorBorder,
      colorBorder: element.colorBorder,
      selectedBorderWidth: element.selectedBorderWidth,
      hoverColor: element.hoverColor,
      borderWidth: element.borderWidth,
    );
  }

  GraphComponentStyleElement copyWith({
    Color? color,
    Color? selectedColor,
    Color? selectedColorBorder,
    Color? colorBorder,
    double? selectedBorderWidth,
    bool? borderWidthRatio,
    double? borderWidth,
    Color? hoverColor,
  }) {
    return GraphComponentStyleElement(
      color: color ?? this.color,
      borderWidthRatio: borderWidthRatio ?? this.borderWidthRatio,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedColorBorder: selectedColorBorder ?? this.selectedColorBorder,
      colorBorder: colorBorder ?? this.colorBorder,
      borderWidth: borderWidth ?? this.borderWidth,
      selectedBorderWidth: selectedBorderWidth ?? this.selectedBorderWidth,
      hoverColor: hoverColor ?? this.hoverColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphComponentStyleElement &&
          color == other.color &&
          borderWidthRatio == other.borderWidthRatio &&
          selectedColor == other.selectedColor &&
          selectedColorBorder == other.selectedColorBorder &&
          colorBorder == other.colorBorder &&
          selectedBorderWidth == other.selectedBorderWidth &&
          hoverColor == other.hoverColor;

  @override
  int get hashCode =>
      color.hashCode ^
      borderWidthRatio.hashCode ^
      selectedColor.hashCode ^
      selectedColorBorder.hashCode ^
      colorBorder.hashCode ^
      selectedBorderWidth.hashCode ^
      borderWidth.hashCode ^
      hoverColor.hashCode;
}

class AnimateElement<T extends Object> {
  final T target;
  final T start;
  final Curve? _curve;

  final bool bounded;

  final void Function(T target, bool cancelled)? _onDone;

  void update(double dt, T value) {
    if (completed) return;
    _elapsedSec += dt;
    double progress = _progressGetter(value, target, _elapsedSec);
    if (bounded) {
      progress = progress.clamp(0.0, 1.0);
    }
    _progress = progress;
    _onUpdate(progress, start, target);
    if (_isDone(value, target, progress)) {
      _onDone?.call(target, false);
      _completed = true;
      _completer.complete();
    }
  }

  final bool Function(T value, T target, double progress) _isDone;

  final void Function(double progress, T start, T target) _onUpdate;

  double _elapsedSec = 0;

  bool _completed = false;

  bool get completed => _completed;

  final double Function(T value, T target, double elapsedSec) _progressGetter;

  double _progress = 0;
  double get progress {
    if (_curve != null) {
      return _curve.transform(_progress);
    }
    return _progress;
  }

  final Completer<void> _completer = Completer<void>();

  Future<void> get onDone async {
    try {
      await onDoneOrCancelled;
    } catch (e) {
      if (e != 'Cancelled') {
        rethrow;
      }
    }
  }

  Future<void> get onDoneOrCancelled => _completer.future;

  AnimateElement(
    this.bounded,
    this.target,
    this._curve,
    this.start,
    this._onUpdate,
    this._isDone,
    this._progressGetter, [
    this._onDone,
  ]);

  factory AnimateElement.bounded(
    T target,
    T start, {
    required void Function(double progress, T start, T target) onUpdate,

    required Duration duration,
    void Function(T target, bool cancelled)? onDone,
    Curve curve = Curves.linear,
  }) {
    return AnimateElement(
      true,
      target,
      curve,
      start,
      onUpdate,
      (_, __, progress) => progress >= 1,
      (_, __, elapsedSec) => _defaultDurationProgress(duration, elapsedSec),
      onDone,
    );
  }

  factory AnimateElement.unbounded(
    T target,
    T start, {
    required void Function(double progress, T start, T target) onUpdate,
    required double Function(T value, T target, double elapsedSec)
    progressGetter,
    required bool Function(T value, T target) isDone,
    void Function(T target, bool cancelled)? onDone,
  }) {
    return AnimateElement(
      false,
      target,
      null,
      start,
      onUpdate,
      (value, target, _) => isDone(value, target),
      progressGetter,
      onDone,
    );
  }

  static AnimateElement<double> fromNum<T extends num>(
    T target,
    T start, {
    required void Function(double newValue) onUpdate,
    Duration? duration,
    double unboundedProgressFactor = 1.0,
    void Function(double target, bool cancelled)? onDone,
    Curve curve = Curves.linear,
  }) {
    void $onUpdate(double progress, double start, double target) {
      final newValue = start + (target - start) * progress;
      onUpdate(newValue);
    }

    void $onDone(double value, bool cancelled) {
      if (!cancelled) {
        onUpdate(value);
      }
      onDone?.call(value, cancelled);
    }

    if (duration != null) {
      return AnimateElement<double>.bounded(
        target.toDouble(),
        start.toDouble(),
        duration: duration,
        curve: curve,
        onUpdate: $onUpdate,
        onDone: $onDone,
      );
    }
    return AnimateElement<double>.unbounded(
      target.toDouble(),
      start.toDouble(),
      onUpdate: $onUpdate,
      isDone: (current, target) {
        return current - start >= target - start;
      },
      onDone: $onDone,

      progressGetter: (_, __, elapsed) {
        return elapsed * unboundedProgressFactor;
      },
    );
  }

  static double _defaultDurationProgress(Duration target, double elapsedSec) {
    return elapsedSec /
        (target.inMicroseconds / Duration.microsecondsPerSecond);
  }

  static AnimateElement<Vector2> fromVector2(
    Vector2 target,
    Vector2 start, {
    required void Function(Vector2 newValue) onUpdate,
    double unboundedProgressFactor = 1.0,

    Duration? duration,
    void Function(Vector2 target, bool cancelled)? onDone,
    Curve curve = Curves.linear,
  }) {
    void $onUpdate(double progress, Vector2 start, Vector2 target) {
      final newValue = start + (target - start) * progress;

      onUpdate(newValue);
    }

    void $onDone(Vector2 value, bool cancelled) {
      if (!cancelled) {
        onUpdate(value);
      }
      onDone?.call(value, cancelled);
    }

    if (duration != null) {
      return AnimateElement<Vector2>.bounded(
        target,
        start,
        curve: curve,
        duration: duration,
        onUpdate: $onUpdate,
        onDone: $onDone,
      );
    }

    return AnimateElement<Vector2>.unbounded(
      target,
      start,
      onUpdate: $onUpdate,
      onDone: $onDone,

      progressGetter: (_, __, elapsed) {
        return elapsed * unboundedProgressFactor;
      },
      isDone: (current, target) {
        final ab = target - start;
        final ac = current - start;
        final dot = ac.dot(ab);
        final abLengthSquared = ab.length2;
        return dot >= abLengthSquared;
      },
    );
  }

  bool cancel() {
    if (_completed) return false;
    _completed = true;
    _onDone?.call(target, true);
    _completer.completeError('Cancelled');
    return true;
  }
}
