import 'package:flutter/painting.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'editor_view.dart';
import 'entity_picker.dart';
import 'ray_triangles.dart';

/// Knows the real shape of some entities — a 3-D model's triangles — so a
/// pick lands on what is drawn, not on its box. Modules offer these
/// (`EditorModule.pickTests`).
abstract interface class EntityRayTest {
  /// How far along [ray] (in units of its direction) it first meets
  /// [entity]'s shape: [double.infinity] for a miss, or null when this test
  /// does not know the entity (its box then decides).
  double? distanceTo(jge.Entity entity, jge.Ray3 ray);
}

/// Knows the corners of some entities' real shape — a model's vertices, a
/// 3-D shape's — so a move can put one thing's corner on another's (hold V
/// while dragging). Pick tests that know an entity's triangles offer it
/// too.
abstract interface class EntityVertexSource {
  /// [entity]'s vertices in the world, or null when this source does not
  /// know it.
  List<jge.Vector3>? verticesOf(jge.Entity entity);
}

/// Knows where a ray meets some entities' real surface and which way it
/// faces there — a model's triangles, a 3-D shape's — so something placed
/// on a slope or a ball sits on it, not on its box. Pick tests that know
/// an entity's triangles offer it too.
abstract interface class EntitySurfaceTest {
  /// Where [ray] first meets [entity]'s shape: how far along it (in units
  /// of its direction) and the surface's facing in the world, towards the
  /// ray's start. Null when this test does not know the entity; an
  /// infinite [RayTriangleHit.t] for a miss.
  RayTriangleHit? surfaceHit(jge.Entity entity, jge.Ray3 ray);
}

/// A point on a surface in space and which way the surface faces there:
/// where something placed from the viewport goes, and which way is up for
/// it.
final class SurfacePoint {
  /// [position] on a surface facing [normal] (unit length), on [onto] or
  /// on the ground when null.
  SurfacePoint(this.position, this.normal, {this.onto});

  /// Where it is.
  final jge.Vector3 position;

  /// Which way the surface faces: up (-Y) on the ground.
  final jge.Vector3 normal;

  /// What the surface belongs to, or null for the ground.
  final jge.Entity? onto;
}

/// Picks in 3-D: the view's ray through the pixel ([EditorView.screenToRay])
/// against each entity's box in space, nearest first, each hit then checked
/// against its real shape when an [EntityRayTest] knows it.
///
/// An entity's box is the union of its components' 3-D extents
/// (`ComponentExtent.boundsInto`) placed by its transform; with none, a
/// half-metre cube at its position.
class RayEntityPicker implements EntityPicker {
  /// A picker refining box hits with [tests].
  RayEntityPicker({List<EntityRayTest> Function()? tests}) : _tests = tests;

  final List<EntityRayTest> Function()? _tests;

  final jge.Ray3 _ray = jge.Ray3();
  final jge.Aabb3 _box = jge.Aabb3();

  @override
  jge.Entity? pickAt(
    EditorView view,
    Offset screen,
    List<jge.Entity> candidates,
  ) {
    view.screenToRay(screen, _ray);
    final hits = <(double, jge.Entity, double)>[];
    for (final entity in candidates) {
      if (!boundsOf(entity, _box)) continue;
      final t = _ray.intersectAabb(_box);
      if (t != null) hits.add((t, entity, _volumeOf(_box)));
    }
    if (hits.isEmpty) return null;
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    final tests = _tests?.call() ?? const <EntityRayTest>[];
    jge.Entity? best;
    var bestT = double.infinity;
    // Boxes the ray starts inside — a trigger, a water volume, around the
    // camera — meet it at 0, nearer than anything. Without an exact test
    // to say where their shape really is, they are picked only when
    // nothing else is under the pointer, the smallest first: else they
    // would win every click made from inside them.
    jge.Entity? around;
    var aroundVolume = double.infinity;
    for (final (boxT, entity, volume) in hits) {
      // A box no nearer than the best hit can't hold a nearer one.
      if (boxT >= bestT) break;
      double? exact;
      for (final test in tests) {
        exact = test.distanceTo(entity, _ray);
        if (exact != null) break;
      }
      if (exact == null && boxT <= 0) {
        if (volume < aroundVolume) {
          aroundVolume = volume;
          around = entity;
        }
        continue;
      }
      final t = exact ?? boxT;
      if (t < bestT) {
        bestT = t;
        best = entity;
      }
    }
    return best ?? around;
  }

  static double _volumeOf(jge.Aabb3 box) =>
      (box.max.x - box.min.x) *
      (box.max.y - box.min.y) *
      (box.max.z - box.min.z);

  /// Where something placed at [screen] goes: on the nearest of
  /// [candidates] under the pointer ([placementAlong]), or else on the
  /// ground, facing up.
  SurfacePoint placementAt(
    EditorView view,
    Offset screen,
    Iterable<jge.Entity> candidates,
  ) {
    view.screenToRay(screen, _ray);
    return placementAlong(_ray, candidates) ??
        SurfacePoint(view.screenToGround(screen), jge.Vector3(0, -1, 0));
  }

