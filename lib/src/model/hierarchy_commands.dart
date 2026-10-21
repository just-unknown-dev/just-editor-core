/// Undoable edits to the shape of a scene: who is under whom, in what
/// order, and what things are called.
///
/// Each edit is an [EditorCommand], so it can be undone, and a drag that
/// re-parents *and* re-orders is a single step.
library;

import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'scene_codec.dart';
import 'editor_commands.dart' show EntitySpec;
import 'editor_scene_state.dart';
import 'editor_history.dart';

/// Where an entity sat: its parent (by id) and its place among its
/// siblings, or among the roots.
class HierarchySlot {
  const HierarchySlot({required this.parentId, required this.index});

  /// The parent it was under, or null for a root.
  final jge.EntityId? parentId;

  /// Its place in that parent's children, or among the scene's roots.
  final int index;

  /// Where [entity] is now.
  factory HierarchySlot.of(
    jge.Entity entity, {
    required jge.World world,
    required EditorSceneState sceneState,
  }) {
    final parentId = entity.getComponent<jge.ParentComponent>()?.parentId;
    if (parentId == null) {
      return HierarchySlot(
        parentId: null,
        index: sceneState.rootIndexOf(entity.id, world: world),
      );
    }
    final children = world
        .getEntity(parentId)
        ?.getComponent<jge.ChildrenComponent>();
    return HierarchySlot(
      parentId: parentId,
      index: children?.childIds.indexOf(entity.id) ?? -1,
    );
  }

  @override
  String toString() => 'HierarchySlot($parentId, $index)';
}

/// Moves [entity] into a slot, detaching it from wherever it is.
///
/// One function so that re-parenting, re-ordering, grouping and the undo
/// of a delete all place an entity the same way — there is only one
/// description of what "being somewhere in the tree" means.
///
/// The slot's parent is found as it is now: one destroyed and made again
/// since the slot was taken ([EditorSceneState.entityRebuilt]) is the one
/// it was made again as. A root index counts the roots the tree shows.
void placeEntity(
  jge.Entity entity, {
  required jge.World world,
  required EditorSceneState sceneState,
  required HierarchySlot slot,
}) {
  detachEntity(entity, world: world, sceneState: sceneState);

  final slotParent = slot.parentId;
  final parent = slotParent == null
      ? null
      : world.getEntity(sceneState.currentId(slotParent));
  if (parent == null) {
    // A parent that is gone leaves it at the top level, at the end, rather
    // than in no list at all.
    entity.getComponent<jge.ParentComponent>()?.parentId = null;
    sceneState.moveRoot(
      entity.id,
      slot.index < 0 || slotParent != null ? 1 << 30 : slot.index,
      world: world,
    );
    return;
  }

  // The child keeps its place in the world — position, turn and scale,
  // in 3-D: its local transform is worked out against the new parent.
  final existing = entity.getComponent<jge.ParentComponent>();
  if (existing != null) {
    existing.parentId = parent.id;
  } else {
    entity.addComponent(jge.ParentComponent(parentId: parent.id));
  }

  var children = parent.getComponent<jge.ChildrenComponent>();
  if (children == null) {
    children = jge.ChildrenComponent();
    parent.addComponent(children);
  }
  final ids = children.childIds..remove(entity.id);
  ids.insert(
    slot.index < 0 ? ids.length : slot.index.clamp(0, ids.length),
    entity.id,
  );
  world.transformHierarchy.adopt(entity);
}

/// Takes [entity] out of whatever holds it — its parent's list of children,
/// or the top-level order — leaving it parentless and in neither until it
/// is placed again ([placeEntity]) or destroyed.
void detachEntity(
  jge.Entity entity, {
  required jge.World world,
  required EditorSceneState sceneState,
}) {
  final parentId = entity.getComponent<jge.ParentComponent>()?.parentId;
  if (parentId != null) {
    world
        .getEntity(parentId)
        ?.getComponent<jge.ChildrenComponent>()
        ?.removeChild(entity.id);
  }
  entity.getComponent<jge.ParentComponent>()?.parentId = null;
  sceneState.forgetRoot(entity.id);
}

