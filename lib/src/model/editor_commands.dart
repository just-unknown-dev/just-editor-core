import 'package:flutter/painting.dart' show Offset;
import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'scene_codec.dart';
import 'hierarchy_commands.dart';
import 'editor_scene_state.dart';
import 'editor_history.dart';

/// A single entity's transform, captured so it can be restored exactly.
///
/// Stores plain doubles rather than a reference to the live component: the
/// point is to survive the component being mutated afterwards. All nine
/// values are kept — position, the three rotation angles and scale, in 3-D —
/// so undoing a 2-D edit never loses a z, a tilt or a z scale.
class TransformSnapshot {
  const TransformSnapshot({
    required this.x,
    required this.y,
    this.z = 0.0,
    required this.angle,
    this.eulerX = 0.0,
    this.eulerY = 0.0,
    required this.scaleX,
    required this.scaleY,
    this.scaleZ = 1.0,
  });

  /// Reads the current transform of [entity].
  factory TransformSnapshot.of(jge.Entity entity) {
    final t = entity.getComponent<jge.TransformComponent>()!;
    return TransformSnapshot(
      x: t.position.x,
      y: t.position.y,
      z: t.position.z,
      angle: t.angle,
      eulerX: t.eulerX,
      eulerY: t.eulerY,
      scaleX: t.scale.x,
      scaleY: t.scale.y,
      scaleZ: t.scale.z,
    );
  }

  /// World X.
  final double x;

  /// World Y.
  final double y;

  /// World Z.
  final double z;

  /// Rotation about Z in radians — the 2-D rotation.
  final double angle;

  /// Rotation about X in radians.
  final double eulerX;

  /// Rotation about Y in radians.
  final double eulerY;

  /// Horizontal scale.
  final double scaleX;

  /// Vertical scale.
  final double scaleY;

  /// Depth scale.
  final double scaleZ;

  /// Writes this snapshot back onto [entity].
  void applyTo(jge.Entity entity) {
    final t = entity.getComponent<jge.TransformComponent>();
    if (t == null) return;
    t
      ..setPositionXYZ(x, y, z)
      ..setEuler(eulerX, eulerY, angle);
    t.scale.setValues(scaleX, scaleY, scaleZ);
  }

  /// Whether [other] describes the same transform, within float noise.
  bool matches(TransformSnapshot other) =>
      (x - other.x).abs() < 1e-6 &&
      (y - other.y).abs() < 1e-6 &&
      (z - other.z).abs() < 1e-6 &&
      (angle - other.angle).abs() < 1e-9 &&
      (eulerX - other.eulerX).abs() < 1e-9 &&
      (eulerY - other.eulerY).abs() < 1e-9 &&
      (scaleX - other.scaleX).abs() < 1e-9 &&
      (scaleY - other.scaleY).abs() < 1e-9 &&
      (scaleZ - other.scaleZ).abs() < 1e-9;
}

/// Moves, rotates or scales one or more entities.
///
/// Built from before/after snapshots rather than a delta so undo restores the
/// exact prior transform instead of re-applying an inverse, which would drift
/// as float error accumulated over a long drag.
class TransformCommand extends EditorCommand {
  TransformCommand({
    required this.label,
    required this.entities,
    required this.before,
    required this.after,
    required this.sceneState,
    this.mergeKey,
  });

  @override
  final String label;

  /// Commands with the same non-null key fold into one undo step.
  ///
  /// Null — the default — never merges: every gesture pushes exactly one
  /// command, so two drags of a platform are two undo steps. A burst of
  /// arrow-key nudges is the case that wants merging, and it opts in.
  final Object? mergeKey;

  /// Entities affected, aligned index-for-index with [before] and [after].
  ///
  /// As they were when the gesture was made: one destroyed and made again
  /// since — a delete undone — is found as what it was made again as
  /// ([EditorSceneState.liveEntity]).
  final List<jge.Entity> entities;

  /// Transforms as they were before the gesture.
  final List<TransformSnapshot> before;

  /// Transforms as they are after it.
  List<TransformSnapshot> after;

  /// Notified so panels and the canvas refresh.
  final EditorSceneState sceneState;

  @override
  void redo() => _apply(after);

  @override
  void undo() => _apply(before);

