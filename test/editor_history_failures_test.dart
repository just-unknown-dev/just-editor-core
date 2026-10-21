// What the history does when a step throws, when old steps are trimmed
// away, and when it is cleared: the buttons stay true and "unsaved" never
// reads clean while the saved state cannot be reached.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

class _Step extends EditorCommand {
  _Step(this.label, {this.throwsOnUndo = false});

  @override
  final String label;
  final bool throwsOnUndo;

  @override
  void redo() {}

  @override
  void undo() {
    if (throwsOnUndo) throw StateError('broken undo');
  }
}

void main() {
  test('a step that throws is dropped, and the stack is published', () {
    final history = EditorHistory();
    addTearDown(history.dispose);
    final reported = <FlutterErrorDetails>[];
    final was = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = was);

    history
      ..push(_Step('ok'))
      ..push(_Step('broken', throwsOnUndo: true));
    history.undo();

    expect(reported, hasLength(1));
    expect(history.undoDepth, 1, reason: 'the broken step is gone');
    expect(history.redoDepth, 0);
    expect(history.nextUndoLabel.value, 'ok', reason: 'labels published');
    expect(history.canRedo.value, isFalse);
    expect(history.dirty.value, isTrue);
  });

  test('a save at the bottom that was trimmed away never reads clean', () {
    final history = EditorHistory(capacity: 3);
    addTearDown(history.dispose);
    history.markSaved(); // saved with nothing done
    for (var i = 0; i < 4; i++) {
      history.push(_Step('edit $i'));
    }
    expect(history.undoDepth, 3, reason: 'the first edit was trimmed');
    history
      ..undo()
      ..undo()
      ..undo();
    expect(history.undoDepth, 0);
    expect(
      history.dirty.value,
      isTrue,
      reason: 'the first edit is still applied; nothing undoes it',
    );
    history.markSaved();
    expect(history.dirty.value, isFalse);
  });

  test('a save on a step that was trimmed away never reads clean', () {
    final history = EditorHistory(capacity: 2);
    addTearDown(history.dispose);
    history.push(_Step('a'));
    history.markSaved();
    history
      ..push(_Step('b'))
      ..push(_Step('c'));
    history
      ..undo()
      ..undo();
    expect(history.dirty.value, isTrue);
  });

  test('clear starts again from clean', () {
    final history = EditorHistory();
    addTearDown(history.dispose);
    history.push(_Step('a'));
    history.markSaved();
    history.push(_Step('b'));
    history.clear();
    expect(history.dirty.value, isFalse);
    history.push(_Step('c'));
    expect(history.dirty.value, isTrue);
    history.undo();
    expect(history.dirty.value, isFalse);
  });
}
