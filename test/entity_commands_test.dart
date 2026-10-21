// Undo and redo across entities that are destroyed and made again.
//
// A world never gives an id out twice, so an undone delete brings an entity
// back under a new one. Every command finds its entity as it is now
// (EditorSceneState.entityRebuilt), so a chain of undo and redo never goes
// silent, never duplicates, and puts each entity back as it was: switched
// off if it was off, in its prefab instance, under its own parent, in its
// own place.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/host.dart';

void main() {
  late World world;
  late EditorSceneState state;
  late EditorHistory history;
  late SceneCodec codec;

  setUp(() {
    world = World()..initialize();
    state = EditorSceneState()..openScene(EditorScene(name: 'test'));
    history = EditorHistory();
    codec = SceneCodec(world.context.definitions);
  });

  tearDown(() {
    history.dispose();
    state.dispose();
    world.dispose();
  });

  Entity make(String? name, {Entity? under, double x = 0}) {
    final e = world.createEntityWithComponents([
      TransformComponent(position: Vector3(x, 0, 0)),
      HealthComponent(maxHealth: 3),
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

  List<Entity> named(String name) => [
    for (final e in world.entities)
      if (e.isAlive && e.name == name) e,
  ];

  Entity one(String name) {
    final found = named(name);
    expect(found, hasLength(1), reason: 'exactly one "$name"');
    return found.single;
  }

  List<EntityId> childIds(Entity e) =>
      e.getComponent<ChildrenComponent>()?.childIds ?? const [];

  List<String?> childNames(Entity e) => [
    for (final id in childIds(e)) world.getEntity(id)?.name,
  ];

  List<String?> rootNames() => [
    for (final id in state.rootOrder(world)) world.getEntity(id)?.name,
  ];

  void delete(List<Entity> entities) => history.push(
    DeleteEntitiesCommand(
      label: 'Delete',
      world: world,
      sceneState: state,
      entities: entities,
      codec: codec,
    ),
  );

  group('delete, undo, redo', () {
    test('a cycle never duplicates and never goes silent', () {
      make('Platform');
      delete([one('Platform')]);
      expect(named('Platform'), isEmpty);

      for (var round = 0; round < 3; round++) {
        history.undo();
        expect(named('Platform'), hasLength(1), reason: 'undo $round');
        history.redo();
        expect(named('Platform'), isEmpty, reason: 'redo $round deletes it');
      }
      history.undo();
      expect(named('Platform'), hasLength(1));
    });

    test('a switched-off entity comes back switched off', () {
      final enemy = make('Enemy')..isActive = false;
      delete([enemy]);
      history.undo();
      expect(one('Enemy').isActive, isFalse);
    });

    test('a group switched off comes back off after ungroup is undone', () {
      final group = make('Group')..isActive = false;
      make('A', under: group);
      history.push(
        UngroupCommand(
          world: world,
          sceneState: state,
          group: group,
          codec: codec,
        ),
      );
      expect(named('Group'), isEmpty);
      history.undo();
      expect(one('Group').isActive, isFalse);
      expect(childNames(one('Group')), ['A']);
    });

    test('siblings come back in their own order, whatever the selection '
        'order', () {
      final a = make('A'), b = make('B');
      make('C');
      make('D');
      expect(rootNames(), ['A', 'B', 'C', 'D']);
      delete([b, a]); // B clicked first, then A.
      history.undo();
      expect(rootNames(), ['A', 'B', 'C', 'D']);

      final p = make('P');
      final kids = [
        for (final n in ['k0', 'k1', 'k2', 'k3']) make(n, under: p),
      ];
      delete([kids[2], kids[0]]);
      history.undo();
      expect(childNames(p), ['k0', 'k1', 'k2', 'k3']);
    });

    test('a child goes back under its own parent, not an older one of the '
        'same name', () {
      // Two instances of one prefab: their parts share names.
      final door1 = make('Door_1');
      final frame1 = make('Frame', under: door1);
      make('Handle', under: frame1);
      final door2 = make('Door_2');
      final frame2 = make('Frame', under: door2);
      make('Handle', under: frame2);

      delete([door2]);
      history.undo();

      final restored = one('Door_2');
      final frame = world.getEntity(childIds(restored).single)!;
      expect(frame.name, 'Frame');
      expect(childNames(frame), ['Handle']);
      expect(childNames(frame1), ['Handle'], reason: 'Door_1 untouched');
    });

    test('a prefab instance stays one through delete and undo', () {
      final top = make('Door');
      final part = make('Frame', under: top);
      top
        ..addComponent(PrefabLink(instance: top.id, path: 'd1'))
        ..addComponent(
          PrefabInstanceComponent(
            block: PrefabInstance(path: 'prefabs/door.prefab.json'),
          ),
        );
      part.addComponent(PrefabLink(instance: top.id, path: 'f1'));

      delete([top]);
      history.undo();

      final door = one('Door'), frame = one('Frame');
      expect(
        door.getComponent<PrefabInstanceComponent>()?.path,
        'prefabs/door.prefab.json',
      );
      expect(door.getComponent<PrefabLink>()?.instance, door.id);
      expect(
        frame.getComponent<PrefabLink>()?.instance,
        door.id,
        reason: 'linked to the rebuilt top, not the destroyed one',
      );
      expect(frame.getComponent<PrefabLink>()?.path, 'f1');

      final ordered = SceneCodec.inTreeOrder([door, frame]);
      final records = codec.encodeInOrder(ordered);
      expect(SceneCodec.markPrefabs(ordered, records), isTrue);
      expect(records.first['prefabRef'], isA<Map>());
      expect((records.first['prefabRef'] as Map)['block'], isA<Map>());
    });
  });

  group('commands find what was rebuilt', () {
    test('a move of a copy is redone after the copy is made again', () {
      final copy = make('Copy');
      history.pushApplied(
        CreateEntitiesCommand.adopting(
          label: 'Duplicate',
          world: world,
          sceneState: state,
          entities: [copy],
          codec: codec,
        ),
      );
      final before = TransformSnapshot.of(copy);
      copy.getComponent<TransformComponent>()!.setPositionXY(100, 50);
      history.pushApplied(
        TransformCommand(
          label: 'Move',
          entities: [copy],
          before: [before],
          after: [TransformSnapshot.of(copy)],
          sceneState: state,
        ),
      );

      history
        ..undo()
        ..undo();
      expect(named('Copy'), isEmpty);
      history
        ..redo()
        ..redo();
      final p = one('Copy').getComponent<TransformComponent>()!.position;
      expect((p.x, p.y), (100.0, 50.0), reason: 'the move is redone');
    });

    test('a rename of a group is redone on the group made again', () {
      final a = make('A'), b = make('B');
      final group = GroupCommand(
        world: world,
        sceneState: state,
        entities: [a, b],
        name: 'group_1',
        position: Vector3.zero(),
      );
      history.push(group);
      history.push(
        RenameCommand(sceneState: state, entity: group.group!, name: 'Room'),
      );
      history
        ..undo()
        ..undo();
      expect(named('Room'), isEmpty);
      expect(rootNames(), ['A', 'B']);
      history
        ..redo()
        ..redo();
      expect(childNames(one('Room')), ['A', 'B']);
    });

    test('a field edit undoes after the component was replaced', () {
      final e = make('E');
      final health = e.getComponent<HealthComponent>()!;
      health.health = 3;
      history.push(
        ComponentFieldCommand(
          label: 'Change health',
          component: health,
          entity: e,
          write: (c, v) => (c as HealthComponent).health = v! as double,
          before: 3.0,
          after: 1.0,
          sceneState: state,
        ),
      );
      // A resize, a flip — or Stop after a play-test — puts in fresh
      // component instances.
      final spec = EntitySpec.of(e, codec);
      history.pushApplied(
        EntityStateCommand(
          label: 'Resize',
          world: world,
          sceneState: state,
          ids: [e.id],
          before: [spec],
          after: [spec],
        ),
      );
      spec.applyTo(e);
      expect(e.getComponent<HealthComponent>(), isNot(same(health)));

      history
        ..undo()
        ..undo();
      expect(e.getComponent<HealthComponent>()!.health, 3.0);
      history.redo();
      expect(e.getComponent<HealthComponent>()!.health, 1.0);
    });

    test('an edit made before a delete still undoes after the delete is '
        'undone', () {
      final e = make('E');
      history.push(
        ComponentFieldCommand(
          label: 'Change health',
          component: e.getComponent<HealthComponent>()!,
          entity: e,
          write: (c, v) => (c as HealthComponent).maxHealth = v! as double,
          before: 3.0,
          after: 9.0,
          sceneState: state,
        ),
      );
      delete([e]);
      history
        ..undo() // the delete: E is back, under a new id
        ..undo(); // the edit
      expect(one('E').getComponent<HealthComponent>()!.maxHealth, 3.0);
    });
  });

  group('adding a component', () {
    test('of a type the entity has puts the old one back on undo', () {
      final e = world.createEntityWithComponents([
        TransformComponent(),
        RectangleComponent(width: 64, height: 16),
        HealthComponent(maxHealth: 1),
      ], name: 'Platform');
      state.registerEntity(e);
      final order = e.componentTypes;

      history.push(
        AddComponentCommand(
          entity: e,
          component: CircleComponent(radius: 8),
          sceneState: state,
        ),
      );
      expect(e.getComponentByType(RenderableComponent), isA<CircleComponent>());

      history.undo();
      final shape = e.getComponentByType(RenderableComponent);
      expect(shape, isA<RectangleComponent>());
      expect((shape! as RectangleComponent).width, 64);
      expect(e.componentTypes, order);
    });
  });

  group('moving in the tree', () {
    test('several siblings dragged down land together, and undo puts them '
        'back', () {
      final p = make('P');
      final e1 = make('e1', under: p), e2 = make('e2', under: p);
      make('a', under: p);
      make('b', under: p);
      // Dropped below b: index 4, less the two above the line.
      history.push(
        ReparentCommand(
          label: 'Move',
          world: world,
          sceneState: state,
          entities: [e1, e2],
          parent: p,
          index: 2,
        ),
      );
      expect(childNames(p), ['a', 'b', 'e1', 'e2']);
      history.undo();
      expect(childNames(p), ['e1', 'e2', 'a', 'b']);
    });

    test('root positions count what the tree shows after a group', () {
      final ground = make('Ground');
      final player = make('Player');
      make('Camera');
      make('Light');
      history.push(
        GroupCommand(
          world: world,
          sceneState: state,
          entities: [player],
          name: 'Group',
          position: Vector3.zero(),
        ),
      );
      expect(rootNames(), ['Ground', 'Camera', 'Light', 'Group']);
      // Ground dropped below Camera: index 2, less one above the line.
      history.push(
        ReparentCommand(
          label: 'Move',
          world: world,
          sceneState: state,
          entities: [ground],
          parent: null,
          index: 1,
        ),
      );
      expect(rootNames(), ['Camera', 'Ground', 'Light', 'Group']);
      history.undo();
      expect(rootNames(), ['Ground', 'Camera', 'Light', 'Group']);
    });

    test('renaming an unnamed entity undoes back to no name', () {
      final e = make(null);
      history.push(RenameCommand(sceneState: state, entity: e, name: 'Named'));
      expect(e.name, 'Named');
      history.undo();
      expect(e.name, isNull);
    });
  });

  test('a snapped scale keeps its sign', () {
    final e = make('Flipped');
    state
      ..scaleStep = 0.1
      ..setScaleX(e, -1);
    expect(e.getComponent<TransformComponent>()!.scale.x, -1);
    state.setScale3(e, Vector3(-2, 1, 1));
    expect(e.getComponent<TransformComponent>()!.scale.x, -2);
  });
  test('a save that fails part-way leaves prefab instances where they '
      'stand', () {
    final home = codec.encode(TransformComponent())!;
    final good = PrefabFile(
      name: 'good',
      entities: [
        PrefabEntity(id: 'r', name: 'r', components: [home]),
      ],
    );
    final failing = SceneCodec(
      world.context.definitions,
      prefabs: (path) => path == 'good.prefab.json'
          ? good
          : throw StateError('unreadable prefab'),
    );
    Entity instance(String name, String path, double x) {
      final top = make(name, x: x);
      top
        ..addComponent(PrefabLink(instance: top.id, path: 'r'))
        ..addComponent(
          PrefabInstanceComponent(block: PrefabInstance(path: path)),
        );
      return top;
    }

    final first = instance('First', 'good.prefab.json', 300);
    final second = instance('Second', 'bad.prefab.json', 500);
    expect(
      () => failing.encodeForSave([first, second]),
      throwsA(isA<StateError>()),
    );
    expect(
      first.getComponent<TransformComponent>()!.position.x,
      300,
      reason: 'moved to its prefab home for the save, and back',
    );
    expect(second.getComponent<TransformComponent>()!.position.x, 500);
  });
}
