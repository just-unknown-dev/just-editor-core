// Who is under whom, and in what order. A group goes where what it holds
// was — inside a UI canvas, on a Level Map — not to the end of the scene;
// on a map it takes the map layer, and ungrouping gives it back. A move or
// a group of a selection works out every place in one look, whatever its
// size.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  late World world;
  late EditorSceneState state;
  late EditorHistory history;
  late SceneCodec codec;

  setUp(() {
    world = World(extensions: [BuiltInComponents.extension])..initialize();
    state = EditorSceneState()..openScene(EditorScene(name: 'test'));
    history = EditorHistory();
    codec = SceneCodec(world.context.definitions);
  });

  tearDown(() {
    history.dispose();
    state.dispose();
    world.dispose();
  });

  Entity make(String name, {Entity? under, List<Component>? also}) {
    final e = world.createEntityWithComponents([
      TransformComponent(),
      ...?also,
    ], name: name);
    state.registerEntity(e);
    if (under != null) {
      placeEntity(
        e,
        world: world,
        sceneState: state,
        slot: HierarchySlot(parentId: under.id, index: -1),
      );
    }
    return e;
  }

  Entity one(String name) =>
      world.entities.singleWhere((e) => e.isAlive && e.name == name);

  List<String?> childNames(Entity e) => [
    for (final id in e.getComponent<ChildrenComponent>()?.childIds ?? [])
      world.getEntity(id)?.name,
  ];

  List<String?> rootNames() => [
    for (final id in state.rootOrder(world)) world.getEntity(id)?.name,
  ];

  GroupCommand grouping(List<Entity> entities) => GroupCommand(
    world: world,
    sceneState: state,
    entities: entities,
    name: 'Group',
    position: Vector3.zero(),
  );

  group('grouping', () {
    test('keeps what it groups under the parent they share, in its '
        'place', () {
      final canvas = make('Canvas');
      final title = make('Title', under: canvas);
      final ok = make('OK', under: canvas);
      final cancel = make('Cancel', under: canvas);
      make('Footer', under: canvas);
      make('Light');

      history.push(grouping([ok, cancel]));
      expect(childNames(canvas), ['Title', 'Group', 'Footer']);
      expect(childNames(one('Group')), ['OK', 'Cancel']);
      expect(rootNames(), ['Canvas', 'Light']);

      history.undo();
      expect(childNames(canvas), ['Title', 'OK', 'Cancel', 'Footer']);
      expect(rootNames(), ['Canvas', 'Light']);
      history.redo();
      expect(childNames(canvas), ['Title', 'Group', 'Footer']);
      expect(title.isAlive, isTrue);
    });

    test('goes under the nearest parent they are all under', () {
      final canvas = make('Canvas');
      final top = make('Top', under: canvas);
      final bottom = make('Bottom', under: canvas);
      final a = make('A', under: top);
      final b = make('B', under: bottom);

      history.push(grouping([b, a]));
      // In the place of Top, which holds the first of them; Top and Bottom
      // stay, emptied.
      expect(childNames(canvas), ['Group', 'Top', 'Bottom']);
      expect(childNames(one('Group')), ['B', 'A']);
      expect(childNames(top), isEmpty);

      history.undo();
      expect(childNames(top), ['A']);
      expect(childNames(bottom), ['B']);
      expect(childNames(canvas), ['Top', 'Bottom']);
    });

    test('leaves out what is under another of what it groups', () {
      final canvas = make('Canvas');
      final panel = make('Panel', under: canvas);
      final label = make('Label', under: panel);
      final command = grouping([label, panel]);
      expect(command.label, 'Group 1 entity');
      history.push(command);
      expect(childNames(one('Group')), ['Panel']);
      expect(childNames(panel), ['Label']);
    });

    test('on a Level Map, the group takes the map layer and gives it back '
        'when taken apart', () {
      final map = make(
        'Level Map',
        also: [LevelMapComponent(mapPath: 'assets/maps/a.map.json')],
      );
      make('Rock', under: map, also: [LayerComponent(mapLayer: 1)]);
      final a = make('A', under: map, also: [LayerComponent(mapLayer: 2)]);
      final b = make('B', under: map, also: [LayerComponent(mapLayer: 2)]);
      int? layerOf(Entity e) => e.getComponent<LayerComponent>()?.mapLayer;

      final command = grouping([a, b]);
      history.push(command);
      final made = command.group!;
      expect(childNames(map), ['Rock', 'Group']);
      expect(layerOf(made), 2, reason: 'the group is on the map');
      expect(layerOf(a), isNull, reason: 'in the group, off the map');
      expect(layerOf(b), isNull);

      history.undo();
      expect(childNames(map), ['Rock', 'A', 'B']);
      expect([layerOf(a), layerOf(b)], [2, 2]);

      history.redo();
      history.push(
        UngroupCommand(
          world: world,
          sceneState: state,
          group: command.group!,
          codec: codec,
        ),
      );
      expect(childNames(map), ['Rock', 'A', 'B']);
      expect([layerOf(a), layerOf(b)], [2, 2], reason: 'back on its layer');

      history.undo();
      expect(childNames(one('Group')), ['A', 'B']);
      expect([layerOf(a), layerOf(b)], [null, null]);
    });

    test('ungrouping on a map gives a layer to what had no layer '
        'component, and takes it off again', () {
      final map = make(
        'Level Map',
        also: [LevelMapComponent(mapPath: 'assets/maps/a.map.json')],
      );
      final g = make('Group', under: map, also: [LayerComponent(mapLayer: 3)]);
      final bare = make('Bare', under: g);
      history.push(
        UngroupCommand(world: world, sceneState: state, group: g, codec: codec),
      );
      expect(bare.getComponent<LayerComponent>()?.mapLayer, 3);
      history.undo();
      expect(bare.hasComponent<LayerComponent>(), isFalse);
    });
  });

  test('a group made on a Level Map can be selected while only the map '
      'can', () {
    final map = make(
      'Level Map',
      also: [LevelMapComponent(mapPath: 'assets/maps/a.map.json')],
    );
    final a = make('A', under: map, also: [LayerComponent(mapLayer: 1)]);
    final b = make('B', under: map, also: [LayerComponent(mapLayer: 1)]);
    bool onMap(Entity e) {
      for (Entity? at = e; at != null;) {
        if (at.id == map.id) return true;
        final up = at.getComponent<ParentComponent>()?.parentId;
        at = up == null ? null : world.getEntity(up);
      }
      return false;
    }

    // The Level Designer's focus: only the map's own subtree.
    state.setSelectable(onMap);
    final command = grouping([a, b]);
    history.push(command);
    state.selectEntity(command.group!);
    expect(state.selectedEntity.value, same(command.group));
  });

  group('reordering', () {
    test('moves a root among the roots, and back', () {
      make('A');
      final b = make('B');
      make('C');
      history.push(
        ReorderCommand(
          label: 'Move',
          world: world,
          sceneState: state,
          entity: b,
          index: 2,
        ),
      );
      expect(rootNames(), ['A', 'C', 'B']);
      history.undo();
      expect(rootNames(), ['A', 'B', 'C']);
    });

    test('moves a child among its siblings, and back', () {
      final p = make('P');
      final a = make('a', under: p);
      make('b', under: p);
      make('c', under: p);
      history.push(
        ReorderCommand(
          label: 'Move',
          world: world,
          sceneState: state,
          entity: a,
          index: 1,
        ),
      );
      expect(childNames(p), ['b', 'a', 'c']);
      history.undo();
      expect(childNames(p), ['a', 'b', 'c']);
      history.redo();
      expect(childNames(p), ['b', 'a', 'c']);
    });
  });

  group('a large selection', () {
    test('every place is worked out as one at a time would', () {
      final map = make('Map');
      final kids = [for (var i = 0; i < 50; i++) make('t$i', under: map)];
      make('Root');
      final all = [map, ...kids.reversed, one('Root')];
      expect(
        [
          for (final s in HierarchySlot.ofAll(
            all,
            world: world,
            sceneState: state,
          ))
            (s.parentId, s.index),
        ],
        [
          for (final e in all)
            switch (HierarchySlot.of(e, world: world, sceneState: state)) {
              final s => (s.parentId, s.index),
            },
        ],
      );
    });

    test('moving a parent with its children moves the parent alone', () {
      final map = make('Map');
      final kids = [for (var i = 0; i < 3000; i++) make('t$i', under: map)];
      final target = make('Target');
      final move = ReparentCommand(
        label: 'Move',
        world: world,
        sceneState: state,
        entities: [...kids, map],
        parent: target,
      );
      expect(move.isValid, isTrue);
      history.push(move);
      expect(childNames(target), ['Map']);
      expect(childNames(map), hasLength(3000));

      final intoOwnChild = ReparentCommand(
        label: 'Move',
        world: world,
        sceneState: state,
        entities: [target],
        parent: kids.last,
      );
      expect(intoOwnChild.isValid, isFalse);
    });

    test('a delete of thousands of children puts each back in its place', () {
      final map = make('Map');
      for (var i = 0; i < 2000; i++) {
        make('t$i', under: map);
      }
      final before = childNames(map);
      final every = [
        for (final id in map.getComponent<ChildrenComponent>()!.childIds)
          world.getEntity(id)!,
      ];
      history.push(
        DeleteEntitiesCommand(
          label: 'Delete',
          world: world,
          sceneState: state,
          entities: [for (var i = every.length - 1; i >= 0; i -= 2) every[i]],
          codec: codec,
        ),
      );
      expect(childNames(map), hasLength(1000));
      history.undo();
      expect(childNames(map), before);
    });
  });
}