  void _apply(List<TransformSnapshot> snapshots) {
    final live = [for (final e in entities) sceneState.liveEntity(e)];
    for (var i = 0; i < live.length; i++) {
      final entity = live[i];
      if (entity == null) continue;
      snapshots[i].applyTo(entity);
    }
    // What hangs under a restored entity goes back with it.
    for (final entity in live) {
      if (entity != null) {
        entity.world?.transformHierarchy.propagateFrom(entity);
      }
    }
    sceneState
      ..markDirty()
      ..refresh();
  }

  /// Absorbs a later transform of the same entities with the same
  /// [mergeKey] — one undo step for a run of nudges, say.
  @override
  bool mergeWith(EditorCommand next) {
    if (next is! TransformCommand) return false;
    if (mergeKey == null || next.mergeKey != mergeKey) return false;
    if (next.entities.length != entities.length) return false;
    for (var i = 0; i < entities.length; i++) {
      if (!identical(entities[i], next.entities[i])) return false;
    }
    after = next.after;
    return true;
  }
}

/// Creates entities from component JSON, and destroys them again on undo.
///
/// Holds JSON rather than live entities because undo destroys them: on redo
/// there is nothing left to re-add, so the command has to be able to rebuild
/// them from scratch. Ids are new each time; each rebuild is recorded
/// ([EditorSceneState.entityRebuilt]), so a later command that moved or
/// renamed one still finds it.
///
/// An entity whose spec names a parent goes under it: by id first
/// ([EntitySpec.parentId]) — one made by this same command, or one already
/// there — then by name ([EntitySpec.parentName]), preferring an entity
/// this command made over an older one of the same name.
class CreateEntitiesCommand extends EditorCommand {
  CreateEntitiesCommand({
    required this.label,
    required this.world,
    required this.sceneState,
    required this.specs,
    this.onCreated,
  }) : _made = List<jge.EntityId?>.filled(specs.length, null),
       _restores = false;

  CreateEntitiesCommand._adopting({
    required this.label,
    required this.world,
    required this.sceneState,
    required this.specs,
    required List<jge.EntityId?> made,
    this.onCreated,
  }) : _made = made,
       _restores = true;

  @override
  final String label;

  /// World the entities live in.
  final jge.World world;

  /// Notified so the scene tree and inspector refresh.
  final EditorSceneState sceneState;

  /// One entry per entity: its name and its serialized components.
  final List<EntitySpec> specs;

  /// Called with the freshly created entities, e.g. to select them.
  final void Function(List<jge.Entity> created)? onCreated;

  /// Per spec, the id its entity was last made with; null for one not made
  /// yet (or with nothing to make).
  final List<jge.EntityId?> _made;

  /// Whether the specs are the very entities they were taken from — put
  /// back, not copied: a prefab link to an instance outside this command
  /// is kept, where a copy drops it and stands on its own.
  final bool _restores;

  /// Records entities that already exist as having been created by this
  /// command, for [EditorHistory.pushApplied].
  ///
  /// For gestures that create entities up front and keep editing them until
  /// release — Alt+drag duplicate — so the whole gesture is one undo step
  /// whose redo rebuilds the entities as they ended up, not as they started.
  factory CreateEntitiesCommand.adopting({
    required String label,
    required jge.World world,
    required EditorSceneState sceneState,
    required List<jge.Entity> entities,
    required SceneCodec codec,
    void Function(List<jge.Entity> created)? onCreated,
  }) => CreateEntitiesCommand._adopting(
    label: label,
    world: world,
    sceneState: sceneState,
    specs: entities
        .map((e) => EntitySpec.of(e, codec, world: world))
        .toList(growable: false),
    made: [for (final e in entities) e.id],
    onCreated: onCreated,
  );

  @override
  void redo() {
    final created = <jge.Entity>[];
    // What this pass has made, by the id its spec was taken from and by
    // name: a child's parent, or an instance's top, among them.
    final byId = <jge.EntityId, jge.Entity>{};
    final byName = <String, jge.Entity>{};

    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final entity = spec.build(
        world,
        prefabTop: (top) =>
            byId[top]?.id ??
            (_restores ? world.getEntity(sceneState.currentId(top))?.id : null),
      );
      if (entity == null) continue;

      sceneState.registerEntity(entity);
      if (_made[i] case final was?) {
        sceneState.entityRebuilt(sceneState.currentId(was), entity);
      }
      _made[i] = entity.id;

      final parent = _parentOf(spec, byId, byName);
      if (parent != null) {
        placeEntity(
          entity,
          world: world,
          sceneState: sceneState,
          slot: HierarchySlot(parentId: parent.id, index: spec.siblingIndex),
        );
      }
      if (spec.id case final id?) byId[id] = entity;
      if (entity.name case final name?) byName[name] = entity;
      created.add(entity);
    }

