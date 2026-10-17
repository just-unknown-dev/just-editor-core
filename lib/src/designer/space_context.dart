import 'dart:ui' show Offset;

import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../view/editor_view.dart';
import '../view/ray_entity_picker.dart';
import 'working_plane.dart';

/// What a 3-D tool knows of the pointer, besides what every tool does: the
/// ray through it, what that ray meets, the working plane it builds on and
/// how it snaps.
///
/// Handed to tools through `ToolContext.space` while the view is in space
/// (a 3-D scene); null in 2-D. Built fresh for each pointer event, so a
/// tool never acts on a stale view.
final class SpaceContext {
  /// The pointer at [screen] on [view]; [surfaceOf] finds the drawn thing
  /// under it, leaving out what it is given to ignore.
  SpaceContext({
    required this.view,
    required this.screen,
    required SurfacePoint Function(Set<jge.Entity> ignore) surfaceOf,
    this.plane = WorkingPlane.ground,
    this.moveStep = 0,
    this.snapping = false,
  }) : ray = view.screenToRay(screen),
       _surfaceOf = surfaceOf;

  /// How the editor sees the scene.
  final EditorView view;

  /// The pointer on the canvas.
  final Offset screen;

  /// The ray from the eye through the pointer.
  final jge.Ray3 ray;

  /// The plane built on where nothing is under the pointer.
  final WorkingPlane plane;

  /// Metres moving snaps in; 0 when it does not.
  final double moveStep;

  /// Whether snapping applies right now: on, and Ctrl not held to suspend
  /// it.
  final bool snapping;

  final SurfacePoint Function(Set<jge.Entity> ignore) _surfaceOf;
  SurfacePoint? _surface;
  jge.Vector3? _planeHit;
  bool _planeDone = false;

  /// Where the ray meets the working [plane]; null when it runs along it
  /// or away from it.
  jge.Vector3? get planeHit {
    if (!_planeDone) {
      _planeDone = true;
      _planeHit = plane.intersect(ray);
    }
    return _planeHit;
  }

  /// The surface under the pointer — the nearest drawn thing's, by its
  /// real shape where a pick test knows it, else the working plane's — and
  /// which way it faces: where something placed there goes. [ignore]
  /// leaves things out, such as what is being placed.
  SurfacePoint surface({Set<jge.Entity> ignore = const {}}) {
    if (ignore.isEmpty) return _surface ??= _resolve(_surfaceOf(const {}));
    return _resolve(_surfaceOf(ignore));
  }

  /// [surface], its point snapped across the surface while [snapping]:
  /// along the ground's X and Z, a wall's two directions.
  SurfacePoint snappedSurface({Set<jge.Entity> ignore = const {}}) {
    final at = surface(ignore: ignore);
    if (!snapping || moveStep <= 0) return at;
    return SurfacePoint(
      snapAcross(at.position, at.normal, moveStep),
      at.normal,
      onto: at.onto,
    );
  }

  /// [point] on the nearest [moveStep] in the working plane's two
  /// directions while [snapping]; as it is otherwise.
  jge.Vector3 snapPoint(jge.Vector3 point) => snapping && moveStep > 0
      ? plane.snapInPlane(point, moveStep)
      : jge.Vector3.copy(point);

  // A miss of everything drawn lands on the working plane, facing its way;
  // the ground the picker fell back to stands in when the plane is out of
  // the ray's way.
  SurfacePoint _resolve(SurfacePoint found) {
    if (found.onto != null) return found;
    final hit = planeHit;
    if (hit == null) return found;
    return SurfacePoint(hit, plane.normal);
  }

  /// [point] on the nearest [step] in the two directions across a surface
  /// facing [normal]: the coordinate along its main axis is left, so the
  /// point stays on the surface.
  static jge.Vector3 snapAcross(
    jge.Vector3 point,
    jge.Vector3 normal,
    double step,
  ) {
    if (step <= 0) return jge.Vector3.copy(point);
    final ax = normal.x.abs(), ay = normal.y.abs(), az = normal.z.abs();
    final keep = ay >= ax && ay >= az ? 1 : (ax >= az ? 0 : 2);
    double s(double v) => (v / step).roundToDouble() * step;
    return jge.Vector3(
      keep == 0 ? point.x : s(point.x),
      keep == 1 ? point.y : s(point.y),
      keep == 2 ? point.z : s(point.z),
    );
  }
}
