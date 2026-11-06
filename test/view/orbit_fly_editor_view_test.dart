// The 3-D view: it puts its orbit on the camera, a pose it is given comes
// back as given, and a ray through the middle of the view runs from the eye
// to the pivot.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  OrbitFlyEditorView viewOn(OutputCamera camera) {
    final view = OrbitFlyEditorView.of(camera)
      ..viewportSize = const Size(800, 600);
    view.sync();
    return view;
  }

  test('is a 3-D view the camera follows', () {
    final view = viewOn(OutputCamera());
    expect(view.isPlanar, isFalse);
    expect(view.camera.isPlanar, isFalse);
  });

  test('a pose given comes back as given', () {
    final view = viewOn(OutputCamera());
    const given = View3DPose(
      x: 2,
      y: -1,
      z: 3,
      distance: 7,
      yaw: 0.4,
      pitch: -0.3,
    );
    view.pose = given;
    expect(view.pose.toJson(), given.toJson());
    expect(View3DPose.fromJson(given.toJson()).toJson(), given.toJson());
  });

  test('the middle of the view looks from the eye at the pivot', () {
    final view = viewOn(OutputCamera());
    final ray = view.screenToRay(const Offset(400, 300));
    final toPivot = (view.pivot - view.eye)..normalize();
    expect(ray.direction.dot(toPivot), closeTo(1, 1e-6));
  });
}