    sceneState
      ..markDirty()
      ..refresh();
    onCreated?.call(created);
  }

  jge.Entity? _parentOf(
    EntitySpec spec,
    Map<jge.EntityId, jge.Entity> byId,
    Map<String, jge.Entity> byName,
  ) {
    if (spec.parentId case final id?) {
      final found = byId[id] ?? world.getEntity(sceneState.currentId(id));
      if (found != null) return found;
    }
    if (spec.parentName case final name?) {
      return byName[name] ?? world.findEntityByName(name);
    }
    return null;
  }

  @override
  void undo() {
    // Last made first, so a child leaves its parent before the parent goes.
    final gone = <jge.EntityId>{};
    for (final id in _made.reversed) {
      if (id == null) continue;
      final entity = world.getEntity(sceneState.currentId(id));
      if (entity == null) continue;
      detachEntity(entity, world: world, sceneState: sceneState);
      gone.add(entity.id);
      world.destroyEntity(entity);
    }
    sceneState
      ..removeEntityNodes(gone)
      ..clearSelection()
      ..markDirty()
      ..refresh();
  }
}

/// What a prefab instance records on an entity it made, which no codec
/// saves: its link (`PrefabLink`) — the instance's top entity and where in
/// the prefab this one is — and, on the top, the instance as loaded
/// (`PrefabInstanceComponent`).
///
/// Kept by an [EntitySpec] so that an entity rebuilt from one — a delete
/// undone, a group put back — is still part of its instance, and a save
/// still writes the instance as a `prefab` block rather than every entity
/// of it in full.
class PrefabOrigin {
  /// An origin linking to the instance whose top had the id [top], at
  /// [path] in its prefab; [block] (with [missing]) on the top itself.
  const PrefabOrigin({this.top, this.path, this.block, this.missing = false});

  /// What [entity] carries, or null for an entity no prefab made.
  static PrefabOrigin? of(jge.Entity entity) {
    final link = entity.getComponent<jge.PrefabLink>();
    final instance = entity.getComponent<jge.PrefabInstanceComponent>();
    if (link == null && instance == null) return null;
    return PrefabOrigin(
      top: link?.instance,
      path: link?.path,
      block: instance?.block,
      missing: instance?.missing ?? false,
    );
  }

  /// The id the instance's top entity had; null when it carried no link.
  final jge.EntityId? top;

  /// Where in the prefab the entity is; null when it carried no link.
  final String? path;

  /// The instance as loaded, on its top entity; null on the others.
  final jge.PrefabInstance? block;

  /// Whether the instance's prefab could not be read.
  final bool missing;

  /// The runtime components to put on an entity made again from it, its
  /// link naming [top] — the instance's top as it is now. A null [top]
  /// leaves the link off: the entity is no longer part of an instance.
  List<jge.Component> components(jge.EntityId? top) => [
    if (top != null && path != null) jge.PrefabLink(instance: top, path: path!),
    if (block case final b?)
      jge.PrefabInstanceComponent(block: b, missing: missing),
  ];
}

/// Name plus serialized components — enough to rebuild one entity — and
/// where it goes in the tree.
class EntitySpec {
  const EntitySpec({
    required this.name,
    required this.componentsJson,
    required this.codec,
    this.parentName,
    this.siblingIndex = -1,
    this.id,
    this.parentId,
    this.enabled = true,
    this.prefab,
  });

  /// Captures [entity] as it currently stands, through [codec]: its
  /// components, whether it is switched on, and the prefab instance it is
  /// part of. With [world], where it sits in the tree too: its parent, by
  /// id and by name, and its place among that parent's children.
  factory EntitySpec.of(
    jge.Entity entity,
    SceneCodec codec, {
    jge.World? world,
  }) {
    final json = codec.encodeAll(entity.components);
    final parentId = entity.getComponent<jge.ParentComponent>()?.parentId;
    final parent = parentId == null ? null : world?.getEntity(parentId);
    return EntitySpec(
      name: entity.name,
      componentsJson: json,
      codec: codec,
      id: entity.id,
      parentId: parent?.id,
      parentName: parent?.name,
      siblingIndex:
          parent?.getComponent<jge.ChildrenComponent>()?.childIds.indexOf(
            entity.id,
          ) ??
          -1,
      enabled: entity.isActive,
      prefab: PrefabOrigin.of(entity),
    );
  }

