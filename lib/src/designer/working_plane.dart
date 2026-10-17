import 'package:just_game_engine/just_game_engine.dart' as jge;

/// Which way the 3-D designer's working plane lies.
enum WorkingPlaneAxis {
  /// Level, like the ground: a height (Y) to build on.
  ground('Ground', 1),

  /// Upright, facing the front: a depth (Z) to build against.
  front('Front', 2),

  /// Upright, facing the side: an X to build against.
  side('Side', 0);

  const WorkingPlaneAxis(this.label, this.axis);

  /// Its name in the editor.
  final String label;

  /// The world axis it is constant along: 0 X, 1 Y, 2 Z.
  final int axis;

  /// The next one round: Ground, Front, Side, Ground.
  WorkingPlaneAxis get next => values[(index + 1) % values.length];
}

/// The plane a 3-D designer builds on where nothing is under the pointer:
/// the ground at some height, or an upright wall at some depth.
///
/// Engine space: +Y is down, so a plane 2 m up has an [offset] of -2.
final class WorkingPlane {
  /// The plane along [axis] at [offset] on its axis.
  const WorkingPlane(this.axis, [this.offset = 0]);

  /// The ground: level, at y = 0.
  static const WorkingPlane ground = WorkingPlane(WorkingPlaneAxis.ground);

  /// Which way it lies.
  final WorkingPlaneAxis axis;

  /// Where it lies on [WorkingPlaneAxis.axis].
  final double offset;

  /// The way it faces: up (-Y) for the ground, +Z for the front, +X for the
  /// side.
  jge.Vector3 get normal => switch (axis) {
    WorkingPlaneAxis.ground => jge.Vector3(0, -1, 0),
    WorkingPlaneAxis.front => jge.Vector3(0, 0, 1),
    WorkingPlaneAxis.side => jge.Vector3(1, 0, 0),
  };

  /// [point]'s coordinate along the plane's axis.
  static double along(jge.Vector3 point, WorkingPlaneAxis axis) =>
      switch (axis.axis) {
        0 => point.x,
        1 => point.y,
        _ => point.z,
      };

  /// Where [ray] crosses it, ahead of the ray's origin; null when the ray
  /// runs along it or away from it.
  jge.Vector3? intersect(jge.Ray3 ray) {
    final o = along(ray.origin, axis);
    final d = along(ray.direction, axis);
    if (d.abs() < 1e-9) return null;
    final t = (offset - o) / d;
    if (t <= 0) return null;
    final hit = jge.Vector3.zero();
    ray.atInto(t, hit);
    // Exactly on it, whatever rounding said.
    switch (axis.axis) {
      case 0:
        hit.x = offset;
      case 1:
        hit.y = offset;
      default:
        hit.z = offset;
    }
    return hit;
  }

  /// [point] with its two coordinates in the plane on the nearest [step];
  /// the one across it is left. [step] of 0 leaves it all.
  jge.Vector3 snapInPlane(jge.Vector3 point, double step) {
    if (step <= 0) return jge.Vector3.copy(point);
    double s(double v) => (v / step).roundToDouble() * step;
    return jge.Vector3(
      axis.axis == 0 ? point.x : s(point.x),
      axis.axis == 1 ? point.y : s(point.y),
      axis.axis == 2 ? point.z : s(point.z),
    );
  }

  /// The same plane, [by] along its normal — up for the ground.
  WorkingPlane moved(double by) {
    final n = along(normal, axis);
    return WorkingPlane(axis, offset + by * n);
  }

  /// The same plane through [point].
  WorkingPlane through(jge.Vector3 point) =>
      WorkingPlane(axis, along(point, axis));

  @override
  bool operator ==(Object other) =>
      other is WorkingPlane && other.axis == axis && other.offset == offset;

  @override
  int get hashCode => Object.hash(axis, offset);

  @override
  String toString() => 'WorkingPlane(${axis.label}, $offset)';
}
