// The project files the editor keeps — tags, collision layers, palettes —
// and the editor's own store: a file that cannot be read is left as it is
// and never written over; a write that fails changes nothing and leaves no
// half file; the editor's settings live in a store of their own.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_colours/just_colours.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_editor_core/src/settings/editor_storage.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_storage/just_storage.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('project_services_');
    addTearDown(() {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may hold it for a moment; it is a temporary one.
      }
    });
  });

  File file(String name) => File('${root.path}/$name');

  List<String> leftovers() => [
    for (final f in root.listSync(recursive: true))
      if (f.path.endsWith('.saving')) f.path,
  ];

  group('the collision layers', () {
    test('a broken file is left as it is, and changes are refused', () {
      const broken = '{"version": 1, "layers": [ ,]}';
      file('physics.json').writeAsStringSync(broken);
      final said = <String>[];
      final store = ProjectPhysicsLayers(
        path: file('physics.json').path,
        onProblem: said.add,
      )..load();
      addTearDown(store.dispose);

      expect(store.isUnreadable, isTrue);
      expect(store.error, contains('not valid'));
      expect(said, hasLength(1));
      expect(store.value, jge.PhysicsLayers.defaults);

      expect(store.create('Player'), isNull);
      expect(store.rename(0, 'Ground'), isFalse);
      store.setCollision(0, 1, false);
      expect(store.value, jge.PhysicsLayers.defaults);
      expect(file('physics.json').readAsStringSync(), broken);

      // Fixed by hand and read again, it changes once more.
      file('physics.json').writeAsStringSync('{"version": 1, "layers": []}');
      store.load();
      expect(store.isUnreadable, isFalse);
      expect(store.create('Player'), 1);
    });

    test('a file from a newer engine is never written over', () {
      const newer = '{"version": 999, "layers": []}';
      file('physics.json').writeAsStringSync(newer);
      final store = ProjectPhysicsLayers(path: file('physics.json').path)
        ..load();
      addTearDown(store.dispose);
      expect(store.isUnreadable, isTrue);
      expect(store.create('Player'), isNull);
      expect(file('physics.json').readAsStringSync(), newer);
    });

    test('a hand-edited wrong type is reported, not thrown', () {
      file('physics.json').writeAsStringSync('{"version": "1"}');
      final store = ProjectPhysicsLayers(path: file('physics.json').path);
      addTearDown(store.dispose);
      expect(store.load, returnsNormally);
      expect(store.isUnreadable, isTrue);
    });

    test('a write that fails changes nothing and leaves no half file', () {
      // A folder where the file goes: nothing can be written there.
      Directory('${root.path}/physics.json').createSync();
      final said = <String>[];
      final store = ProjectPhysicsLayers(
        path: '${root.path}/physics.json',
        onProblem: said.add,
      )..load();
      addTearDown(store.dispose);
      expect(store.create('Player'), isNull);
      expect(store.value.isNamed(1), isFalse);
      expect(store.error, contains('Could not write'));
      expect(said, hasLength(1));

      // Not there at all, but its folder cannot be made.
      file('blocker').writeAsStringSync('');
      final blocked = ProjectPhysicsLayers(
        path: '${root.path}/blocker/physics.json',
        onProblem: said.add,
      )..load();
      addTearDown(blocked.dispose);
      expect(blocked.isUnreadable, isFalse);
      expect(blocked.create('Player'), isNull);
      expect(blocked.value.isNamed(1), isFalse);
      expect(blocked.error, contains('Could not write'));
      expect(leftovers(), isEmpty);
    });
  });

  group('the tag list', () {
    test('a broken file is left as it is, and changes are refused', () {
      const broken = '{"version": 1, "tags": [';
      file('tags.json').writeAsStringSync(broken);
      final said = <String>[];
      final tags = ProjectTags(
        path: file('tags.json').path,
        onProblem: said.add,
      )..load();
      addTearDown(tags.dispose);

      expect(tags.isUnreadable, isTrue);
      expect(tags.loadError, contains('not valid'));
      expect(tags.create('enemy'), isNull);
      expect(tags.adopt(['coin']), 0);
      expect(tags.remove('coin'), isFalse);
      expect(tags.library.value.contains('enemy'), isFalse);
      expect(file('tags.json').readAsStringSync(), broken);

      file('tags.json').writeAsStringSync('{"version": 1, "tags": []}');
      tags.load();
      expect(tags.create('enemy'), isNotNull);
    });

    test('a file from a newer engine is never written over', () {
      const newer = '{"version": 999, "tags": []}';
      file('tags.json').writeAsStringSync(newer);
      final tags = ProjectTags(path: file('tags.json').path)..load();
      addTearDown(tags.dispose);
      expect(tags.isUnreadable, isTrue);
      expect(tags.create('enemy'), isNull);
      expect(file('tags.json').readAsStringSync(), newer);
    });

    test('a write that fails is not shown as made, and says so', () {
      file('blocker').writeAsStringSync('');
      final said = <String>[];
      final tags = ProjectTags(
        path: '${root.path}/blocker/tags.json',
        onProblem: said.add,
      )..load();
      addTearDown(tags.dispose);
      expect(tags.create('enemy'), isNull);
      expect(tags.library.value.contains('enemy'), isFalse);
      expect(tags.writeError, contains('Could not write'));
      expect(said, isNotEmpty);
      expect(leftovers(), isEmpty);
    });
  });

  group('the palettes', () {
    test('a broken file is left as it is; a change to it is taken back', () {
      const broken = '{"palettes": [ {"id": }';
      file('palettes.json').writeAsStringSync(broken);
      final said = <String>[];
      final colours = ProjectColours(
        path: file('palettes.json').path,
        onProblem: said.add,
      )..load();
      addTearDown(colours.dispose);

      expect(colours.isUnreadable, isTrue);
      expect(said, hasLength(1));
      colours.library.savePalette(
        const ColourPalette(id: 'p', name: 'Mine', colors: [Color(0xFF00FF00)]),
      );
      expect(colours.library.palettes, isEmpty, reason: 'taken back');
      expect(said, hasLength(2));
      expect(file('palettes.json').readAsStringSync(), broken);
    });

    test('palettes of the wrong type are reported, not thrown', () {
      file('palettes.json').writeAsStringSync('{"palettes": [{"id": 5}]}');
      final colours = ProjectColours(path: file('palettes.json').path);
      addTearDown(colours.dispose);
      expect(colours.load, returnsNormally);
      expect(colours.isUnreadable, isTrue);
    });

    test('a good file is written whole on each change', () {
      final colours = ProjectColours(path: file('palettes.json').path)..load();
      addTearDown(colours.dispose);
      colours.library.savePalette(
        const ColourPalette(id: 'p', name: 'Mine', colors: [Color(0xFF00FF00)]),
      );
      final saved = jsonDecode(file('palettes.json').readAsStringSync()) as Map;
      expect((saved['palettes'] as List).single['name'], 'Mine');
      expect(leftovers(), isEmpty);
    });
  });

  group("the editor's own store", () {
    test('takes the editor\'s keys out of the shared file, once', () async {
      final shared = FileStorage(root);
      await shared.write('editor.overlay.textScale', '1.2');
      await shared.write('editor.colour_picker.recents', '{"colours":[]}');
      await shared.write('save.slot1', 'the game\'s');
      final own = FileStorage(Directory('${root.path}/just_game_editor'));
      await own.write('editor.overlay.textScale', '1.4');

      var opened = 0;
      Future<JustStandardStorage> open() async {
        opened++;
        return FileStorage(root);
      }

      await moveEditorKeys(shared: open, own: own);
      expect(await own.read('editor.overlay.textScale'), '1.4', reason: 'own');
      expect(await own.read('editor.colour_picker.recents'), '{"colours":[]}');
      final left = await FileStorage(root).readAll();
      expect(left.keys, ['save.slot1'], reason: 'the game\'s keys stay');

      await moveEditorKeys(shared: open, own: own);
      expect(opened, 1, reason: 'never opened again');
    });

    test('settings and recent colours on one store keep each other', () async {
      final store = FileStorage(root);
      final settings = OverlaySettingsStore(Future.value(store));
      final colours = ProjectColours(
        path: file('palettes.json').path,
        storage: () async => store,
      )..load();
      addTearDown(colours.dispose);
      await settings.saveSettings(
        const OverlayUiSettings.defaults().copyWith(textScale: 1.3),
      );
      colours.library.addRecentColours(const [Color(0xFF123456)]);
      await pumpEventQueue();
      await settings.saveSettings(
        const OverlayUiSettings.defaults().copyWith(textScale: 1.1),
      );
      await pumpEventQueue();
      final onDisk = await FileStorage(root).readAll();
      expect(onDisk['editor.colour_picker.recents'], contains('${0xFF123456}'));
      expect(onDisk['editor.overlay.textScale'], '1.1');
    });

    test('a settings change writes only the settings that changed', () async {
      final store = _Counting(root);
      final settings = OverlaySettingsStore(Future.value(store));
      final loaded = await settings.loadSettings();
      await settings.saveSettings(loaded);
      final first = store.writes;
      expect(first, greaterThan(10), reason: 'an empty store: all of them');

      await settings.saveSettings(loaded.copyWith(textScale: 1.3));
      expect(store.writes - first, 1);
      await settings.saveSettings(loaded.copyWith(textScale: 1.3));
      expect(store.writes - first, 1, reason: 'nothing new');
      final decoded = await OverlaySettingsStore(
        Future.value(FileStorage(root)),
      ).loadSettings();
      expect(decoded.textScale, 1.3);
    });
  });
}

/// A store that counts its writes: each one rewrites the whole file.
class _Counting extends FileStorage {
  _Counting(super.directory);

  int writes = 0;

  @override
  Future<void> write(String key, String value) {
    writes++;
    return super.write(key, value);
  }
}
