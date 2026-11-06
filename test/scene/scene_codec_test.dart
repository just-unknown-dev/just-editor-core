// A scene file links a child to its parent by name, so a parent with no
// name of its own still has one in the file — the same in its record and
// in its children's — or the child is a root once the scene is opened
// again. A file saved before that was so is mended as it is read.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  late World world;
  late EditorSceneState state;
  late SceneCodec codec;

  setUp(() {
    world = World(extensions: [BuiltInComponents.extension])..initialize();
    state = EditorSceneState()..openScene(EditorScene(name: 'test'));
    codec = SceneCodec(world.context.definitions);
  });

  tearDown(() {
    state.dispose();
    world.dispose();
  });

  Entity make(String? name, {Entity? under}) {
    final e = world.createEntityWithComponents([
      TransformComponent(),
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

  List<Map<String, dynamic>> save() =>
      codec.encodeEntities(world.entities.toList());

  test('a child of an unnamed parent is still its child when the scene is '
      'read again', () {
    final parent = make(null);
    make('Child', under: parent);
    make('Grandchild', under: world.entities.last);
    final saved = save();
    expect(saved.first['name'], 'entity_${parent.id}');
    expect(saved[1]['parentName'], 'entity_${parent.id}');
    expect(SceneLoader.parentIndices(saved), [null, 0, 1]);
  });

  test('the name made up is one no entity has', () {
    final parent = make(null);
    make('Child', under: parent);
    make('entity_${parent.id}'); // a root that took the name first
    final saved = save();
    final name = saved.first['name'];
    expect(name, 'entity_${parent.id}_2');
    expect(saved[1]['parentName'], name);
    expect(SceneLoader.parentIndices(saved), [null, 0, null]);
  });

  test('an unnamed entity nothing is under stays unnamed', () {
    make(null);
    make('Named');
    expect(save().first['name'], isNull);
  });

  test('the records kept beside their entities keep their names as they '
      'are', () {
    // What a play-test puts back from: the entity has no name, and must
    // not be given one by being put back.
    final parent = make(null);
    make('Child', under: parent);
    final records = codec.encodeInOrder(
      SceneCodec.inTreeOrder([...world.entities]),
    );
    expect(records.first['name'], isNull);
    expect(records[1]['parentName'], 'entity_${parent.id}');
  });

  group('a file saved before', () {
    test('has its unnamed parents named as its children name them', () {
      final entries = <Map<String, dynamic>>[
        {'name': 'Ground', 'components': <Object?>[]},
        {'name': null, 'components': <Object?>[]},
        {'name': 'Door', 'parentName': 'entity_7', 'components': <Object?>[]},
        {'name': 'Key', 'parentName': 'entity_7', 'components': <Object?>[]},
      ];
      expect(SceneLoader.parentIndices(entries), [null, null, null, null]);
      expect(SceneCodec.nameUnnamedParents(entries), 1);
      expect(entries[1]['name'], 'entity_7');
      expect(SceneLoader.parentIndices(entries), [null, null, 1, 1]);
    });

    test('is left as it is where it cannot be told which is the parent', () {
      final entries = <Map<String, dynamic>>[
        // The record before the first child has a name: not the parent.
        {'name': 'Ground', 'components': <Object?>[]},
        {'name': 'Door', 'parentName': 'entity_7', 'components': <Object?>[]},
        // A later child of the same name is not looked at again.
        {'name': null, 'components': <Object?>[]},
        {'name': 'Key', 'parentName': 'entity_7', 'components': <Object?>[]},
        // A name the editor never made up is not guessed at.
        {'name': null, 'components': <Object?>[]},
        {'name': 'Lamp', 'parentName': 'Gone', 'components': <Object?>[]},
        // A name some record has is the parent already.
        {'name': 'entity_9', 'components': <Object?>[]},
        {'name': null, 'components': <Object?>[]},
        {'name': 'Bell', 'parentName': 'entity_9', 'components': <Object?>[]},
      ];
      expect(SceneCodec.nameUnnamedParents(entries), 0);
      expect(entries[2]['name'], isNull);
      expect(entries[4]['name'], isNull);
      expect(entries[7]['name'], isNull);
    });
  });
}