/// Everything under [moving] — children, theirs, and so on — that is not
/// moving itself: what goes along when a parent is moved or turned.
///
/// A transform is where an entity is in the world, not where it is from its
/// parent, so a parent moved alone would leave its children behind.
List<jge.Entity> carriedWith(
  Iterable<jge.Entity> moving, {
  required jge.World world,
}) {
  final skip = {for (final e in moving) e.id};
  final out = <jge.Entity>[];
  void walk(jge.Entity entity) {
    final children = entity.getComponent<jge.ChildrenComponent>()?.childIds;
    if (children == null) return;
    for (final id in children) {
      final child = world.getEntity(id);
      if (child == null || !skip.add(id)) continue;
      if (child.hasComponent<jge.TransformComponent>()) out.add(child);
      walk(child);
    }
  }

  for (final e in moving) {
    walk(e);
  }
  return out;
}

/// Whether [candidate] is [entity] or somewhere under it.
///
/// What stops a parent being dropped into its own child, which would make
/// a loop nothing could draw or save.
bool isSelfOrDescendant(
  jge.Entity candidate,
  jge.Entity entity, {
  required jge.World world,
}) {
  if (candidate.id == entity.id) return true;
  final children = entity.getComponent<jge.ChildrenComponent>();
  if (children == null) return false;
  for (final id in children.childIds) {
    final child = world.getEntity(id);
    if (child == null) continue;
    if (isSelfOrDescendant(candidate, child, world: world)) return true;
  }
  return false;
}

/// Moves entities to a new place in the tree, as one undoable step.
///
/// Takes a list so that dragging a selection is one command rather than
/// one per entity, and so undo puts every one of them back at once.
///
/// Into a level map with a [mapLayer], they go on that layer of it; moved
/// anywhere else, they leave the map layer they were on.
class ReparentCommand extends EditorCommand {
  /// Moves `entities` under [parent] at [index].
  ///
  /// An entity whose ancestor is also in `entities` is left out: it goes
  /// along with that ancestor. Where each one is now is recorded here, for
  /// [undo].
  ReparentCommand({
    required this.label,
    required this.world,
    required this.sceneState,
    required List<jge.Entity> entities,
    required this.parent,
    this.index,
    this.mapLayer,
  }) : _entities = [
         // An entity whose own parent is also moving comes along with it;
         // moving both would take it out of its parent on the way.
         for (final e in entities)
           if (!entities.any(
             (other) =>
                 other.id != e.id && isSelfOrDescendant(e, other, world: world),
           ))
             e,
       ] {
    _before = [
      for (final e in _entities)
        HierarchySlot.of(e, world: world, sceneState: sceneState),
    ];
    _layerBefore = [
      for (final e in _entities) e.getComponent<jge.LayerComponent>()?.mapLayer,
    ];
  }

  @override
  final String label;

  /// The world the entities are in.
  final jge.World world;

  /// The editor's scene state: holds the top-level order, finds entities
  /// rebuilt since this was made, and is marked dirty after each step.
  final EditorSceneState sceneState;
  final List<jge.Entity> _entities;

  /// Where they are going; null moves them to the top level.
  final jge.Entity? parent;

  /// Where among that parent's children; null puts them last.
  final int? index;

  /// The layer of [parent]'s map they go on, when [parent] is a level map.
  final int? mapLayer;

  late final List<HierarchySlot> _before;
  late final List<int?> _layerBefore;

  /// Which of [_entities], by place in that list, were given a layer
  /// component to say which map layer they are on.
  final Set<int> _gaveLayer = {};

  void _setMapLayer(int i, jge.Entity entity, int? id) {
    var layer = entity.getComponent<jge.LayerComponent>();
    if (layer == null) {
      if (id == null) return;
      layer = jge.LayerComponent();
      entity.addComponent(layer);
      _gaveLayer.add(i);
    }
    layer.mapLayer = id;
  }

  /// The entities as they are now: one rebuilt since (an undone delete)
  /// is the one it was rebuilt as; one that is gone is null.
  List<jge.Entity?> get _live => [
    for (final e in _entities) sceneState.liveEntity(e),
  ];

