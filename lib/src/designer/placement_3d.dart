import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../view/ray_entity_picker.dart';
import 'prefab_registry.dart';

/// How something placed in 3-D is set down: turned upright or to stand on
/// the surface, spun about its up, sized, and lifted so that its lowest
/// point touches the surface, its middle over the point.
///
/// +Y is down: an upright thing's up is -Y.
abstract final class Placement3D {
  /// Up, in the engine's space.
  static final jge.Vector3 up = jge.Vector3(0, -1, 0);

  /// The turn taking direction [from] onto [to] (both unit length) the
  /// shortest way.
  static jge.Quaternion turnBetween(jge.Vector3 from, jge.Vector3 to) {
    final d = from.dot(to).clamp(-1.0, 1.0);
    if (d > 1 - 1e-9) return jge.Quaternion.identity();
    var axis = from.cross(to);
    if (d < -1 + 1e-9) {
      // Opposite: any axis across [from] will do.
      axis = from.cross(jge.Vector3(1, 0, 0));
      if (axis.lengthSquared < 1e-9) axis = from.cross(jge.Vector3(0, 0, 1));
    }
    return jge.Quaternion.axisAngle(axis..normalize(), math.acos(d));
  }

  /// The turn for something set on [at]: standing on the surface (its up
  /// along the surface's facing) when [align], upright otherwise, then
  /// spun [spinDegrees] about that up.
  static jge.Quaternion turnFor(
    SurfacePoint at, {
    bool align = false,
    double spinDegrees = 0,
  }) {
    final upOn = align
        ? (jge.Vector3.copy(at.normal)..normalize())
        : jge.Vector3.copy(up);
    final stand = align ? turnBetween(up, upOn) : jge.Quaternion.identity();
    final spin = jge.Quaternion.axisAngle(upOn, spinDegrees * math.pi / 180);
    return spin..multiply(stand);
  }

  /// [prefab]'s components set down on [at]: built upright (on a level
  /// surface when [align] is on), then, about the point, sized by [size]
  /// and turned — stood on the surface when [align] is on — and spun
  /// [spin] degrees about its up. Given a transform at the point when the
  /// prefab brings none.
  static List<jge.Component> posed(
    PrefabDefinition prefab,
    SurfacePoint at, {
    bool align = false,
    double spin = 0,
    double size = 1,
  }) {
    final built = align ? SurfacePoint(at.position, up, onto: at.onto) : at;
    final components =
        prefab.buildAt?.call(built) ??
        prefab.build(
          jge.Vector3(at.position.x, at.position.y, 0).toOffset(),
          prefab.defaultSize,
        );
    var transform = components.whereType<jge.TransformComponent>().firstOrNull;
    if (transform == null) {
      transform = jge.TransformComponent(position: jge.Vector3.copy(at.position));
      components.insert(0, transform);
    } else if (prefab.buildAt == null) {
      transform.position.z = at.position.z;
    }
    if (align || spin != 0 || size != 1) {
      final turn = turnFor(at, align: align, spinDegrees: spin);
      final offset = (transform.position - at.position)..scale(size);
      turn.rotate(offset);
      transform.position.setFrom(at.position + offset);
      final own = jge.Quaternion.identity();
      transform.rotationInto(own);
      transform
        ..setRotation(turn..multiply(own))
        ..scale.scale(size);
    }
    return components;
  }

  /// Where an entity goes so that [box] — its own bounds about its origin,
  /// before [turn] and [scale] — rests on [at]: its lowest point along the
  /// surface's facing on the surface (a hair off it for something flat,
  /// so the two do not fight), its middle over the point.
  static jge.Vector3 restingAt(
    SurfacePoint at,
    jge.Aabb3 box,
    jge.Quaternion turn,
    jge.Vector3 scale,
  ) {
    final n = jge.Vector3.copy(at.normal)..normalize();
    if (box.isEmpty) return jge.Vector3.copy(at.position);
    var lowest = double.infinity, highest = double.negativeInfinity;
    final corner = jge.Vector3.zero();
    for (var i = 0; i < 8; i++) {
      corner.setValues(
        (i & 1 == 0 ? box.min.x : box.max.x) * scale.x,
        (i & 2 == 0 ? box.min.y : box.max.y) * scale.y,
        (i & 4 == 0 ? box.min.z : box.max.z) * scale.z,
      );
      turn.rotate(corner);
      final d = n.dot(corner);
      lowest = math.min(lowest, d);
      highest = math.max(highest, d);
    }
    final centre = jge.Vector3(
      (box.min.x + box.max.x) / 2 * scale.x,
      (box.min.y + box.max.y) / 2 * scale.y,
      (box.min.z + box.max.z) / 2 * scale.z,
    );
    turn.rotate(centre);
    // Across the surface the middle goes over the point; along it, the
    // lowest point onto it.
    final across = centre - n * n.dot(centre);
    final lift = -lowest + (highest - lowest < 1e-6 ? 0.001 : 0);
    return at.position - across + n * lift;
  }
}

/// The random part of the next placement — a turn about its up and a
/// size — rolled ahead, so the preview shows exactly what a click makes,
/// and rolled again after each one.
final class PlacementRoll {
  /// A roll from [seed], or a fresh one each run.
  PlacementRoll({int? seed}) : _random = math.Random(seed);

  final math.Random _random;

  /// Degrees added to the spin.
  double turn = 0;

  /// What the size is multiplied by.
  double size = 1;

  /// Rolls the next: a turn within ±[turnRange] degrees, a size within
  /// ±[sizeRange] (a fraction) of 1. Nothing random where a range is 0.
  void roll({required double turnRange, required double sizeRange}) {
    turn = turnRange <= 0 ? 0 : (_random.nextDouble() * 2 - 1) * turnRange;
    size = sizeRange <= 0 ? 1 : 1 + (_random.nextDouble() * 2 - 1) * sizeRange;
  }
}
