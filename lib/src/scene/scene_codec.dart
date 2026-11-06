import 'package:just_game_engine/just_game_engine.dart';

import 'transform_snapshot.dart';
import 'unknown_types_component.dart';

/// Encodes and decodes components for one editor, through the engine's
/// definition registry.
///
/// The same registry the shipped game loads with, so the editor and the game
/// cannot disagree about what a saved level means. A component with no
/// definition is not saved — the save path warns instead of silently writing
/// something the game would then refuse to load. A *saved* component with no
/// definition is the other way round: it came from the file, so it is kept
/// ([UnknownTypesComponent]) and written back as it was.
class SceneCodec {
  const SceneCodec(this.definitions, {this.prefabs});

  /// Where component definitions come from.
  final ComponentDefinitionRegistry definitions;

  /// The prefab files read so far, by path: what an instance's entities
  /// are compared with when it is saved ([collapseMarked]). Without it, an
  /// instance is saved with the changes it was loaded with.
  final PrefabFile? Function(String path)? prefabs;

  /// Encodes [component], or null if it has no definition.
  Map<String, dynamic>? encode(Component component) =>
      definitions.encode(component);

  /// Decodes [json], or null if its type is unknown.
  Component? decode(Map<String, dynamic> json) => definitions.decode(json);

  /// Whether [component] would be saved.
  bool canEncode(Component component) =>
      component is UnknownTypesComponent || definitions.canEncode(component);

