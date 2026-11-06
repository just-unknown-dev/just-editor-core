import 'package:just_game_engine/just_game_engine.dart' as jge;

/// A single entity's transform, captured so it can be restored exactly.
///
/// Stores plain doubles rather than a reference to the live component: the
/// point is to survive the component being mutated afterwards. All nine
/// values are kept — position, the three rotation angles and scale, in 3-D —
/// so undoing a 2-D edit never loses a z, a tilt or a z scale.
class TransformSnapshot {
  const TransformSnapshot({
    required this.x,
    required this.y,
    this.z = 0.0,
    required this.angle,
    this.eulerX = 0.0,
    this.eulerY = 0.0,
    required this.scaleX,
    required this.scaleY,
    this.scaleZ = 1.0,
  });

  /// Reads the current transform of [entity].
  factory TransformSnapshot.of(jge.Entity entity) {
    final t = entity.getComponent<jge.TransformComponent>()!;
    return TransformSnapshot(
      x: t.position.x,
      y: t.position.y,
      z: t.position.z,
      angle: t.angle,
      eulerX: t.eulerX,
      eulerY: t.eulerY,
      scaleX: t.scale.x,
      scaleY: t.scale.y,
      scaleZ: t.scale.z,
    );
  }

  /// World X.
  final double x;

  /// World Y.
  final double y;

  /// World Z.
  final double z;

  /// Rotation about Z in radians — the 2-D rotation.
  final double angle;

  /// Rotation about X in radians.
  final double eulerX;

  /// Rotation about Y in radians.
  final double eulerY;

  /// Horizontal scale.
  final double scaleX;

  /// Vertical scale.
  final double scaleY;

  /// Depth scale.
  final double scaleZ;

  /// Writes this snapshot back onto [entity].
  void applyTo(jge.Entity entity) {
    final t = entity.getComponent<jge.TransformComponent>();
    if (t == null) return;
    t
      ..setPositionXYZ(x, y, z)
      ..setEuler(eulerX, eulerY, angle);
    t.scale.setValues(scaleX, scaleY, scaleZ);
  }

  /// Whether [other] describes the same transform, within float noise.
  bool matches(TransformSnapshot other) =>
      (x - other.x).abs() < 1e-6 &&
      (y - other.y).abs() < 1e-6 &&
      (z - other.z).abs() < 1e-6 &&
      (angle - other.angle).abs() < 1e-9 &&
      (eulerX - other.eulerX).abs() < 1e-9 &&
      (eulerY - other.eulerY).abs() < 1e-9 &&
      (scaleX - other.scaleX).abs() < 1e-9 &&
      (scaleY - other.scaleY).abs() < 1e-9 &&
      (scaleZ - other.scaleZ).abs() < 1e-9;
}