  /// Entity name, or null for an unnamed entity.
  final String? name;

  /// The id of the entity this was taken from, or null for a spec made by
  /// hand. What a child's [parentId] and a [prefab] link name it by.
  final jge.EntityId? id;

  /// The id of the entity it goes under, as it was when this was taken.
  ///
  /// Looked for before [parentName]: names need not be unique — the parts
  /// of two instances of one prefab share them — and an id found through
  /// [EditorSceneState.currentId] is the same entity even after it was
  /// rebuilt. Null to go by [parentName] alone.
  final jge.EntityId? parentId;

  /// The name of the entity it goes under, or null for a root — what is
  /// used when there is no [parentId], or that entity is gone.
  final String? parentName;

  /// Its place among its parent's children; -1 for after them all.
  final int siblingIndex;

  /// Whether the entity is switched on — the scene's `enabled` flag, which
  /// lives on the entity, not in a component.
  final bool enabled;

  /// The prefab instance the entity is part of, or null.
  final PrefabOrigin? prefab;

  /// Serialized components, in attachment order.
  final List<Map<String, dynamic>> componentsJson;

  /// Turns [componentsJson] back into components: the scope's codec.
  final SceneCodec codec;

  /// Decodes the components. Anything with no definition is kept as it
  /// was saved (`UnknownComponents`), exactly as a scene load does.
  List<jge.Component> decode() => codec.decodeAll(componentsJson);

  /// Makes the entity this describes in [world]: its components, its name,
  /// switched off if it was, and part of its prefab instance again — its
  /// link naming the top [prefabTop] gives for the id the top had (null
  /// drops the link; a top that is this entity itself is found without
  /// asking). Not placed in the tree: that is the caller's.
  ///
  /// Null when nothing decodes — there is nothing to make — unless
  /// [evenEmpty].
  jge.Entity? build(
    jge.World world, {
    jge.EntityId? Function(jge.EntityId top)? prefabTop,
    bool evenEmpty = false,
  }) {
    final components = decode();
    if (components.isEmpty && !evenEmpty) return null;
    final entity = world.createEntityWithComponents(components, name: name);
    if (!enabled) entity.isActive = false;
    final origin = prefab;
    if (origin != null) {
      final top = switch (origin.top) {
        null => null,
        final was when was == id => entity.id,
        final was => prefabTop?.call(was),
      };
      for (final c in origin.components(top)) {
        entity.addComponent(c);
      }
    }
    return entity;
  }

  /// Makes [entity] match this spec, in place.
  ///
  /// The entity keeps its id, so selection, the physics body bound to it and
  /// any history entry that refers to it all stay valid. Components the spec
  /// lacks are removed if they are part of the level format; runtime-only
  /// ones (the physics handle) are left to the systems that own them, which
  /// re-sync from what is written here.
  ///
  /// Where it is in the tree is not part of this: the entity's parent link
  /// and its list of children are left as they are. Decoded, they would be
  /// empty — they name entities by id — and a resize would cut a child
  /// loose, or an edit to a parent drop all of its children.
  void applyTo(jge.Entity entity) {
    final decoded = decode();
    final components = [
      for (final c in decoded)
        if (!_isLink(c)) c,
    ];
    final kept = {for (final c in components) c.componentType};
    for (final c in entity.components.toList()) {
      if (_isLink(c)) continue;
      if (!kept.contains(c.componentType) && codec.canEncode(c)) {
        entity.removeComponentByType(c.componentType);
      }
    }
    for (final c in components) {
      entity.addComponent(c); // replaces the same component type
    }
    // In the record's order: a replaced component keeps its old place, and
    // the order is the entity's, rearranged in the inspector and saved.
    entity.reorderComponents([for (final c in decoded) c.componentType]);
    entity.name = name;
  }

  static bool _isLink(jge.Component c) =>
      c is jge.ParentComponent || c is jge.ChildrenComponent;

