// Tag uses in saved files: what an instance of a prefab changes, a prefab
// file's own entities, and the short "#tag" text a hand-written file may
// hold — found, renamed and removed like every other use.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  late EditorScope scope;

  setUp(() {
    scope = EditorScope(world: World()..initialize());
    addTearDown(scope.dispose);
  });

  Map<String, dynamic> saved(Component c) =>
      jsonDecode(jsonEncode(scope.definitions.definitionFor(c)!.encode(c)));

  test('an instance\'s changes and added components are walked', () {
    final tags = saved(TagComponent.of(['enemy', 'boss']));
    final camera = saved(
      VirtualCameraComponent(follow: const EntityTarget.tag('enemy')),
    );
    final scene = {
      'entities': [
        {
          'name': 'Goblin',
          'prefab': {
            'path': 'assets/prefabs/goblin.prefab.json',
            'overrides': [
              {
                'target': 'body',
                'component': tags['type'],
                'field': 'tags',
                'value': ['enemy', 'boss'],
              },
            ],
            'addedComponents': [
              {'target': 'body', 'component': camera},
            ],
          },
        },
      ],
    };
    final refs = scope.tagReferences;
    expect(refs.inScene(scene, tag: 'enemy'), hasLength(2));
    expect(refs.renameInScene(scene, 'enemy', 'foe'), 2);
    final block = (scene['entities']!.single as Map)['prefab'] as Map;
    expect((block['overrides'] as List).single['value'], ['foe', 'boss']);
    final added = (block['addedComponents'] as List).single['component'];
    expect(jsonEncode(added), contains('"foe"'));
    expect(refs.inScene(scene, tag: 'enemy'), isEmpty);

    expect(refs.removeFromScene(scene, 'boss'), 1);
    expect((block['overrides'] as List).single['value'], ['foe']);
  });

  test('a prefab file is walked like a scene', () {
    final prefab = PrefabFile(
      name: 'Goblin',
      entities: [
        PrefabEntity(
          id: 'body',
          name: 'Body',
          components: [
            saved(TagComponent.of(['enemy'])),
          ],
        ),
      ],
    ).toJson();
    final refs = scope.tagReferences;
    expect(refs.inScene(prefab, tag: 'enemy').single.owner, 'Body');
    expect(refs.renameInScene(prefab, 'enemy', 'foe'), 1);
    expect(PrefabFile.fromJson(prefab).encode(), contains('"foe"'));
  });

  test('the short "#tag" forms are found and renamed in place', () {
    final camera = saved(VirtualCameraComponent());
    final field = (camera['fields'] as Map).keys.firstWhere(
      (k) => k == 'follow',
    );
    (camera['fields'] as Map)[field] = '#player';
    // An inline timeline's track bound by the short text too.
    (camera['fields'] as Map)['timeline'] = {
      'tracks': [
        {'binding': '#player'},
        {
          'binding': {'name': 'Door', 'tag': 'player'},
        },
      ],
    };
    final scene = {
      'entities': [
        {
          'name': 'Cam',
          'components': [camera],
        },
      ],
    };
    final refs = scope.tagReferences;
    expect(
      refs.inScene(scene, tag: 'player'),
      hasLength(2),
      reason: 'a binding naming an entity is not a tag, as the engine reads',
    );
    expect(refs.renameInScene(scene, 'player', 'hero'), 2);
    final fields = camera['fields'] as Map;
    expect(fields[field], '#hero');
    expect((fields['timeline']['tracks'] as List).first['binding'], '#hero');
    expect(
      EntityTarget.fromJson(fields[field]),
      const EntityTarget.tag('hero'),
    );
  });

  test('a scene that cannot be read gives no tags, and breaks nothing', () {
    final root = Directory.systemTemp.createTempSync('tag_seed_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/odd.scene.json').writeAsStringSync('[1, 2]');
    File(
      '${root.path}/newer.scene.json',
    ).writeAsStringSync('{"version": 9999, "entities": []}');
    File('${root.path}/good.scene.json').writeAsStringSync(
      jsonEncode({
        'version': SceneFormat.current,
        'entities': [
          {
            'name': 'Coin',
            'components': [
              saved(TagComponent.of(['coin'])),
            ],
          },
        ],
      }),
    );
    final seeded = EditorScope(
      world: World()..initialize(),
      scenesRoot: root.path,
    );
    addTearDown(seeded.dispose);
    expect(() => seeded.tags, returnsNormally);
    expect(seeded.tags.names, contains('coin'));
    // Made once: a rebuild after it keeps the declared tags in step.
    expect(seeded.reload, returnsNormally);
  });
}
