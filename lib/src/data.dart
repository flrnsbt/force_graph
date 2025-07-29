import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart';

class ForceGraphNodeData {
  final String iD;
  final List<ForceGraphEdgeData> edges;
  final GraphComponentStyle style;
  final String title;
  final Object? data;
  final double radius;
  final bool removable;
  const ForceGraphNodeData(
    this.iD,
    this.edges,
    this.style,
    this.title,
    this.data,
    this.radius,
    this.removable,
  );

  factory ForceGraphNodeData.from({
    required String id,
    List<ForceGraphEdgeData> edges = const [],
    GraphComponentStyle style = GraphComponentStyle.none,
    String title = '',
    Object? data,
    double radius = 0.2,
    bool removable = true,
  }) {
    return ForceGraphNodeData(id, edges, style, title, data, radius, removable);
  }

  ForceGraphNodeData deepCopy() {
    return ForceGraphNodeData(
      iD,
      List.from(edges),
      style,
      title,
      data,
      radius,
      removable,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ForceGraphNodeData && iD == other.iD;

  @override
  int get hashCode => iD.hashCode;

  @override
  String toString() {
    return 'ForceGraphNodeData(id: $iD, edges: $edges)';
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
  final GraphComponentStyle style;
  const ForceGraphEdgeData(
    this.source,
    this.target,
    this.similarity,
    this.weight,
    this.style,
  );

  factory ForceGraphEdgeData.from({
    required String source,
    required String target,
    required double similarity,
    double weight = 1.0,
    GraphComponentStyle style = GraphComponentStyle.none,
  }) {
    return ForceGraphEdgeData(source, target, similarity, weight, style);
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
    return 'ForceGraphEdgeData(source: $source, target: $target, similarity: $similarity)';
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
    double borderWidth = 0.07,
    Color? hoverColor,
  }) {
    return GraphComponentStyle.fromGraphComponentStyleElement(
      GraphComponentStyleElement(
        color: color,
        selectedColor: selectedColor,
        selectedColorBorder: selectedColorBorder,
        colorBorder: colorBorder,
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
  final double borderWidth;
  final Color? hoverColor;
  const GraphComponentStyleElement({
    this.color,
    this.selectedColor,
    this.selectedColorBorder,
    this.colorBorder,
    this.hoverColor,
    this.borderWidth = 0.07,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphComponentStyleElement &&
          color == other.color &&
          selectedColor == other.selectedColor &&
          selectedColorBorder == other.selectedColorBorder &&
          colorBorder == other.colorBorder &&
          borderWidth == other.borderWidth &&
          hoverColor == other.hoverColor;

  @override
  int get hashCode =>
      color.hashCode ^
      selectedColor.hashCode ^
      selectedColorBorder.hashCode ^
      colorBorder.hashCode ^
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
