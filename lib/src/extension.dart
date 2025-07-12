import 'dart:ui';

import 'package:forge2d/forge2d.dart';

extension Vector2Extension on Vector2 {
  Offset toOffset() => Offset(x, y);
}

extension OffsetExtension on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}
