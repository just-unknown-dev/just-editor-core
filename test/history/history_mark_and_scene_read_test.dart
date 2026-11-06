// A history can be put back as it was at a mark (what a play-test's Stop
// does), and a scene file that is there but cannot be read is an error —
// not a missing scene that would open empty and be saved over it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  group('EditorHistory.mark and restore', () {
    late EditorHistory history;
    final log = <String>[];

    EditorCommand step(String name) => CallbackCommand(
      label: name,
      onRedo: () => log.add('do $name'),
      onUndo: () => log.add('undo $name'),
    );

    setUp(() {
      history = EditorHistory();
      log.clear();
    });
    tearDown(() => history.dispose());

    test('what was done after the mark is dropped, running nothing', () {
      history
        ..push(step('a'))
        ..push(step('b'))
        ..undo();
      final mark = history.mark();
      history.push(step('c'));
      log.clear();

      history.restore(mark);

      expect(log, isEmpty);
      expect(history.nextUndoLabel.value, 'a');
      expect(history.nextRedoLabel.value, 'b');
      expect(history.undoDepth, 1);
      expect(history.redoDepth, 1);
    });

    test('what was undone after the mark is a step again', () {
      history.push(step('a'));
      final mark = history.mark();
      history.undo();
      history.restore(mark);
      expect(history.canUndo.value, isTrue);
      expect(history.canRedo.value, isFalse);
      expect(history.nextUndoLabel.value, 'a');
    });

    test('the next edit after a restore is a step of its own', () {
      final merging = _Merging('drag');
      history.push(merging);
      final mark = history.mark();
      history.restore(mark);
      history.push(_Merging('drag'));
      expect(history.undoDepth, 2);
    });
  });

  group('SceneStore reading', () {
    late Directory dir;
    late SceneStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('scene_read');
      store = SceneStore(
        codec: SceneCodec(ComponentDefinitionRegistry()),
        root: dir.path,
      );
    });
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may hold it a moment longer.
      }
    });

    void write(String name, String text) =>
        File('${dir.path}/$name.scene.json').writeAsStringSync(text);

    test('a missing scene is null', () async {
      expect(await store.loadRawSidecar('nope'), isNull);
    });

    test(
      'a scene that is not valid JSON is an error naming the file',
      () async {
        write('broken', '{"entities": [],}');
        await expectLater(
          store.loadRawSidecar('broken'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('broken.scene.json'),
            ),
          ),
        );
        expect(await store.loadFromSidecar('broken'), isNull);
      },
    );

    test('nor is JSON that is not an object a scene', () async {
      write('list', '[]');
      await expectLater(
        store.loadRawSidecar('list'),
        throwsA(isA<FormatException>()),
      );
      expect(store.readRawSync('list'), isNull);
    });
  });
}

class _Merging extends EditorCommand {
  _Merging(this.label);

  @override
  final String label;

  @override
  void redo() {}

  @override
  void undo() {}

  @override
  bool mergeWith(EditorCommand next) => next is _Merging;
}