  /// This spec with some of it changed; the rest — where it came from,
  /// whether it is on, its prefab instance — kept.
  EntitySpec _with({
    String? name,
    List<Map<String, dynamic>>? componentsJson,
    String? parentName,
    jge.EntityId? parentId,
    bool keepParent = true,
    int? siblingIndex,
  }) => EntitySpec(
    name: name ?? this.name,
    componentsJson: componentsJson ?? this.componentsJson,
    codec: codec,
    id: id,
    parentId: keepParent ? this.parentId : parentId,
    parentName: keepParent ? this.parentName : parentName,
    siblingIndex: siblingIndex ?? this.siblingIndex,
    enabled: enabled,
    prefab: prefab,
  );

  /// A copy with a different name, for duplicate and array operations.
  EntitySpec renamed(String? newName) => EntitySpec(
    name: newName,
    componentsJson: componentsJson,
    codec: codec,
    id: id,
    parentId: parentId,
    parentName: parentName,
    siblingIndex: siblingIndex,
    enabled: enabled,
    prefab: prefab,
  );

  /// A copy that goes under [parent] — by name, instead of the parent it
  /// was taken under — at [index], or at the end.
  EntitySpec under(String? parent, {int index = -1}) =>
      _with(parentName: parent, keepParent: false, siblingIndex: index);

  /// A copy whose transform [edit] changes — moved, turned, sized — for
  /// duplicate and array operations in space: under the same parent, just
  /// after the original.
  EntitySpec transformed(
    void Function(jge.TransformComponent transform) edit, {
    String? newName,
  }) {
    final changed = <Map<String, dynamic>>[];
    for (final json in componentsJson) {
      final component = codec.decode(json);
      if (component is! jge.TransformComponent) {
        changed.add(json);
        continue;
      }
      edit(component);
      changed.add(codec.encode(component) ?? json);
    }
    return _with(
      name: newName,
      componentsJson: changed,
      siblingIndex: siblingIndex < 0 ? -1 : siblingIndex + 1,
    );
  }

  /// A copy shifted by [delta], for duplicate and array operations: under
  /// the same parent, just after the original.
  ///
  /// Decodes, moves the transform and re-encodes, so this knows nothing
  /// about how a position is spelled on disk — the codec does.
  EntitySpec translated(Offset delta, {String? newName}) {
    final shifted = <Map<String, dynamic>>[];
    for (final json in componentsJson) {
      final component = codec.decode(json);
      if (component is! jge.TransformComponent) {
        shifted.add(json);
        continue;
      }
      component.position = jge.Vector3(
        component.position.x + delta.dx,
        component.position.y + delta.dy,
        component.position.z,
      );
      shifted.add(codec.encode(component) ?? json);
    }
    return _with(
      name: newName,
      componentsJson: shifted,
      siblingIndex: siblingIndex < 0 ? -1 : siblingIndex + 1,
    );
  }
}

/// Destroys entities, and rebuilds them from their captured state on undo.
///
/// The capture has to happen before the entities are destroyed, so the command
/// snapshots in its constructor rather than in [redo].
///
/// A rebuilt entity has a new id (a world never gives one out twice). Each
/// rebuild is recorded ([EditorSceneState.entityRebuilt]), so the next redo
/// deletes what undo made, and any other command that refers to one of
/// them — a move before the delete, a rename after the undo — still finds
/// it. It comes back as it was: switched off if it was off, part of the
/// prefab instance it was part of, under the parent it had and in its
/// place among its siblings.
class DeleteEntitiesCommand extends EditorCommand {
  /// Captures `entities` and everything under them, parents first, through
  /// `codec`, as they are when this is made.
  DeleteEntitiesCommand({
    required this.label,
    required this.world,
    required this.sceneState,
    required List<jge.Entity> entities,
    required SceneCodec codec,
  }) {
    // The whole subtree: deleting a card and leaving its labels behind as
    // roots is not what anyone means by deleting the card. Captured
    // parent-first so undo can rebuild it from the top down.
    final ordered = <jge.Entity>[];
    final seen = <jge.EntityId>{};
    void collect(jge.Entity entity) {
      if (!seen.add(entity.id)) return;
      ordered.add(entity);
      final children = entity.getComponent<jge.ChildrenComponent>();
      if (children == null) return;
      for (final id in List.of(children.childIds)) {
        final child = world.getEntity(id);
        if (child != null) collect(child);
      }
    }

    for (final entity in entities) {
      collect(entity);
    }
    for (final entity in ordered) {
      _specs.add(EntitySpec.of(entity, codec, world: world));
      _ids.add(entity.id);
      _places.add(
        HierarchySlot.of(entity, world: world, sceneState: sceneState).index,
      );
    }
  }