  /// Whether this can run: false when there is nothing to move, when
  /// [parent] is gone, or when it would move something into itself or
  /// under its own child.
  bool get isValid {
    if (_entities.isEmpty) return false;
    final target = _target;
    if (parent != null && target == null) return false;
    if (target == null) return true;
    return !_live.any(
      (e) => e != null && isSelfOrDescendant(target, e, world: world),
    );
  }

  jge.Entity? get _target {
    final to = parent;
    return to == null ? null : sceneState.liveEntity(to);
  }

  @override
  void redo() {
    if (!isValid) return;
    final target = _target;
    final live = _live;
    // All of them out first: [index] counts the siblings that stay, as the
    // tree works it out. Taking each out only as it went in shifted the
    // ones put in before it.
    for (final entity in live) {
      if (entity != null) {
        detachEntity(entity, world: world, sceneState: sceneState);
      }
    }
    var at = index;
    final onMap = target?.hasComponent<jge.LevelMapComponent>() ?? false;
    for (var i = 0; i < live.length; i++) {
      final entity = live[i];
      if (entity == null) continue;
      placeEntity(
        entity,
        world: world,
        sceneState: sceneState,
        slot: HierarchySlot(parentId: target?.id, index: at ?? -1),
      );
      _setMapLayer(i, entity, onMap ? mapLayer : null);
      if (at != null) at++;
    }
    sceneState
      ..markDirty()
      ..refresh();
  }

