// The scene files: renames that never delete, duplicates that never
// overwrite, a play order never thrown away, readers that never crash, and
// backups that never reach outside their folder.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/host.dart';

void main() {
  late Directory root;
  late SceneStore store;
  late World world;

  setUp(() {
    root = Directory.systemTemp.createTempSync('scene_store_test');
    world = World();
    store = SceneStore(
      codec: SceneCodec(world.context.definitions),
      root: root.path,
    );
  });

  tearDown(() {
    world.dispose();
    root.deleteSync(recursive: true);
  });

  File scene(String name) => File('${root.path}/$name.scene.json');
  File manifest() => File('${root.path}/scenes.json');
  List<String> listed() =>
      ((jsonDecode(manifest().readAsStringSync()) as Map)['scenes'] as List)
          .cast<String>();
  String? nameInside(String file) =>
      (jsonDecode(scene(file).readAsStringSync()) as Map)['name'] as String?;

  test('a rename that only changes letter case keeps the scene', () async {
    await store.writeInitialFiles('level_01');
    await store.renameSceneFiles('level_01', 'Level_01');

    final names = root
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.scene.json'))
        .toList();
    expect(names, ['Level_01.scene.json'], reason: 'renamed, not deleted');
    expect(nameInside('Level_01'), 'Level_01');
    expect(listed(), ['Level_01']);
  });

  test('a rename onto another scene is refused, changing nothing', () async {
    await store.writeInitialFiles('a');
    await store.writeInitialFiles('b');
    final before = scene('b').readAsStringSync();
    await expectLater(
      store.renameSceneFiles('a', 'b'),
      throwsA(isA<FileSystemException>()),
    );
    expect(scene('a').existsSync(), isTrue);
    expect(scene('b').readAsStringSync(), before);
    expect(listed(), ['a', 'b']);
  });

  test('a rename takes the backups along', () async {
    await store.writeInitialFiles('cave');
    await store.writeBackup('cave', '{}', keep: 5);
    await store.renameSceneFiles('cave', 'grotto');
    expect(store.backupsOf('grotto'), hasLength(1));
    expect(store.backupsOf('cave'), isEmpty);
  });

  test(
    'a duplicate onto itself, or a case variant of it, is refused',
    () async {
      await store.writeInitialFiles('level_01');
      final before = scene('level_01').readAsStringSync();
      for (final to in ['level_01', if (ProjectFiles.foldsCase) 'Level_01']) {
        await expectLater(
          store.duplicateSceneFiles('level_01', to),
          throwsA(isA<FileSystemException>()),
          reason: to,
        );
      }
      expect(scene('level_01').readAsStringSync(), before);
      expect(listed(), ['level_01']);
    },
  );

  test('a scenes.json that cannot be read is never rewritten', () async {
    await store.writeInitialFiles('level_01');
    const broken = '{"scenes": ["level_01", "level_02",]}';
    manifest().writeAsStringSync(broken);

    await expectLater(
      store.writeSceneJson('level_03', EditorScene(name: 'level_03'), []),
      throwsA(isA<FormatException>()),
    );
    expect(scene('level_03').existsSync(), isTrue, reason: 'the scene saved');
    expect(manifest().readAsStringSync(), broken, reason: 'the list kept');

    await expectLater(
      store.duplicateSceneFiles('level_01', 'level_04'),
      throwsA(isA<FormatException>()),
    );
    expect(scene('level_04').existsSync(), isFalse, reason: 'nothing done');
  });

  test('saving leaves no temporary file behind', () async {
    await store.writeSceneJson('level_01', EditorScene(name: 'level_01'), []);
    final names = root.listSync().map((e) => e.uri.pathSegments.last);
    expect(names.where((n) => n.endsWith('.saving')), isEmpty);
  });

  test('readers do not crash on a scene of the wrong shape, and opening '
      'one is refused, naming the file', () async {
    scene('array').writeAsStringSync('[]');
    scene('object').writeAsStringSync('{"name": "object", "entities": {}}');
    scene('bytes').writeAsBytesSync([0xff, 0xfe, 0x00]);

    for (final name in ['array', 'object', 'bytes']) {
      final summary = store.summaryOf(name);
      expect(summary, isNotNull, reason: name);
      expect(summary!.isReadable, isFalse, reason: name);
    }
    for (final name in ['array', 'bytes']) {
      expect(store.readRawSync(name), isNull, reason: name);
      expect(await store.loadFromSidecar(name), isNull, reason: name);
      // Never "nothing there": an unreadable scene opened as an empty one
      // would be saved over the file.
      await expectLater(
        store.loadRawSidecar(name),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('$name.scene.json'),
          ),
        ),
        reason: name,
      );
    }
    expect(await store.loadRawSidecar('missing'), isNull);
  });

  test('a scene is named by its file, not by what it says inside', () async {
    await store.writeInitialFiles('level_01');
    scene('level_01').copySync(scene('level_07').path);
    expect(nameInside('level_07'), 'level_01');

    final opened = await store.loadFromSidecar('level_07');
    expect(opened!.name, 'level_07');
    expect(
      EditorScene.fromJson(const {'mode': '2d'}, name: 'x').name,
      'x',
      reason: 'a file with no name inside still opens',
    );
  });

  test('names that are not one file name are refused', () async {
    for (final bad in ['..', '.', 'a/b', r'a\b', '']) {
      await expectLater(
        store.writeBackup(bad, '{}', keep: 3),
        throwsA(isA<ArgumentError>()),
        reason: bad,
      );
    }
    // A file named "...scene.json" is not offered as the scene "..".
    File('${root.path}/...scene.json').writeAsStringSync('{}');
    expect(store.listSceneNames(), isNot(contains('..')));
  });

  test('pruning backups deletes only backups', () async {
    final dir = Directory('${store.backupsRoot}/level_01')
      ..createSync(recursive: true);
    final keepMe = File('${dir.path}/notes.txt')..writeAsStringSync('mine');
    for (var i = 0; i < 4; i++) {
      await store.writeBackup('level_01', '{"n": $i}', keep: 2);
    }
    expect(store.backupsOf('level_01'), hasLength(2));
    expect(keepMe.existsSync(), isTrue);
    final newest = store.backupsOf('level_01').first;
    expect(newest.readAsStringSync(), '{"n": 3}');
  });

  test('a deleted scene goes to the trash, not away', () async {
    await store.writeInitialFiles('level_01');
    final text = scene('level_01').readAsStringSync();
    final kept = await store.deleteSceneFiles('level_01');
    expect(scene('level_01').existsSync(), isFalse);
    expect(File(kept!).readAsStringSync(), text);
    expect(listed(), isEmpty);
  });
}