  @override
  final String label;

  /// World the entities belong to.
  final jge.World world;

  /// Notified so panels refresh.
  final EditorSceneState sceneState;

  final List<EntitySpec> _specs = [];

  /// The ids the entities had when this was made; what they are now is
  /// [EditorSceneState.currentId] of them.
  final List<jge.EntityId> _ids = [];

  /// Each one's place among its parent's children, or among the roots,
  /// counted with all of them there.
  final List<int> _places = [];

  @override
  void redo() {
    final gone = <jge.EntityId>{};
    for (final id in _ids) {
      final entity = world.getEntity(sceneState.currentId(id));
      if (entity == null) continue;
      detachEntity(entity, world: world, sceneState: sceneState);
      gone.add(entity.id);
      // Each id in the list is removed on its own; its children are not
      // this command's to take.
      world.destroyEntity(entity, withChildren: false);
    }
    sceneState
      ..removeEntityNodes(gone)
      ..clearSelection()
      ..markDirty()
      ..refresh();
  }

  @override
  void undo() {
    final restored = List<jge.Entity?>.filled(_specs.length, null);
    // Parents first, each recorded as rebuilt before the next is made, so
    // a child — or a part of a prefab instance — finds what it hangs from
    // as it is now.
    for (var i = 0; i < _specs.length; i++) {
      final entity = _specs[i].build(
        world,
        prefabTop: (top) => world.getEntity(sceneState.currentId(top))?.id,
      );
      if (entity == null) continue;
      sceneState
        ..registerEntity(entity)
        ..entityRebuilt(sceneState.currentId(_ids[i]), entity);
      restored[i] = entity;
    }

    // Lowest place first: each place was counted with all of them there,
    // so filling them in order puts every one back where it was. Taken in
    // the order they were selected in, a later one landed before an
    // earlier one and the order scrambled.
    final order = [for (var i = 0; i < _specs.length; i++) i];
    int key(int i) => _places[i] < 0 ? 1 << 30 : _places[i];
    order.sort((a, b) {
      final byPlace = key(a).compareTo(key(b));
      return byPlace != 0 ? byPlace : a.compareTo(b);
    });
    for (final i in order) {
      final entity = restored[i];
      if (entity == null) continue;
      final spec = _specs[i];
      final parent = _parentOf(spec);
      final hadParent = spec.parentId != null || spec.parentName != null;
      placeEntity(
        entity,
        world: world,
        sceneState: sceneState,
        slot: HierarchySlot(
          parentId: parent?.id,
          // A parent that is gone leaves it last among the roots: its
          // place was counted among that parent's children.
          index: parent == null && hadParent ? -1 : _places[i],
        ),
      );
    }

    sceneState
      ..markDirty()
      ..refresh();
  }

  /// The parent [spec] was under, as it is now: by id — rebuilt by this
  /// undo, or still there — and by name only when that is gone.
  jge.Entity? _parentOf(EntitySpec spec) {
    if (spec.parentId case final id?) {
      final found = world.getEntity(sceneState.currentId(id));
      if (found != null) return found;
    }
    if (spec.parentName case final name?) return world.findEntityByName(name);
    return null;
  }
}

/// Changes one field of one component, using the editor descriptor's own
/// read/write closures.
///
/// Because every registered field already exposes a generic getter and setter,
/// this single command gives undo to every field of every component in the
/// inspector without a line of per-field work.
///
/// With an [entity], the component written is the one of [component]'s
/// type that entity has when the command runs — not necessarily
/// [component] itself. Stopping a play-test puts back every component as a fresh
/// instance, and an undone delete rebuilds the whole entity; an edit made
/// before either still reaches the component that is there now.
class ComponentFieldCommand extends EditorCommand {
  ComponentFieldCommand({
    required this.label,
    required this.component,
    required this.write,
    required this.before,
    required this.after,
    required this.sceneState,
    required this.entity,
  });

  @override
  final String label;

  /// The component being edited, as it was when the edit was made.
  final jge.Component component;

  /// The entity [component] belongs to: what the component to write is
  /// looked up on, by type, each time the command runs. Null only for a
  /// component that is on no entity (one edited in a file's own window);
  /// every caller says which, so none forgets it.
  final jge.Entity? entity;

