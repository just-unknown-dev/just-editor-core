// Picking in 3-D from inside a box: a volume around the camera — a trigger,
// water — is what a click picks only when nothing else is under the
// pointer, so whatever is inside it can still be picked.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

/// A view whose every pixel looks from the origin along +Z.
class _AlongZ implements EditorView {
  @override
  Ray3 screenToRay(Offset screen, [Ray3? out]) {
    final ray = out ?? Ray3();
    ray.origin.setValues(0, 0, 0);
    ray.direction.setValues(0, 0, 1);
    return ray;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late World world;

  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
  });

  // A half-metre cube at [z], [size] times bigger.
  Entity box(double z, {double size = 1}) => world.createEntityWithComponents([
    TransformComponent(
      position: Vector3(0, 0, z),
      scale: Vector3(size, size, size),
    ),
  ]);

  test('a box around the camera does not win every click', () {
    final water = box(0, size: 200);
    final crate = box(5);
    final picker = RayEntityPicker();
    expect(picker.pickAt(_AlongZ(), Offset.zero, [water, crate]), crate);
  });

  test('with nothing else under the pointer, the smallest one around it', () {
    final water = box(0, size: 200);
    final room = box(0, size: 40);
    final picker = RayEntityPicker();
    expect(picker.pickAt(_AlongZ(), Offset.zero, [water, room]), room);
    expect(picker.pickAt(_AlongZ(), Offset.zero, [water]), water);
  });

  test('with an exact test, one around the camera is where its shape is', () {
    final terrain = box(0, size: 200);
    final crate = box(5);
    final picker = RayEntityPicker(
      tests: () => [
        _At({terrain: 2}),
      ],
    );
    expect(picker.pickAt(_AlongZ(), Offset.zero, [terrain, crate]), terrain);
  });
}

/// Knows exactly how far along the ray some entities' shapes are.
class _At implements EntityRayTest {
  _At(this.distances);

  final Map<Entity, double> distances;

  @override
  double? distanceTo(Entity entity, Ray3 ray) => distances[entity];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
