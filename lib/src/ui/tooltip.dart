import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// A delegate for computing the layout of a tooltip to be displayed above or
/// below a target specified in the global coordinate system.
class _TooltipPositionDelegate extends SingleChildLayoutDelegate {
  /// Creates a delegate for computing the layout of a tooltip.
  _TooltipPositionDelegate({
    required this.target,
    required this.offset,
    required this.preferBelow,
  });

  /// The offset of the target the tooltip is positioned near in the global
  /// coordinate system.
  final Offset target;

  final Offset offset;

  /// Whether the tooltip is displayed below its widget by default.
  ///
  /// If there is insufficient space to display the tooltip in the preferred
  /// direction, the tooltip will be displayed in the opposite direction.
  final bool preferBelow;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return positionDependentBox(
      size: size,
      childSize: childSize,
      target: target,
      offset: offset,
      preferBelow: preferBelow,
    );
  }

  Offset positionDependentBox({
    required Size size,
    required Size childSize,
    required Offset target,
    required bool preferBelow,
    Offset offset = Offset.zero,
    double margin = 10.0,
  }) {
    // VERTICAL DIRECTION
    final bool fitsBelow =
        target.dy + offset.dy + childSize.height <= size.height - margin;
    final bool fitsAbove = target.dy - offset.dy - childSize.height >= margin;
    final bool fitsNone = !fitsAbove && !fitsBelow;
    final bool tooltipBelow = fitsAbove == fitsBelow ? preferBelow : fitsBelow;
    final double y;
    if (tooltipBelow) {
      if (fitsNone) {
        y = math.min(
          target.dy + offset.dy,
          size.height - childSize.height - margin,
        );
      } else {
        y = math.min(target.dy + offset.dy, size.height - margin);
      }
    } else {
      y = math.max(target.dy - offset.dy - childSize.height, margin);
    }

    // HORIZONTAL DIRECTION
    final double flexibleSpace = size.width - childSize.width - offset.dx;
    final double x = flexibleSpace <= 2 * margin
        ? flexibleSpace / 2.0
        : clampDouble(
            target.dx + offset.dx - childSize.width / 2,
            margin,
            flexibleSpace - margin,
          );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TooltipPositionDelegate oldDelegate) {
    return target != oldDelegate.target ||
        offset != oldDelegate.offset ||
        preferBelow != oldDelegate.preferBelow;
  }
}

class TooltipPositionedWidget extends StatelessWidget {
  const TooltipPositionedWidget({
    super.key,
    required this.child,
    required this.target,
    this.offset = Offset.zero,
    this.preferBelow = true,
    this.margin = 10.0,
  });
  final Widget child;
  final Offset target;
  final Offset offset;
  final bool preferBelow;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _TooltipPositionDelegate(
        target: target,
        offset: offset,
        preferBelow: preferBelow,
      ),
      child: child,
    );
  }
}