  @override
  void undo() {
    final live = _live;
    for (final entity in live) {
      if (entity != null) {
        detachEntity(entity, world: world, sceneState: sceneState);
      }
    }
    // Then back in the order they stood, lowest place first: each place
    // was taken with all of them there, so filling them from the top puts
    // every one where it was.
    for (final i in _ascending(_before)) {
      final entity = live[i];
      if (entity == null) continue;
      placeEntity(
        entity,
        world: world,
        sceneState: sceneState,
        slot: _before[i],
      );
      if (_gaveLayer.remove(i)) {
        entity.removeComponent<jge.LayerComponent>();
      } else {
        entity.getComponent<jge.LayerComponent>()?.mapLayer = _layerBefore[i];
      }
    }
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// The positions of [slots], ordered by the place each one names — the
/// lowest first, and a slot with no place (-1) after all of them.
///
/// Putting entities back in this order puts each where it was: its place
/// was counted with all of them present, and everything before it is back
/// by the time it goes in.
List<int> _ascending(List<HierarchySlot> slots) {
  final order = [for (var i = 0; i < slots.length; i++) i];
  int key(int i) => slots[i].index < 0 ? 1 << 30 : slots[i].index;
  // Two at the same place keep the order they were given.
  order.sort((a, b) {
    final byPlace = key(a).compareTo(key(b));
    return byPlace != 0 ? byPlace : a.compareTo(b);
  });
  return order;
}

/// Moves one entity among its siblings, or among the roots.
class ReorderCommand extends EditorCommand {
  ReorderCommand({
    required this.label,
    required this.world,
    required this.sceneState,
    required this.entity,
    required this.index,
  }) : _before = HierarchySlot.of(entity, world: world, sceneState: sceneState);

  @override
  final String label;

  /// The world the entity is in.
  final jge.World world;

  /// The editor's scene state: holds the top-level order and is marked
  /// dirty after each step.
  final EditorSceneState sceneState;

  /// The entity to move; one rebuilt since (an undone delete) is found
  /// through [EditorSceneState.liveEntity].
  final jge.Entity entity;

  /// Where it is going among its siblings.
  final int index;

  final HierarchySlot _before;

  @override
  void redo() => _move(index);

  @override
  void undo() => _move(_before.index);

  void _move(int to) {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    placeEntity(
      live,
      world: world,
      sceneState: sceneState,
      slot: HierarchySlot(parentId: _before.parentId, index: to),
    );
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Renames an entity.
///
/// Names are how a scene file records who a child's parent is, so two
/// entities sharing one silently breaks the hierarchy on the next load.
/// [RenameCommand.isAvailable] is what the tree asks before it commits.
class RenameCommand extends EditorCommand {
  RenameCommand({
    required this.sceneState,
    required this.entity,
    required this.name,
  }) : _before = entity.name;

  @override
  String get label => 'Rename to $name';

  /// The editor's scene state, marked dirty after each step.
  final EditorSceneState sceneState;

  /// The entity to rename.
  final jge.Entity entity;

  /// The new name, trimmed when it is applied; an empty one leaves the
  /// entity with no name.
  final String name;

  /// The name it had — null for an entity that had none, which undo puts
  /// back as none.
  final String? _before;

  /// Whether [name] is free for [entity] in [world].
  static bool isAvailable(
    String name,
    jge.Entity entity, {
    required jge.World world,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    for (final other in world.entities) {
      if (other.id == entity.id) continue;
      if (other.name == trimmed) return false;
    }
    return true;
  }

  @override
  void redo() => _apply(name.trim());

  @override
  void undo() => _apply(_before);

  void _apply(String? value) {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    // Straight onto the entity: going through the scene state's rename
    // refuses an empty name, so an entity that had none kept the new one.
    live.name = value == null || value.isEmpty ? null : value;
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Whether an entity is on or off in the game.
///
/// Editor-only hiding is a different thing entirely — this one is saved
/// and the game honours it.
class SetEnabledCommand extends EditorCommand {
  SetEnabledCommand({
    required this.sceneState,
    required this.entity,
    required this.enabled,
  }) : _before = entity.isActive;

  @override
  String get label => enabled
      ? 'Enable ${entity.name ?? 'entity'}'
      : 'Disable ${entity.name ?? 'entity'}';

  /// The editor's scene state, marked dirty after each step.
  final EditorSceneState sceneState;

  /// The entity to switch on or off.
  final jge.Entity entity;

  /// The value given to the entity's saved Enabled flag (`isActive`).
  final bool enabled;
  final bool _before;

  @override
  void redo() => _apply(enabled);

  @override
  void undo() => _apply(_before);

  void _apply(bool value) {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    live.isActive = value;
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Puts entities inside a new group entity.
///
/// One command rather than a create and a move stitched together: those
/// capture what they need when they are *built*, and a group's children
/// move after the group exists. Undo takes the children back out and
/// destroys the group; redo makes a fresh one, so the command survives
/// being undone and redone even though ids are handed out again.
class GroupCommand extends EditorCommand {
  GroupCommand({
    required this.world,
    required this.sceneState,
    required List<jge.Entity> entities,
    required this.name,
    required this.position,
  }) : _entities = List.of(entities) {
    _before = [
      for (final e in _entities)
        HierarchySlot.of(e, world: world, sceneState: sceneState),
    ];
  }

  @override
  String get label =>
      'Group ${_entities.length} entit${_entities.length == 1 ? 'y' : 'ies'}';

  /// The world the group is made in.
  final jge.World world;

  /// The editor's scene state: registers the group, finds entities rebuilt
  /// since, and is marked dirty after each step.
  final EditorSceneState sceneState;
  final List<jge.Entity> _entities;

  /// What the group is called; the same name on a redo, so anything that
  /// refers to it by name still does.
  final String name;

  /// Where the group sits — the middle of what it holds.
  final jge.Vector3 position;

  late final List<HierarchySlot> _before;

  /// The group as it stands, or null while undone.
  jge.Entity? group;

  /// The id the group was last made with: a redo makes it again under a
  /// new one, and anything recorded against the old one is pointed at it.
  jge.EntityId? _groupId;

  @override
  void redo() {
    final made = world.createEntityWithComponents([
      jge.TransformComponent(
        position: jge.Vector3(position.x, position.y, position.z),
      ),
      jge.ChildrenComponent(),
    ], name: name);
    sceneState.registerEntity(made);
    if (_groupId case final was?) {
      sceneState.entityRebuilt(sceneState.currentId(was), made);
    }
    _groupId = made.id;
    group = made;
    for (final e in _entities) {
      final entity = sceneState.liveEntity(e);
      if (entity == null) continue;
      placeEntity(
        entity,
        world: world,
        sceneState: sceneState,
        slot: HierarchySlot(parentId: made.id, index: -1),
      );
    }
    sceneState
      ..markDirty()
      ..refresh();
  }

  @override
  void undo() {
    final live = [for (final e in _entities) sceneState.liveEntity(e)];
    for (final entity in live) {
      if (entity != null) {
        detachEntity(entity, world: world, sceneState: sceneState);
      }
    }
    final made = switch (_groupId) {
      final id? => world.getEntity(sceneState.currentId(id)),
      null => null,
    };
    if (made != null) {
      detachEntity(made, world: world, sceneState: sceneState);
      sceneState.removeEntityNode(made.id);
      world.destroyEntity(made);
    }
    group = null;
    // Back where they were, lowest place first, with the group gone: the
    // places were counted before it existed.
    for (final i in _ascending(_before)) {
      final entity = live[i];
      if (entity == null) continue;
      placeEntity(
        entity,
        world: world,
        sceneState: sceneState,
        slot: _before[i],
      );
    }
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Takes a group apart: its children move up into its place, and the
/// empty group goes.
class UngroupCommand extends EditorCommand {
  /// Takes `group` apart. The group is recorded as it is when this is made
  /// (its components, place and children), which is what [undo] rebuilds.
  UngroupCommand({
    required this.world,
    required this.sceneState,
    required jge.Entity group,
    required this.codec,
  }) : _name = group.name ?? 'group',
       _groupId = group.id,
       _spec = EntitySpec.of(group, codec),
       _slot = HierarchySlot.of(group, world: world, sceneState: sceneState),
       _children = [
         for (final id in List.of(
           group.getComponent<jge.ChildrenComponent>()?.childIds ??
               const <jge.EntityId>[],
         ))
           ?world.getEntity(id),
       ];

  @override
  String get label => 'Ungroup $_name';

  /// The world the group is in.
  final jge.World world;

  /// The editor's scene state: forgets and re-registers the group, finds
  /// entities rebuilt since, and is marked dirty after each step.
  final EditorSceneState sceneState;

  /// Records the group's components when this is made, so [undo] can make
  /// it again.
  final SceneCodec codec;

  final String _name;

  /// The group as it was — its components, whether it was switched on, the
  /// prefab instance it is the top of — to make it again on undo.
  final EntitySpec _spec;
  final HierarchySlot _slot;
  final List<jge.Entity> _children;

  /// The id the group had when it was last taken apart.
  jge.EntityId _groupId;

  @override
  void redo() {
    final group = world.getEntity(sceneState.currentId(_groupId));
    // The children take the group's place, in their own order.
    var at = _slot.index;
    for (final c in _children) {
      final child = sceneState.liveEntity(c);
      if (child == null) continue;
      placeEntity(
        child,
        world: world,
        sceneState: sceneState,
        slot: HierarchySlot(parentId: _slot.parentId, index: at),
      );
      if (at >= 0) at++;
    }
    if (group != null) {
      _groupId = group.id;
      // Out of its parent's list before it goes, or the list keeps an id
      // that no longer belongs to anything.
      detachEntity(group, world: world, sceneState: sceneState);
      sceneState.removeEntityNode(group.id);
      world.destroyEntity(group);
    }
    sceneState
      ..markDirty()
      ..refresh();
  }

  @override
  void undo() {
    final group = _spec.build(world, prefabTop: _prefabTop, evenEmpty: true)!;
    sceneState
      ..registerEntity(group)
      ..entityRebuilt(sceneState.currentId(_groupId), group);
    _groupId = group.id;
    placeEntity(group, world: world, sceneState: sceneState, slot: _slot);
    for (final c in _children) {
      final child = sceneState.liveEntity(c);
      if (child == null) continue;
      placeEntity(
        child,
        world: world,
        sceneState: sceneState,
        slot: HierarchySlot(parentId: group.id, index: -1),
      );
    }
    sceneState
      ..markDirty()
      ..refresh();
  }

  jge.EntityId? _prefabTop(jge.EntityId top) =>
      world.getEntity(sceneState.currentId(top))?.id;
}
