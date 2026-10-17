// Setting things down in 3-D: where a ray meets a real surface and which
// way it faces, the turn that stands something on it, resting on it by its
// box, the random part rolled ahead, the copies an array makes, and the
// favourites kept in the preferences.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';

/// A quad lying flat at y = 0, 2 m across.
ModelGeometry _floor() => ModelGeometry(
  Float32List.fromList([-1, 0, -1, 1, 0, -1, 1, 0, 1, -1, 0, 1]),
  Uint32List.fromList([0, 1, 2, 0, 2, 3]),
);

/// Knows [entity]'s surface: a floor at its position, or nothing there.
class _Floors implements EntityRayTest, EntitySurfaceTest {
  _Floors(this.known, {this.misses = const {}});

  final Set<Entity> known;
  final Set<Entity> misses;

  @override
  double? distanceTo(Entity entity, Ray3 ray) => surfaceHit(entity, ray)?.t;

  @override
  RayTriangleHit? surfaceHit(Entity entity, Ray3 ray) {
    if (misses.contains(entity)) return RayTriangleHit(double.infinity, Vector3(0, -1, 0));
    if (!known.contains(entity)) return null;
    final world = Matrix4.identity();
    entity.getComponent<TransformComponent>()!.localToWorldInto(world);
    return RayTriangles.nearestPlaced(_floor(), world, ray);
  }
}

void _near(Vector3 v, List<double> expected, [double tolerance = 1e-6]) {
  expect(v.x, closeTo(expected[0], tolerance));
  expect(v.y, closeTo(expected[1], tolerance));
  expect(v.z, closeTo(expected[2], tolerance));
}