  /// The descriptor field's setter.
  final void Function(jge.Component component, Object? value) write;

  /// Value before the edit.
  final Object? before;

  /// Value after it.
  Object? after;

  /// Notified so the canvas and panels refresh.
  final EditorSceneState sceneState;

  /// The component to write now: [component]'s type on [entity] as it is
  /// now, or [component] itself without an [entity]. Null when that entity
  /// is gone or no longer has one.
  jge.Component? get target {
    final owner = entity;
    if (owner == null) return component;
    return sceneState
        .liveEntity(owner)
        ?.getComponentByType(component.componentType);
  }

  @override
  void redo() => _apply(after);

  @override
  void undo() => _apply(before);

  void _apply(Object? value) {
    final into = target;
    if (into != null) write(into, value);
    sceneState
      ..markDirty()
      ..refresh();
  }

  /// Collapses consecutive edits to the same field.
  ///
  /// Scrubbing a number field emits a value per pixel of drag; without this,
  /// nudging a width would fill the entire history. A new gesture stands on
  /// its own: whoever starts one calls [EditorHistory.breakMerge] — the
  /// inspector on every press inside a component's card.
  @override
  bool mergeWith(EditorCommand next) {
    if (next is! ComponentFieldCommand) return false;
    if (next.label != label) return false;
    final mine = entity, theirs = next.entity;
    final same =
        identical(next.component, component) ||
        (mine != null &&
            theirs != null &&
            next.component.componentType == component.componentType &&
            identical(
              sceneState.liveEntity(theirs),
              sceneState.liveEntity(mine),
            ));
    if (!same) return false;
    after = next.after;
    return true;
  }
}

/// Adds a component to an entity.
///
/// An entity holds one component per type (`Component.componentType`):
/// adding one of a type it has already replaces that one — every 2-D shape
/// is a `RenderableComponent`, say. The one replaced is kept, and undo puts
/// it back, with its place among the others.
class AddComponentCommand extends EditorCommand {
  AddComponentCommand({
    required this.entity,
    required this.component,
    required this.sceneState,
  }) : _added = component;

  @override
  String get label => 'Add ${component.runtimeType}';

  /// The entity gaining the component.
  final jge.Entity entity;

  /// The component instance. Reused across undo/redo so any values the user
  /// has since typed into it survive an undo/redo round trip.
  final jge.Component component;

  /// Notified so the inspector refreshes.
  final EditorSceneState sceneState;

  /// What goes on at redo: [component] at first; then whatever of its type
  /// the entity had when it was last undone — the same instance, or the
  /// fresh one a Stop put in its place.
  jge.Component _added;

  /// What adding it replaced, and the entity's order before.
  jge.Component? _replaced;
  List<Type>? _order;

  @override
  void redo() {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    final existing = live.getComponentByType(component.componentType);
    _replaced = identical(existing, _added) ? null : existing;
    _order = live.componentTypes;
    live.addComponent(_added);
    sceneState
      ..markDirty()
      ..refresh();
  }

