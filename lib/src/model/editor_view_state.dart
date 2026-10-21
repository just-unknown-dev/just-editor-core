/// What the editor is hiding and what it will not let you pick.
///
/// Editor-only: nothing here changes an entity or is saved with the scene.
/// Hiding clutter while building a level must never be the same act as
/// turning something off in the game — that is `Enabled`, which is saved.
///
/// It is on the scope rather than the Level Designer's controller: the eye
/// and the padlock are in the scene tree, and the tree is there whether or
/// not the designer is open.
library;

import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_signals/just_signals.dart';

import 'transform_mode.dart';

/// One editor's view-only state: the entities hidden in the viewport and
/// locked against picking, the entity the inspector is pinned to, and the
/// selection's gizmo.
///
/// The scope holds one (`EditorScope.view`), which the Level Designer's
/// controller shares. None of it is saved with the scene.
class EditorViewState {
  /// Entities hidden in the viewport (H, or everything else under
  /// isolate).
  final Signal<Set<jge.EntityId>> hidden = Signal(
    <jge.EntityId>{},
    debugLabel: 'hiddenEntities',
  );

  /// Entities the pointer passes straight through (L).
  final Signal<Set<jge.EntityId>> locked = Signal(
    <jge.EntityId>{},
    debugLabel: 'lockedEntities',
  );

  /// The entity the inspector is pinned to, if any.
  ///
  /// Unity's inspector lock: what is *shown* stops following what is
  /// *selected*, so a thing's components can be read while picking
  /// something else. Editor-only and never saved, like the rest of this.
  final Signal<jge.EntityId?> pinned = Signal<jge.EntityId?>(
    null,
    debugLabel: 'pinnedEntity',
  );

  /// Which gizmo the selection shows — All, Move, Scale or Rotate (Q, W,
  /// E, R). In the editor and the Level Designer alike, and kept between
  /// them.
  final Signal<TransformMode> transformMode = Signal(
    TransformMode.all,
    debugLabel: 'transformMode',
  );

  /// Whether the inspector is pinned to [id].
  bool isPinned(jge.EntityId id) => pinned.value == id;

  /// Pins [id], or releases it when it is already the pinned one. Only
  /// ever one: pinning another moves the pin rather than queueing.
  void togglePinned(jge.EntityId id) =>
      pinned.value = pinned.value == id ? null : id;

  /// Releases the pin, so the inspector follows the selection again.
  void unpin() => pinned.value = null;

  /// Whether [id] itself is hidden; [isHiddenIn] also counts the groups it
  /// is in.
  bool isHidden(jge.EntityId id) => hidden.value.contains(id);

  /// Whether [id] itself is locked; [isLockedIn] also counts the groups it
  /// is in.
  bool isLocked(jge.EntityId id) => locked.value.contains(id);

  /// Whether [entity] is hidden — itself, or a group it is in: hiding a
  /// group hides what it holds.
  bool isHiddenIn(jge.Entity entity) => _inChain(entity, hidden.value);

  /// Whether [entity] is locked — itself, or a group it is in.
  bool isLockedIn(jge.Entity entity) => _inChain(entity, locked.value);

  static bool _inChain(jge.Entity entity, Set<jge.EntityId> ids) {
    if (ids.isEmpty) return false;
    jge.Entity? at = entity;
    for (var guard = 0; at != null && guard < 64; guard++) {
      if (ids.contains(at.id)) return true;
      final parent = at.getComponent<jge.ParentComponent>()?.parentId;
      if (parent == null) return false;
      at = at.world?.getEntity(parent);
    }
    return false;
  }

  /// Hides every one of [ids], or shows them again when [hidden] is false.
  void setHidden(Iterable<jge.EntityId> ids, {required bool hidden}) {
    final next = Set<jge.EntityId>.from(this.hidden.value);
    hidden ? next.addAll(ids) : next.removeAll(ids);
    this.hidden.value = next;
  }

  /// Locks every one of [ids], or unlocks them when [locked] is false.
  void setLocked(Iterable<jge.EntityId> ids, {required bool locked}) {
    final next = Set<jge.EntityId>.from(this.locked.value);
    locked ? next.addAll(ids) : next.removeAll(ids);
    this.locked.value = next;
  }

  /// Hides [id], or shows it when it is hidden: the scene tree's eye.
  void toggleHidden(jge.EntityId id) => setHidden([id], hidden: !isHidden(id));

  /// Locks [id], or unlocks it when it is locked: the scene tree's padlock.
  void toggleLocked(jge.EntityId id) => setLocked([id], locked: !isLocked(id));

  /// Hides everything in [world] except [keep] and whatever is under it.
  ///
  /// The way to look at one thing in a busy level. Calling it with
  /// nothing kept shows everything again.
  void isolate(jge.World world, Iterable<jge.EntityId> keep) {
    if (keep.isEmpty) {
      hidden.value = <jge.EntityId>{};
      return;
    }
    final shown = <jge.EntityId>{};
    void keepSubtree(jge.EntityId id) {
      if (!shown.add(id)) return;
      final children = world
          .getEntity(id)
          ?.getComponent<jge.ChildrenComponent>();
      for (final child in children?.childIds ?? const <jge.EntityId>[]) {
        keepSubtree(child);
      }
    }

    for (final id in keep) {
      keepSubtree(id);
      // And everything above it, or the thing being looked at sits
      // inside something invisible.
      var entity = world.getEntity(id);
      var guard = 0;
      while (entity != null && guard++ < 64) {
        final parentId = entity.getComponent<jge.ParentComponent>()?.parentId;
        if (parentId == null) break;
        shown.add(parentId);
        entity = world.getEntity(parentId);
      }
    }

    hidden.value = {
      for (final entity in world.entities)
        if (entity.isActive && !shown.contains(entity.id)) entity.id,
    };
  }

  /// Shows every hidden entity again.
  void showAll() => hidden.value = <jge.EntityId>{};

  /// Unlocks every locked entity.
  void unlockAll() => locked.value = <jge.EntityId>{};

  /// Disposes the signals; the scope calls it when it is torn down.
  void dispose() {
    transformMode.dispose();
    pinned.dispose();
    hidden.dispose();
    locked.dispose();
  }
}
