import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_signals/just_signals.dart';

import '../designer/array_3d.dart';
import '../designer/working_plane.dart';
import '../view/ray_entity_picker.dart';

/// How the 3-D view draws the scene: as the game does, its colours only,
/// its edges, or what things collide with.
enum ViewMode3D {
  lit('Lit', 'As the game draws it: its lights and shadows'),
  unlit('Unlit', 'Colours only, shaded a little: to read shapes by'),
  wireframe('Wire', 'Every edge, nothing filled'),
  collision('Collision', 'What things collide with, over the scene unlit');

  const ViewMode3D(this.label, this.description);

  /// Its name on a button.
  final String label;

  /// What it shows.
  final String description;
}

/// Where the 3-D gizmo sits on what is selected, and what it turns and
/// scales about.
enum PivotMode3D {
  /// The middle of the selection's box.
  centre('Centre', 'The middle of what is selected'),

  /// The selected thing's own origin (the first one's, for several).
  pivot('Pivot', "The first selected thing's own origin"),

  /// The middle of the bottom of the selection's box: what it stands on.
  base('Base', 'The middle of the bottom of what is selected');

  const PivotMode3D(this.label, this.description);

  /// Its name on a button.
  final String label;

  /// What it means.
  final String description;
}

/// How the 3-D Level Designer is set up to build — the working plane it
/// places on where nothing else is under the pointer, and whether that
/// plane keeps to the selection — and how its view draws the scene: the
/// view mode, the selection's outline, a slice.
///
/// Editor-only and on the scope, like the hidden and locked sets: the gizmo,
/// the grid and every 3-D tool read the same plane, designer open or not.
class Designer3DState {
  /// Which way the working plane lies.
  final Signal<WorkingPlaneAxis> planeAxis = Signal(
    WorkingPlaneAxis.ground,
    debugLabel: 'planeAxis',
  );

  /// Where it lies on its axis (+Y is down: 2 m up is -2).
  final Signal<double> planeOffset = Signal(0, debugLabel: 'planeOffset');

  /// Whether the plane moves to the selection: level with the base of what
  /// is selected, so the next thing goes beside it.
  final Signal<bool> followSelection = Signal(
    false,
    debugLabel: 'planeFollowsSelection',
  );

  /// How the scene is drawn.
  final Signal<ViewMode3D> viewMode = Signal(
    ViewMode3D.lit,
    debugLabel: 'viewMode3D',
  );

  /// Whether the selection's edges are drawn over the scene.
  final Signal<bool> outline = Signal(true, debugLabel: 'outline3D');

  /// Whether what is above [sliceY] is taken away, to see inside.
  final Signal<bool> sliceOn = Signal(false, debugLabel: 'sliceOn');

  /// The slice's height (engine Y: 2 m up is -2).
  final Signal<double> sliceY = Signal(-2, debugLabel: 'sliceY');

  /// Where the gizmo sits on the selection.
  final Signal<PivotMode3D> pivotMode = Signal(
    PivotMode3D.pivot,
    debugLabel: 'pivotMode3D',
  );

  /// Whether a move puts what is moved on the surface under the pointer.
  final Signal<bool> surfaceSnap = Signal(false, debugLabel: 'surfaceSnap');

  /// Whether a move lines what is moved up with the boxes of things near
  /// it: side to side, top to bottom.
  final Signal<bool> boundsSnap = Signal(false, debugLabel: 'boundsSnap');

  // ── Placing ─────────────────────────────────────────────────────────

  /// Whether what is placed stands on the surface — its up along the
  /// surface's facing — rather than upright.
  final Signal<bool> alignToSurface = Signal(false, debugLabel: 'alignToSurface');

  /// How far what is placed is spun about its up (degrees): Shift+wheel
  /// while placing.
  final Signal<double> placeSpin = Signal(0, debugLabel: 'placeSpin');

  /// How far each placement is turned at random about its up, either way
  /// (degrees; 0 for none).
  final Signal<double> randomTurn = Signal(0, debugLabel: 'randomTurn');

  /// How far each placement's size varies at random, either way (a
  /// fraction: 0.2 for 80-120 %; 0 for none).
  final Signal<double> randomSize = Signal(0, debugLabel: 'randomSize');

  /// Whether a drag while placing stamps a trail of copies.
  final Signal<bool> stamp = Signal(false, debugLabel: 'stamp');

  /// How far apart stamped copies are (metres).
  final Signal<double> stampSpacing = Signal(1, debugLabel: 'stampSpacing');

  /// The material file in hand: what painting puts on a shape or model.
  final Signal<String?> materialInHand = Signal(null, debugLabel: 'materialInHand');

  /// How Array lays out copies of the selection.
  final Signal<Array3DSpec> array = Signal(
    const Array3DSpec(),
    debugLabel: 'array3D',
  );

  /// The working plane as set.
  WorkingPlane get plane => WorkingPlane(planeAxis.value, planeOffset.value);

  /// Moves the plane [metres] along its normal — up for the ground.
  void raise(double metres) =>
      planeOffset.value = plane.moved(metres).offset;

  /// Turns the plane the next way round: ground, front, side.
  void cycleAxis() => planeAxis.value = planeAxis.value.next;

  /// The plane through [entities]' base — the bottom of their boxes for the
  /// ground, their middle for an upright plane — or as set when there are
  /// none.
  WorkingPlane planeAt(Iterable<jge.Entity> entities) {
    final box = jge.Aabb3(), one = jge.Aabb3();
    for (final e in entities) {
      if (RayEntityPicker.boundsOf(e, one)) box.addBox(one);
    }
    if (box.isEmpty) return plane;
    final axis = planeAxis.value;
    // +Y is down: the ground under something is its largest Y.
    final at = switch (axis) {
      WorkingPlaneAxis.ground => box.max.y,
      WorkingPlaneAxis.front => (box.min.z + box.max.z) / 2,
      WorkingPlaneAxis.side => (box.min.x + box.max.x) / 2,
    };
    return WorkingPlane(axis, at);
  }

  /// Puts the plane through [entities] (see [planeAt]).
  void moveTo(Iterable<jge.Entity> entities) =>
      planeOffset.value = planeAt(entities).offset;

  /// Releases the signals.
  void dispose() {
    materialInHand.dispose();
    alignToSurface.dispose();
    placeSpin.dispose();
    randomTurn.dispose();
    randomSize.dispose();
    stamp.dispose();
    stampSpacing.dispose();
    array.dispose();
    pivotMode.dispose();
    surfaceSnap.dispose();
    boundsSnap.dispose();
    viewMode.dispose();
    outline.dispose();
    sliceOn.dispose();
    sliceY.dispose();
    planeAxis.dispose();
    planeOffset.dispose();
    followSelection.dispose();
  }
}