  @override
  void undo() {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    final type = component.componentType;
    _added = live.getComponentByType(type) ?? _added;
    live.removeComponentByType(type);
    if (_replaced case final replaced?) live.addComponent(replaced);
    if (_order case final order?) live.reorderComponents(order);
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Removes a component from an entity.
class RemoveComponentCommand extends EditorCommand {
  RemoveComponentCommand({
    required this.entity,
    required this.component,
    required this.sceneState,
  }) : _removed = component;

  @override
  String get label => 'Remove ${component.runtimeType}';

  /// The entity losing the component.
  final jge.Entity entity;

  /// The removed component, kept so undo can put the same instance back with
  /// all of its configured values intact.
  final jge.Component component;

  /// Notified so the inspector refreshes.
  final EditorSceneState sceneState;

  /// What undo puts back: the instance of [component]'s type the entity
  /// had when it was removed — [component], or the one a Stop put in its
  /// place.
  jge.Component _removed;

  /// The entity's order before the removal, so undo puts the component
  /// back in its place rather than at the end.
  List<Type>? _order;

  @override
  void redo() {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    final type = component.componentType;
    _removed = live.getComponentByType(type) ?? _removed;
    _order = live.componentTypes;
    live.removeComponentByType(type);
    sceneState
      ..markDirty()
      ..refresh();
  }

  @override
  void undo() {
    final live = sceneState.liveEntity(entity);
    if (live == null) return;
    live.addComponent(_removed);
    if (_order case final order?) live.reorderComponents(order);
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Puts an entity's components in a new order — a card dragged, or moved
/// from its menu, in the inspector. The order is the entity's
/// (`Entity.reorderComponents`): what the inspector lists and what the scene
/// saves; the game finds components by type, so it runs as before.
class ReorderComponentsCommand extends EditorCommand {
  ReorderComponentsCommand({
    required this.entity,
    required this.before,
    required this.after,
    required this.sceneState,
    this.label = 'Rearrange components',
  });

  @override
  final String label;

  /// The entity whose components are reordered; one rebuilt since is found
  /// through [EditorSceneState.liveEntity].
  final jge.Entity entity;

  /// The component types in order, as they were.
  final List<Type> before;

  /// The component types in the order they are to be.
  final List<Type> after;

  /// Notified so the inspector redraws.
  final EditorSceneState sceneState;

  @override
  void redo() => _apply(after);

  @override
  void undo() => _apply(before);

  void _apply(List<Type> order) {
    sceneState.liveEntity(entity)?.reorderComponents(order);
    sceneState
      ..markDirty()
      ..refresh();
  }
}

/// Rewrites entities in place between two captured states.
///
/// For edits that change more than a transform — a resize, a flip, a
/// replaced component — while keeping each entity itself: capture
/// [EntitySpec]s before, make the change, capture after, push this applied.
class EntityStateCommand extends EditorCommand {
  /// [ids], [before] and [after] must be the same length, one entry per
  /// entity.
  EntityStateCommand({
    required this.label,
    required this.world,
    required this.sceneState,
    required this.ids,
    required this.before,
    required this.after,
    this.mergeKey,
  }) : assert(ids.length == before.length && ids.length == after.length);

  /// Commands with the same non-null key fold into one undo step — a scrub
  /// of a number field, say, which commits on every pixel of drag.
  final Object? mergeKey;

  @override
  final String label;

  /// World the entities live in.
  final jge.World world;

  /// Notified so panels and the canvas refresh.
  final EditorSceneState sceneState;

  /// Entities affected, aligned with [before] and [after].
  final List<jge.EntityId> ids;

  /// State before the edit.
  final List<EntitySpec> before;

  /// State after it.
  List<EntitySpec> after;

  @override
  bool mergeWith(EditorCommand next) {
    if (mergeKey == null || next is! EntityStateCommand) return false;
    if (next.mergeKey != mergeKey || next.ids.length != ids.length) {
      return false;
    }
    for (var i = 0; i < ids.length; i++) {
      if (next.ids[i] != ids[i]) return false;
    }
    after = next.after;
    return true;
  }

  /// Whether anything actually changed — a command that changes nothing
  /// would make Ctrl+Z appear to do nothing.
  bool get changesAnything {
    for (var i = 0; i < ids.length; i++) {
      if (!_sameJson(before[i].componentsJson, after[i].componentsJson) ||
          before[i].name != after[i].name) {
        return true;
      }
    }
    return false;
  }

  @override
  void redo() => _apply(after);

  @override
  void undo() => _apply(before);

  void _apply(List<EntitySpec> specs) {
    for (var i = 0; i < ids.length; i++) {
      // As it is now: rebuilt since by an undone delete, it has a new id.
      final entity = world.getEntity(sceneState.currentId(ids[i]));
      if (entity == null || !entity.isAlive) continue;
      specs[i].applyTo(entity);
    }
    sceneState
      ..markDirty()
      ..refresh();
  }

  static bool _sameJson(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_sameJson(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_sameJson(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is num && b is num) return (a - b).abs() < 1e-9;
    return a == b;
  }
}

/// Several commands performed as one undo step.
///
/// Redone in order and undone in reverse, so each part sees the state the
/// previous one left — replacing an entity is a delete then a create.
class CompositeCommand extends EditorCommand {
  CompositeCommand({required this.label, required this.commands});

  @override
  final String label;

  /// The parts, in the order they are performed.
  final List<EditorCommand> commands;

  @override
  void redo() {
    for (final command in commands) {
      command.redo();
    }
  }

  @override
  void undo() {
    for (final command in commands.reversed) {
      command.undo();
    }
  }
}