void main() {
  group('where a ray meets a surface', () {
    test('which way the triangle faces, towards where the ray came from', () {
      final down = RayTriangles.nearest(_floor(), Vector3(0, -3, 0), Vector3(0, 1, 0))!;
      expect(down.t, closeTo(3, 1e-9));
      _near(down.normal, [0, -1, 0]);
      final up = RayTriangles.nearest(_floor(), Vector3(0, 3, 0), Vector3(0, -1, 0))!;
      _near(up.normal, [0, 1, 0], 1e-9);
    });

    test('a placed surface faces as it is turned, however it is sized', () {
      // Turned a quarter about Z: the floor becomes a wall facing ±X.
      final world = Matrix4.identity();
      TransformComponent(position: Vector3(5, 0, 0), scale: Vector3(3, 1, 1))
        ..setEuler(0, 0, math.pi / 2)
        ..localToWorldInto(world);
      final ray = Ray3()..setValues(0, 0, 0, 1, 0, 0);
      final hit = RayTriangles.nearestPlaced(_floor(), world, ray)!;
      expect(hit.t, closeTo(5, 1e-6));
      _near(hit.normal, [-1, 0, 0]);
    });

    test('placement takes the real surface, and passes through a miss', () {
      final world = World()..initialize();
      addTearDown(world.dispose);
      final near = world.createEntityWithComponents([TransformComponent(position: Vector3(0, -4, 0))]);
      final far = world.createEntityWithComponents([TransformComponent(position: Vector3(0, -1, 0))]);
      final ray = Ray3()..setValues(0, -10, 0, 0, 1, 0);
      final through = RayEntityPicker(tests: () => [_Floors({far}, misses: {near})]).placementAlong(ray, [near, far])!;
      expect(through.onto, same(far), reason: 'the near one is not there');
      _near(through.position, [0, -1, 0]);
      _near(through.normal, [0, -1, 0]);
      final none = RayEntityPicker().placementAlong(Ray3()..setValues(9, -10, 9, 0, 1, 0), [near, far]);
      expect(none, isNull);
    });
  });

  group('setting something down', () {
    final ground = SurfacePoint(Vector3(2, 0, 3), Vector3(0, -1, 0));
    final wall = SurfacePoint(Vector3(4, -1, 0), Vector3(1, 0, 0));
    final cube = Aabb3()..setValues(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5);

    test('stood on a surface, its up along the facing', () {
      final turn = Placement3D.turnFor(wall, align: true);
      final up = Vector3.copy(Placement3D.up);
      turn.rotate(up);
      _near(up, [1, 0, 0]);
      final upright = Placement3D.turnFor(wall);
      final same = Vector3.copy(Placement3D.up);
      upright.rotate(same);
      _near(same, [0, -1, 0], 1e-9);
    });

    test('spun about its up', () {
      final turn = Placement3D.turnFor(ground, spinDegrees: 90);
      final forward = Vector3(0, 0, 1);
      turn.rotate(forward);
      expect(forward.y, closeTo(0, 1e-9));
      expect(forward.x.abs(), closeTo(1, 1e-9));
    });

    test('resting on the surface by its box', () {
      _near(Placement3D.restingAt(ground, cube, Quaternion.identity(), Vector3(1, 1, 1)), [2, -0.5, 3]);
      _near(Placement3D.restingAt(ground, cube, Quaternion.identity(), Vector3(2, 2, 2)), [2, -1, 3]);
      _near(Placement3D.restingAt(wall, cube, Quaternion.identity(), Vector3(1, 1, 1)), [4.5, -1, 0]);
      // A box off its origin: its middle goes over the point.
      final high = Aabb3()..setValues(-0.5, -2, -0.5, 0.5, 0, 0.5);
      _near(Placement3D.restingAt(ground, high, Quaternion.identity(), Vector3(1, 1, 1)), [2, 0, 3]);
      final flat = Aabb3()..setValues(-1, 0, -1, 1, 0, 1);
      expect(Placement3D.restingAt(ground, flat, Quaternion.identity(), Vector3(1, 1, 1)).y, closeTo(-0.001, 1e-9),
          reason: 'a hair off, not fighting the surface');
    });

    test('the random part is rolled ahead, within its ranges', () {
      final roll = PlacementRoll(seed: 7);
      expect([roll.turn, roll.size], [0, 1]);
      for (var i = 0; i < 50; i++) {
        roll.roll(turnRange: 45, sizeRange: 0.2);
        expect(roll.turn.abs(), lessThanOrEqualTo(45));
        expect(roll.size, inInclusiveRange(0.8, 1.2));
      }
      roll.roll(turnRange: 0, sizeRange: 0);
      expect([roll.turn, roll.size], [0, 1]);
    });
  });

  group('an array', () {
    final pivot = Vector3(10, 0, 0);

    test('in a row: the count with the original, each a step on', () {
      const spec = Array3DSpec(count: 4, stepX: 2, stepY: -1);
      final steps = spec.steps(pivot);
      expect(spec.total, 4);
      expect(steps, hasLength(3));
      _near(steps.last.apply(pivot), [16, -3, 0]);
    });

    test('in a grid, floors going up', () {
      const spec = Array3DSpec(mode: ArrayMode3D.grid, columns: 3, floors: 2, rows: 2, spacingX: 1, spacingY: 3, spacingZ: 2);
      expect(spec.total, 12);
      final at = [for (final s in spec.steps(Vector3.zero())) s.apply(Vector3.zero())];
      expect(at, hasLength(11));
      expect(at.any((p) => p.x == 2 && p.y == -3 && p.z == 2), isTrue);
    });

    test('round a circle: all the way, or part way to the end', () {
      const full = Array3DSpec(mode: ArrayMode3D.radial, around: 4, radius: 5);
      final steps = full.steps(pivot);
      expect(steps, hasLength(3));
      // The middle is 5 m along -X: the copies go round it.
      final positions = [for (final s in steps) s.apply(pivot)];
      for (final p in positions) {
        expect((p - Vector3(5, 0, 0)).length, closeTo(5, 1e-9));
      }
      _near(positions[1], [0, 0, 0]);
      expect(steps.every((s) => s.turnsItself), isTrue);

      const half = Array3DSpec(mode: ArrayMode3D.radial, around: 3, radius: 5, sweep: 180, faceCentre: false);
      final ends = half.steps(pivot);
      _near(ends.last.apply(pivot), [0, 0, 0], 1e-9);
      expect(ends.any((s) => s.turnsItself), isFalse);
    });
  });

  test('favourites are kept by id, one per line', () {
    final pref = PrefabFavourites.pref;
    expect(pref.decode(pref.encode({'shape.cube', 'tp.coin'})), {'shape.cube', 'tp.coin'});
    expect(pref.decode(''), isEmpty);
  });
}
