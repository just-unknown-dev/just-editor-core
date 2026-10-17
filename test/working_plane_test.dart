// The 3-D designer's working plane: where a ray meets it, snapping in it,
// moving and turning it, putting it at the base of the selection, and what
// a 3-D tool is told of the pointer — the surface under it, or the plane.
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';

/// A ray from [origin] towards [to].
Ray3 _ray(Vector3 origin, Vector3 to) =>
    Ray3.originDirection(origin, (to - origin)..normalize());

void main() {
  group('the plane', () {
    test('a ray meets the ground where it comes down on it', () {
      final hit = WorkingPlane.ground.intersect(
        _ray(Vector3(0, -10, 0), Vector3(3, 0, 4)),
      )!;
      expect([hit.x, hit.y, hit.z], [closeTo(3, 1e-9), 0, closeTo(4, 1e-9)]);
    });

    test('raised, it is met higher up: up is -Y', () {
      final plane = WorkingPlane.ground.moved(2);
      expect(plane.offset, -2);
      final hit = plane.intersect(_ray(Vector3(0, -10, 0), Vector3(0, 0, 8)))!;
      expect(hit.y, -2);
      expect(hit.z, closeTo(6.4, 1e-9));
    });

    test('a ray along it or away from it misses', () {
      expect(
        WorkingPlane.ground.intersect(
          Ray3.originDirection(Vector3(0, -1, 0), Vector3(1, 0, 0)),
        ),
        isNull,
      );
      expect(
        WorkingPlane.ground.intersect(
          Ray3.originDirection(Vector3(0, -1, 0), Vector3(0, -1, 0)),
        ),
        isNull,
        reason: 'looking up from above it',
      );
    });

    test('the front and side planes are upright', () {
      final front = const WorkingPlane(WorkingPlaneAxis.front, 5);
      final hit = front.intersect(_ray(Vector3(1, -1, 0), Vector3(1, -1, 10)))!;
      expect([hit.x, hit.y, hit.z], [closeTo(1, 1e-9), closeTo(-1, 1e-9), 5]);
      expect(front.moved(1).offset, 6);
      final side = const WorkingPlane(WorkingPlaneAxis.side, -3);
      expect(side.intersect(_ray(Vector3.zero(), Vector3(-6, 0, 2)))!.x, -3);
    });

    test('snapping in it leaves the coordinate across it', () {
      final p = const WorkingPlane(
        WorkingPlaneAxis.ground,
        -1.3,
      ).snapInPlane(Vector3(0.6, -1.3, 1.1), 0.5);
      expect([p.x, p.y, p.z], [0.5, -1.3, 1.0]);
      final w = const WorkingPlane(
        WorkingPlaneAxis.front,
        2,
      ).snapInPlane(Vector3(0.6, -1.3, 2), 0.5);
      expect([w.x, w.y, w.z], [0.5, -1.5, 2]);
    });

    test('turning goes ground, front, side and round', () {
      expect(WorkingPlaneAxis.ground.next, WorkingPlaneAxis.front);
      expect(WorkingPlaneAxis.front.next, WorkingPlaneAxis.side);
      expect(WorkingPlaneAxis.side.next, WorkingPlaneAxis.ground);
      expect(
        WorkingPlane.ground.through(Vector3(1, -4, 2)),
        const WorkingPlane(WorkingPlaneAxis.ground, -4),
      );
    });
  });

  group('the state', () {
    test('raised and turned, the plane follows', () {
      final state = Designer3DState();
      addTearDown(state.dispose);
      state.raise(1.5);
      expect(state.plane, const WorkingPlane(WorkingPlaneAxis.ground, -1.5));
      state.cycleAxis();
      expect(state.plane.axis, WorkingPlaneAxis.front);
    });

    test('at the selection: the ground under it, an upright plane through it', () {
      final world = World()..initialize();
      addTearDown(world.dispose);
      final state = Designer3DState();
      addTearDown(state.dispose);
      // A half-metre default box: its centre 3 m up, its base 2.75 m up.
      final e = world.createEntityWithComponents([
        TransformComponent(position: Vector3(4, -3, 1)),
      ]);
      state.moveTo([e]);
      expect(state.plane.offset, closeTo(-2.75, 1e-9));
      state.planeAxis.value = WorkingPlaneAxis.side;
      expect(state.planeAt([e]).offset, closeTo(4, 1e-9));
      expect(state.planeAt(const []).offset, state.plane.offset);
    });
  });

  group('what a 3-D tool is told', () {
    late World world;
    late GameCameraEditorView flat;

    setUp(() {
      world = World()..initialize();
      flat = GameCameraEditorView.of(Camera(viewportSize: const Size(10, 10)));
    });
    tearDown(() => world.dispose());

    test('with nothing under the pointer, the surface is the plane', () {
      final view = _LookingDown();
      final space = SpaceContext(
        view: view,
        screen: Offset.zero,
        surfaceOf: (_) => SurfacePoint(Vector3(9, 0, 9), Vector3(0, -1, 0)),
        plane: WorkingPlane.ground.moved(2),
      );
      final at = space.surface();
      expect(at.position.y, -2, reason: 'on the raised plane, not the ground');
      expect([at.normal.x, at.normal.y, at.normal.z], [0, -1, 0]);
      expect(space.planeHit, isNotNull);
    });

    test('something under it wins over the plane', () {
      final box = world.createEntityWithComponents([TransformComponent()]);
      final space = SpaceContext(
        view: _LookingDown(),
        screen: Offset.zero,
        surfaceOf: (_) =>
            SurfacePoint(Vector3(0, -0.25, 0), Vector3(0, -1, 0), onto: box),
        plane: WorkingPlane.ground.moved(2),
      );
      expect(space.surface().onto, box);
      expect(space.surface().position.y, -0.25);
    });

    test('snapped across the surface it lands on, when snapping', () {
      SpaceContext make({required bool snapping}) => SpaceContext(
        view: _LookingDown(),
        screen: Offset.zero,
        surfaceOf: (_) => SurfacePoint(Vector3(1.1, -0.3, 2.6), Vector3(1, 0, 0), onto: world.createEntity()),
        moveStep: 0.5,
        snapping: snapping,
      );
      final on = make(snapping: true).snappedSurface().position;
      expect([on.x, on.y, on.z], [1.1, -0.5, 2.5], reason: 'a wall: X stays');
      final off = make(snapping: false).snappedSurface().position;
      expect([off.x, off.y, off.z], [1.1, -0.3, 2.6]);
      expect(flat.isPlanar, isTrue);
    });
  });

  test('the 3-D move step is kept in the settings', () {
    const s = OverlayUiSettings.defaults();
    expect(s.moveStep3D, OverlayUiSettings.defaultMoveStep3D);
    final changed = s.copyWith(moveStep3D: 0.5);
    expect(changed.moveStep3D, 0.5);
    expect(changed == s, isFalse);
    expect(changed.copyWith(moveStep3D: 0.25) == s, isTrue);
  });
}

/// A view straight down from 10 m above the origin: every pixel's ray goes
/// down.
class _LookingDown implements EditorView {
  @override
  Ray3 screenToRay(Offset screen, [Ray3? out]) =>
      (out ?? Ray3())..setValues(0, -10, 0, 0, 1, 0);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
