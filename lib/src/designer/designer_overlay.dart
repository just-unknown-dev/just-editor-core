import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../settings/gizmo_settings.dart';

import 'designer_canvas.dart';
import '../model/editor_history.dart';
import '../model/modifier_keys.dart';
import 'level_designer_controller.dart';
import '../view/editor_view.dart';

/// Everything an overlay needs to draw itself.
class OverlayPaintContext {
  const OverlayPaintContext({
    required this.draw,
    required this.world,
    required this.controller,
    this.showsGizmo = _always,
  });

  static bool _always(GizmoKind kind) => true;

  /// Screen-space drawing helpers and world/screen conversion.
  final DesignerCanvas draw;

  /// The world being edited, for querying whatever the overlay visualises.
  final jge.World world;

  /// Designer state: selection, active tool, guides.
  final LevelDesignerController controller;

  /// Whether gizmos of a kind are drawn now, in the editor's mode. An
  /// overlay that is not a gizmo ([DesignerOverlay.gizmoKind] null) but
  /// draws an outline beside its handles asks for [GizmoKind.selection].
  final bool Function(GizmoKind kind) showsGizmo;

  /// The entity currently selected, if any.
  jge.Entity? get selected => controller.sceneState.selectedEntity.value;

  /// Whether [entity] is part of the current selection.
  bool isSelected(jge.Entity entity) =>
      controller.sceneState.selectedEntity.value?.id == entity.id ||
      controller.sceneState.isInMultiSelection(entity.id);

  /// Whether [entity] is drawn in the viewport — not hidden by its eye, its
  /// layer, or the designer keeping to the Level Map. An overlay about an
  /// entity draws nothing for one that is not.
  bool isShown(jge.Entity entity) => controller.isShownInViewport(entity);

  /// Whether [entity]'s gizmos may be drawn: not hidden by its eye or its
  /// layer, on the Level Map or off it. A gizmo overlay (its
  /// [DesignerOverlay.gizmoKind] set) asks this rather than [isShown]: its
  /// gizmos are drawn only once asked for, and then for the whole scene.
  bool showsGizmosOf(jge.Entity entity) => controller.showsGizmosOf(entity);
}

/// Something drawn over the level in the designer viewport.
///
/// Overlays are how a project visualises concepts the generic editor knows
/// nothing about — a patrol route, a spawn radius, a navmesh, a trigger volume.
/// Each gets its own toggle in the designer's status bar, so an author can turn
/// off what they are not working on.
///
/// Overlays draw in screen space through [DesignerCanvas]; see its notes on why.
abstract class DesignerOverlay {
  /// Stable identifier, also the key for its visibility toggle.
  String get id;

  /// Short label for the toggle, e.g. 'Paths'.
  String get label;

  /// Icon for the toggle.
  IconData get icon;

  /// Tooltip explaining what it shows.
  String? get description => null;

  /// Whether it starts visible.
  bool get defaultVisible => true;

  /// Which kind of the editor's gizmos it is: an aid drawn over the level
  /// (a path, a frame, bounds, an outline), drawn and handed the pointer
  /// only while the Gizmos button shows that kind in the editor's mode.
  /// Null for what a tool in use draws (a drag box, a brush, a ghost, the
  /// selection's handles) and for the designer's own rulers, guides and
  /// minimap, which are always there.
  GizmoKind? get gizmoKind => GizmoKind.aids;

  /// Which scene modes it draws in. 2-D unless it says otherwise.
  jge.Dimensions get dimensions => jge.Dimensions.twoD;

  /// Paint order. Lower draws first (further back).
  ///
  /// The built-in overlays occupy the [OverlayOrder] band; a project overlay
  /// that should sit under the selection outlines belongs below
  /// [OverlayOrder.selection].
  int get order => OverlayOrder.content;

  /// Draws the overlay.
  void paint(OverlayPaintContext context);
}

/// Conventional [DesignerOverlay.order] values for the built-in overlays, so a
/// project can slot its own overlay into the right depth without guessing.
abstract final class OverlayOrder {
  /// Regions and areas — drawn first, behind everything.
  static const int region = 100;

  /// Level content annotations: paths, links, radii.
  static const int content = 200;

  /// Alignment guides.
  static const int guides = 300;

  /// Selection outlines and the drag rectangle.
  static const int selection = 400;

  /// Measurements and readouts.
  static const int measurement = 500;

  /// Rulers — drawn last, over everything, pinned to the viewport edges.
  static const int chrome = 600;
}

/// The overlays available in the designer.
///
/// Mirrors [PrefabRegistry] so a project extends the viewport the same way it
/// extends the palette.
class OverlayRegistry {
  OverlayRegistry();

  final Map<String, DesignerOverlay> _overlays = {};

  /// The mode of the scene being edited; overlays that do not belong in it
  /// are left out of [all]. Null offers everything.
  jge.SceneMode Function()? modeOf;

  /// The registered overlays for the scene's mode, sorted back-to-front by
  /// [DesignerOverlay.order].
  List<DesignerOverlay> get all {
    final mode = modeOf?.call();
    final sorted = [
      for (final o in _overlays.values)
        if (mode == null || o.dimensions.allows(mode)) o,
    ]..sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(sorted);
  }

  /// Looks up an overlay by id.
  DesignerOverlay? byId(String id) => _overlays[id];

  /// Registers [overlay], replacing any existing one with the same id.
  void register(DesignerOverlay overlay) => _overlays[overlay.id] = overlay;

  /// Registers several overlays.
  void registerAll(Iterable<DesignerOverlay> overlays) {
    for (final overlay in overlays) {
      register(overlay);
    }
  }

  /// Removes every registration, ahead of rebuilding from extensions.
  void clear() => _overlays.clear();
}

/// What an interactive overlay is given for a pointer event on the canvas,
/// in screen space.
class OverlayPointerContext {
  const OverlayPointerContext({
    required this.screen,
    required this.canvasSize,
    required this.area,
    required this.camera,
    required this.world,
    required this.controller,
    required this.history,
    required this.modifiers,
    required this.gridSize,
  });

  /// The pointer, on the canvas.
  final Offset screen;

  /// The whole canvas.
  final Size canvasSize;

  /// The part of the canvas not covered by panels.
  final Rect area;

  final EditorView camera;
  final jge.World world;
  final LevelDesignerController controller;

  /// Where an overlay records an undoable edit (a moved guide, say).
  final EditorHistory history;

  final ModifierKeys modifiers;
  final double gridSize;

  /// Whether snapping applies right now, folding in the Ctrl override.
  bool get snapping => controller.snapEnabled.value && !modifiers.control;
}

/// An overlay that also takes pointer input: rulers you drag guides out of,
/// a minimap you click to jump. Offered every press before any tool, topmost
/// first; the one that returns true from [onPointerDown] owns the gesture.
mixin InteractiveOverlay on DesignerOverlay {
  /// Return true to claim the gesture.
  bool onPointerDown(OverlayPointerContext context) => false;

  void onPointerMove(OverlayPointerContext context) {}

  void onPointerUp(OverlayPointerContext context) {}

  /// The gesture was abandoned; discard any in-progress state.
  void onCancel() {}
}