  /// Where [ray] first meets one of [candidates]: its real surface where
  /// an [EntitySurfaceTest] knows it (a miss of its shape passes through,
  /// as through an arch), else the face of its box, facing out. Null when
  /// it meets none.
  SurfacePoint? placementAlong(jge.Ray3 ray, Iterable<jge.Entity> candidates) {
    final hits = <(double, jge.Entity, jge.Aabb3)>[];
    for (final entity in candidates) {
      final box = jge.Aabb3();
      if (!boundsOf(entity, box)) continue;
      final t = ray.intersectAabb(box);
      if (t != null && t >= 0) hits.add((t, entity, box));
    }
    if (hits.isEmpty) return null;
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    final tests = [...?_tests?.call().whereType<EntitySurfaceTest>()];
    var bestT = double.infinity;
    jge.Entity? onto;
    jge.Vector3? facing;
    jge.Aabb3? ontoBox;
    for (final (boxT, entity, box) in hits) {
      // A box no nearer than the best hit can't hold a nearer one.
      if (boxT >= bestT) break;
      RayTriangleHit? exact;
      for (final test in tests) {
        exact = test.surfaceHit(entity, ray);
        if (exact != null) break;
      }
      if (exact != null) {
        if (exact.t < bestT) {
          bestT = exact.t;
          onto = entity;
          facing = exact.normal;
          ontoBox = null;
        }
      } else if (boxT > 0 && boxT < bestT) {
        bestT = boxT;
        onto = entity;
        facing = null;
        ontoBox = box;
      }
    }
    if (onto == null) return null;
    final at = jge.Vector3.zero();
    ray.atInto(bestT, at);
    return SurfacePoint(at, facing ?? _faceOf(at, ontoBox!), onto: onto);
  }

  /// Which face of [box] [at] is on: the side it is nearest, for the box's
  /// size, facing out.
  static jge.Vector3 _faceOf(jge.Vector3 at, jge.Aabb3 box) {
    final size = jge.Vector3.zero();
    box.sizeInto(size);
    double near(double v, double lo, double hi, double extent) {
      final d = (v - lo).abs() < (v - hi).abs()
          ? (v - lo).abs()
          : (v - hi).abs();
      return d / (extent > 1e-9 ? extent : 1e-9);
    }

    final dx = near(at.x, box.min.x, box.max.x, size.x);
    final dy = near(at.y, box.min.y, box.max.y, size.y);
    final dz = near(at.z, box.min.z, box.max.z, size.z);
    double side(double v, double lo, double hi) =>
        (v - lo).abs() < (v - hi).abs() ? -1 : 1;
    final normal = dy <= dx && dy <= dz
        ? jge.Vector3(0, side(at.y, box.min.y, box.max.y), 0)
        : dx <= dz
        ? jge.Vector3(side(at.x, box.min.x, box.max.x), 0, 0)
        : jge.Vector3(0, 0, side(at.z, box.min.z, box.max.z));
    return normal;
  }

  @override
  List<jge.Entity> pickInRect(
    EditorView view,
    Rect screenRect,
    Iterable<jge.Entity> candidates,
  ) {
    final out = <jge.Entity>[];
    final centre = jge.Vector3.zero();
    for (final entity in candidates) {
      if (!boundsOf(entity, _box)) continue;
      _box.centerInto(centre);
      final at = view.projectToScreen(centre);
      if (at != null && screenRect.contains(at)) out.add(entity);
    }
    return out;
  }

  static final jge.Aabb3 _local = jge.Aabb3();
  static final jge.Aabb3 _part = jge.Aabb3();
  static final jge.Matrix4 _matrix = jge.Matrix4.identity();

  /// [entity]'s box in world space into [out]; false without a transform.
  static bool boundsOf(jge.Entity entity, jge.Aabb3 out) {
    final transform = entity.getComponent<jge.TransformComponent>();
    if (transform == null) return false;
    localBoundsOf(entity.components, entity.world?.context.definitions, _local);
    transform.localToWorldInto(_matrix);
    _local.transformInto(_matrix, out);
    return true;
  }

  /// The box [components] take up about their entity's origin, before its
  /// transform: the union of their 3-D extents ([definitions] knows them),
  /// or a half-metre cube when none has one. What a box in space is built
  /// from — and a preview of something not made yet.
  static void localBoundsOf(
    Iterable<jge.Component> components,
    jge.ComponentDefinitionRegistry? definitions,
    jge.Aabb3 out,
  ) {
    out.setEmpty();
    if (definitions != null) {
      for (final component in components) {
        final extent = definitions.definitionFor(component)?.extent;
        if (extent != null && extent.boundsInto(component, _part)) {
          out.addBox(_part);
        }
      }
    }
    if (out.isEmpty) out.setValues(-0.25, -0.25, -0.25, 0.25, 0.25, 0.25);
  }
}
