import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart' as jge;

/// Rays against triangle lists: what a pick test that knows an entity's
/// real shape — a model's mesh, a 3-D shape's — measures with.
abstract final class RayTriangles {
  /// How far along the ray from [origin] in [direction] the first of
  /// [geometry]'s triangles is (either side facing), in units of
  /// [direction]; null when it meets none.
  static double? nearestHit(
    jge.ModelGeometry geometry,
    jge.Vector3 origin,
    jge.Vector3 direction,
  ) => nearest(geometry, origin, direction)?.t;

  /// The first of [geometry]'s triangles along the ray from [origin] in
  /// [direction], and which way it faces (in the geometry's own space, unit
  /// length, turned towards the ray's start); null when it meets none.
  static RayTriangleHit? nearest(
    jge.ModelGeometry geometry,
    jge.Vector3 origin,
    jge.Vector3 direction,
  ) {
    final p = geometry.positions, idx = geometry.indices;
    double? best;
    var bx = 0.0, by = 0.0, bz = 0.0;
    for (var i = 0; i + 2 < idx.length; i += 3) {
      final a = idx[i] * 3, b = idx[i + 1] * 3, c = idx[i + 2] * 3;
      // Möller–Trumbore.
      final e1x = p[b] - p[a], e1y = p[b + 1] - p[a + 1], e1z = p[b + 2] - p[a + 2];
      final e2x = p[c] - p[a], e2y = p[c + 1] - p[a + 1], e2z = p[c + 2] - p[a + 2];
      final px = direction.y * e2z - direction.z * e2y;
      final py = direction.z * e2x - direction.x * e2z;
      final pz = direction.x * e2y - direction.y * e2x;
      final det = e1x * px + e1y * py + e1z * pz;
      if (det.abs() < 1e-12) continue;
      final inv = 1 / det;
      final tx = origin.x - p[a], ty = origin.y - p[a + 1], tz = origin.z - p[a + 2];
      final u = (tx * px + ty * py + tz * pz) * inv;
      if (u < 0 || u > 1) continue;
      final qx = ty * e1z - tz * e1y, qy = tz * e1x - tx * e1z, qz = tx * e1y - ty * e1x;
      final v = (direction.x * qx + direction.y * qy + direction.z * qz) * inv;
      if (v < 0 || u + v > 1) continue;
      final t = (e2x * qx + e2y * qy + e2z * qz) * inv;
      if (t < 0) continue;
      if (best == null || t < best) {
        best = t;
        bx = e1y * e2z - e1z * e2y;
        by = e1z * e2x - e1x * e2z;
        bz = e1x * e2y - e1y * e2x;
      }
    }
    if (best == null) return null;
    final length = math.sqrt(bx * bx + by * by + bz * bz);
    final normal = length < 1e-12
        ? jge.Vector3(0, -1, 0)
        : jge.Vector3(bx / length, by / length, bz / length);
    // Either side counts: the one the ray came from.
    if (normal.dot(direction) > 0) normal.negate();
    return RayTriangleHit(best, normal);
  }

  /// [nearest] for [geometry] placed in the world by [world]: [ray] taken
  /// into its own space, the facing brought back out (by the inverse's
  /// transpose, unit length). Null when it meets none, or [world] squashes
  /// it flat.
  static RayTriangleHit? nearestPlaced(
    jge.ModelGeometry geometry,
    jge.Matrix4 world,
    jge.Ray3 ray,
  ) {
    final inverse = jge.Matrix4.identity();
    if (inverse.copyInverse(world) == 0) return null;
    final origin = jge.Vector3.zero(), direction = jge.Vector3.zero();
    // The direction is carried over unnormalised, so t stays in the ray's
    // units.
    inverse
      ..transformPointInto(ray.origin, origin)
      ..transformDirectionInto(ray.direction, direction);
    final hit = nearest(geometry, origin, direction);
    if (hit == null) return null;
    final n = hit.normal, m = inverse.storage;
    final out = jge.Vector3(
      m[0] * n.x + m[1] * n.y + m[2] * n.z,
      m[4] * n.x + m[5] * n.y + m[6] * n.z,
      m[8] * n.x + m[9] * n.y + m[10] * n.z,
    )..normalize();
    if (out.dot(ray.direction) > 0) out.negate();
    return RayTriangleHit(hit.t, out);
  }
}

/// Where a ray met a triangle list: how far along it ([t], in units of its
/// direction) and which way the triangle faced there.
final class RayTriangleHit {
  const RayTriangleHit(this.t, this.normal);

  /// How far along the ray.
  final double t;

  /// The triangle's facing, towards the ray's start.
  final jge.Vector3 normal;
}
