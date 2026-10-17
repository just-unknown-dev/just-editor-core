// A ray against a triangle list: what picking by a model's or a shape's
// real shape measures with.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';

void main() {
  test('a ray meets the first triangle in its way, either side facing', () {
    final quad = ModelGeometry(
      Float32List.fromList([-1, -1, 4, 1, -1, 4, 1, 1, 4, -1, 1, 4]),
      Uint32List.fromList([0, 1, 2, 0, 2, 3]),
    );
    final t = RayTriangles.nearestHit(quad, Vector3.zero(), Vector3(0, 0, 2));
    expect(t, closeTo(2, 1e-9), reason: 'in units of the direction');
    expect(RayTriangles.nearestHit(quad, Vector3(3, 0, 0), Vector3(0, 0, 1)), isNull);
    expect(
      RayTriangles.nearestHit(quad, Vector3(0, 0, 8), Vector3(0, 0, -1)),
      closeTo(4, 1e-9),
      reason: 'from behind too',
    );
    expect(RayTriangles.nearestHit(quad, Vector3(0, 0, 5), Vector3(0, 0, 1)), isNull, reason: 'not behind the origin');
  });
}