  /// Decodes an entity's saved components, in order.
  ///
  /// What no definition can read is not dropped: it is gathered, verbatim,
  /// into one [UnknownTypesComponent] so that [encodeAll] writes it back.
  List<Component> decodeAll(Iterable<dynamic> json) {
    final out = <Component>[];
    final unknown = <Map<String, dynamic>>[];
    for (final item in json) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final component = decode(map);
      if (component != null) {
        out.add(component);
      } else {
        unknown.add(map);
      }
    }
    if (unknown.isNotEmpty) out.add(UnknownTypesComponent(unknown));
    return out;
  }

  /// Encodes [components] as a scene file stores them: the ones with a
  /// definition through it, the [UnknownTypesComponent] exactly as they were
  /// read, and runtime-only state not at all.
  List<Map<String, dynamic>> encodeAll(Iterable<Component> components) => [
    for (final c in components)
      if (c is UnknownTypesComponent)
        for (final entry in c.entries) Map<String, dynamic>.of(entry)
      else
        ?encode(c),
  ];

  /// Encodes [entities] the way a scene file stores them.
  ///
  /// Destroyed entities are gone from the world already; a switched-off
  /// one is saved with `enabled: false`, because being off is part of
  /// the scene. Components with no definition are skipped — runtime-only
  /// state such as a physics body handle.
  List<Map<String, dynamic>> encodeEntities(
    List<Entity> entities, {
    List<EntityId>? rootOrder,
  }) {
    final ordered = inTreeOrder(
      entities.where((e) => e.isAlive).toList(),
      rootOrder: rootOrder,
    );
    return collapseMarked(encodeForSave(ordered));
  }

  /// [records] — from [encodeForSave] — as a scene file stores them: each
  /// prefab instance's records folded into one entry holding what the
  /// instance changes ([PrefabCollapse.collapseScene]); [records] itself
  /// when nothing came from a prefab.
  List<Map<String, dynamic>> collapseMarked(
    List<Map<String, dynamic>> records,
  ) {
    final marked = records.any(
      (r) => r.containsKey('prefabRef') || r.containsKey('parentInside'),
    );
    if (!marked) return records;
    return PrefabCollapse.collapseScene(records, prefabs ?? (_) => null);
  }

  /// [ordered] encoded for a save, one record per entity, marked where
  /// they came from a prefab ([markPrefabs]).
  ///
  /// What is inside a prefab instance is written in its prefab's own
  /// space — as though the instance's top stood where the prefab has it —
  /// so that what was not moved inside it is not a change; the top, and
  /// everything of the scene's own, as it stands. The live entities are
  /// moved to work that out and put back.
  List<Map<String, dynamic>> encodeForSave(List<Entity> ordered) {
    final actual = encodeInOrder(ordered);
    final homes = <Entity, TransformSnapshot>{};
    final List<Map<String, dynamic>> inPrefab;
    try {
      for (final top in ordered) {
        final instance = top.getComponent<PrefabInstanceComponent>();
        final t = top.getComponent<TransformComponent>();
        if (instance == null || instance.missing || t == null) continue;
        final made = PrefabExpander.expand(
          PrefabInstance(path: instance.path),
          prefabs ?? (_) => null,
        );
        final saved = made?.first.componentOf('TransformComponent');
        final home = saved == null ? null : decode(saved);
        if (home is! TransformComponent) continue;
        final world = top.world;
        world?.transformHierarchy.propagateFrom(top);
        homes[top] = TransformSnapshot.of(top);
        final turn = Quaternion.identity();
        home.rotationInto(turn);
        t
          ..position.setFrom(home.position)
          ..scale.setFrom(home.scale)
          ..setRotation(turn);
        world?.transformHierarchy.propagateFrom(top);
      }
      if (homes.isEmpty) {
        markPrefabs(ordered, actual);
        _nameParents(ordered, actual);
        return actual;
      }
      inPrefab = encodeInOrder(ordered);
    } finally {
      // Back where they are, the innermost first — whatever happened: a
      // save that fails part-way must not leave the instances moved, or
      // the next one writes them where they were moved to.
      for (final MapEntry(key: top, value: snapshot)
          in homes.entries.toList().reversed) {
        snapshot.applyTo(top);
        top.world?.transformHierarchy.propagateFrom(top);
      }
    }
    final homeIds = {for (final top in homes.keys) top.id};
    final out = [
      for (var i = 0; i < ordered.length; i++)
        switch (ordered[i].getComponent<PrefabLinkComponent>()) {
          final link?
              when homeIds.contains(link.instance) &&
                  link.instance != ordered[i].id =>
            inPrefab[i],
          _ => actual[i],
        },
    ];
    markPrefabs(ordered, out);
    _nameParents(ordered, out);
    return out;
  }

  /// Marks the records in [encoded] — one per entity of [ordered] — whose
  /// entities came from a prefab, as [PrefabCollapse.collapseScene] reads
  /// them; whether any did. An entity whose instance's top is not among
  /// [ordered] (taken out of it) is saved as its own.
  static bool markPrefabs(
    List<Entity> ordered,
    List<Map<String, dynamic>> encoded,
  ) {
    final index = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
    PrefabLinkComponent? linkOf(Entity? e) {
      final link = e?.getComponent<PrefabLinkComponent>();
      if (link == null) return null;
      final top = index[link.instance];
      if (top == null ||
          !ordered[top].hasComponent<PrefabInstanceComponent>()) {
        return null;
      }
      return link;
    }

    var any = false;
    for (var i = 0; i < ordered.length; i++) {
      final e = ordered[i];
      final parentId = e.getComponent<ParentComponent>()?.parentId;
      final parent = parentId == null ? null : e.world?.getEntity(parentId);
      final link = linkOf(e);
      final parentLink = linkOf(parent);
      final top = link == null ? null : index[link.instance];
      final isTop = top == i;
      if (link != null) {
        any = true;
        final instance = isTop
            ? e.getComponent<PrefabInstanceComponent>()!
            : null;
        encoded[i]['prefabRef'] = {
          'instance': top,
          'path': link.path,
          if (!isTop &&
              parentLink != null &&
              parentLink.instance == link.instance)
            'parent': parentLink.path,
          if (instance != null) 'block': instance.block.toJson(),
          if (instance != null && instance.missing) 'missing': instance.path,
        };
      }
      // Under an entity inside an instance, not of it.
      if (parentLink != null &&
          (link == null || isTop || parentLink.instance != link.instance)) {
        encoded[i]['parentInside'] = {
          'instance': index[parentLink.instance],
          'path': parentLink.path,
        };
      }
    }
    return any;
  }

  /// Encodes [ordered] as it stands, one record per entity in the same
  /// order — for a caller that must keep each record beside its entity
  /// (see [inTreeOrder] for the order a file wants).
  ///
  /// A child's `parentName` is its parent's name — or, for a parent with
  /// none, the name [encodeForSave] writes into the parent's own record
  /// ([parentNames]). Here the parent's record keeps the name it has: none.
  List<Map<String, dynamic>> encodeInOrder(List<Entity> ordered) {
    final names = parentNames(ordered);
    return [
      for (final e in ordered)
        {
          'name': e.name,
          // Left out when it is on, which is nearly always.
          if (!e.isActive) 'enabled': false,
          'parentName': switch (e.getComponent<ParentComponent>()?.parentId) {
            final id? => names[id],
            null => null,
          },
          'components': encodeAll(e.components),
        },
    ];
  }

  /// The name a scene file links each entity of [ordered] that another of
  /// [ordered] is under by, by id: its own; or, for one with none, a name
  /// made up for the file — `entity_<id>`, or `entity_<id>_2` and so on
  /// when an entity is called that already.
  ///
  /// A file links a child to its parent by name (`parentName`), so a parent
  /// with no name of its own still needs one there — the same in the
  /// child's record and in the parent's ([encodeForSave]), or the child is
  /// a root once the scene is opened again.
  static Map<EntityId, String> parentNames(List<Entity> ordered) {
    final listed = {for (final e in ordered) e.id};
    final parents = <EntityId>{
      for (final e in ordered)
        if (e.getComponent<ParentComponent>()?.parentId case final id?
            when listed.contains(id))
          id,
    };
    final taken = {for (final e in ordered) ?e.name};
    final out = <EntityId, String>{};
    for (final e in ordered) {
      if (!parents.contains(e.id)) continue;
      final own = e.name;
      if (own != null) {
        out[e.id] = own;
        continue;
      }
      var name = 'entity_${e.id}';
      for (var n = 2; taken.contains(name); n++) {
        name = 'entity_${e.id}_$n';
      }
      taken.add(name);
      out[e.id] = name;
    }
    return out;
  }

  /// Writes into [records] — one per entity of [ordered], marked by
  /// [markPrefabs] — the made-up name ([parentNames]) of each unnamed
  /// entity a record of the file is linked to by name: one a child of the
  /// scene is under, or an instance's top when a child is under something
  /// inside it. A record folded into its prefab instance is left as it is:
  /// its place in the prefab says where it is.
  static void _nameParents(
    List<Entity> ordered,
    List<Map<String, dynamic>> records,
  ) {
    bool folded(int i) => switch (records[i]['prefabRef']) {
      {'instance': final int top} => top != i,
      _ => false,
    };
    final index = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
    final linkedTo = <int>{};
    for (var i = 0; i < ordered.length; i++) {
      if (folded(i)) continue;
      if (records[i]['parentInside'] case {'instance': final int top}) {
        linkedTo.add(top);
        continue;
      }
      final parentId = ordered[i].getComponent<ParentComponent>()?.parentId;
      final at = parentId == null ? null : index[parentId];
      if (at != null) linkedTo.add(at);
    }
    if (linkedTo.every((i) => ordered[i].name != null)) return;
    final names = parentNames(ordered);
    for (final i in linkedTo) {
      if (ordered[i].name != null || folded(i)) continue;
      final name = names[ordered[i].id];
      if (name != null) records[i]['name'] = name;
    }
  }

  /// Mends [entries] — a scene file's, as read, before they are built — as
  /// an editor before 0.1.0 saved a child of an unnamed parent: with
  /// `parentName: "entity_<id>"`, and the parent's own record with no name,
  /// so that the child was a root once the scene was opened again.
  ///
  /// A file is written in tree order, so such a parent is the record just
  /// before the first child naming it. When no record has that name and
  /// the record before has none, it is given the name. How many were
  /// mended.
  static int nameUnnamedParents(List<Map<String, dynamic>> entries) {
    final names = <String>{
      for (final e in entries)
        if (e['name'] case final String name) name,
    };
    final tried = <String>{};
    var mended = 0;
    for (var i = 1; i < entries.length; i++) {
      final wanted = entries[i]['parentName'];
      if (wanted is! String ||
          names.contains(wanted) ||
          !tried.add(wanted) ||
          !_madeUpName.hasMatch(wanted)) {
        continue;
      }
      final before = entries[i - 1];
      if (before['name'] != null) continue;
      before['name'] = wanted;
      names.add(wanted);
      mended++;
    }
    return mended;
  }

  /// What [encodeInOrder] made an unnamed parent's name before 0.1.0.
  static final RegExp _madeUpName = RegExp(r'^entity_\d+$');

  /// [entities] with each parent before its children, and siblings in the
  /// order their parent lists them.
  ///
  /// The order a scene file is written in *is* the sibling order: loading
  /// rebuilds each `ChildrenComponent` by walking the file. So a row whose
  /// buttons were dragged into a new order keeps it by being written in
  /// it.
  static List<Entity> inTreeOrder(
    List<Entity> entities, {
    List<EntityId>? rootOrder,
  }) {
    final byId = {for (final e in entities) e.id: e};
    final out = <Entity>[];
    final placed = <EntityId>{};

    void walk(Entity entity) {
      if (!placed.add(entity.id)) return;
      out.add(entity);
      final children = entity.getComponent<ChildrenComponent>();
      if (children == null) return;
      for (final id in children.childIds) {
        final child = byId[id];
        if (child != null) walk(child);
      }
    }

    // The roots in the order the editor holds them, so rearranging the top
    // level is a real edit and not a redraw.
    for (final id in rootOrder ?? const <EntityId>[]) {
      final entity = byId[id];
      if (entity == null) continue;
      final parentId = entity.getComponent<ParentComponent>()?.parentId;
      if (parentId == null || !byId.containsKey(parentId)) walk(entity);
    }
    for (final entity in entities) {
      final parentId = entity.getComponent<ParentComponent>()?.parentId;
      // A root, or a child whose parent is not being saved.
      if (parentId == null || !byId.containsKey(parentId)) walk(entity);
    }
    // A child its parent forgot to list, and anything in a parent loop.
    for (final entity in entities) {
      walk(entity);
    }
    return out;
  }

  /// The definition [component] is saved and inspected through, or null.
  ComponentDefinition? definitionFor(Component component) =>
      definitions.definitionFor(component);
}
