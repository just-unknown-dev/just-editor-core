// A value previewed live — a colour picker's, while it is open — is shown
// without being recorded, holds an autosave off, is put back before a save
// or a play-test reads the scene, and leaves the next edit a step of its
// own.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

/// A step that merges with any next one of its kind.
class _Merging extends EditorCommand {
  @override
  String get label => 'Merging';
  @override
  void redo() {}
  @override
  void undo() {}
  @override
  bool mergeWith(EditorCommand next) => next is _Merging;
}

void main() {
  late EditorScope scope;

  setUp(() {
    scope = EditorScope(
      world: World()..initialize(),
      settingsStore: MemorySettingsStore(),
    );
  });
  tearDown(() => scope.dispose());

  test('shows unrecorded, holds an autosave off, and a save puts it '
      'back', () {
    var value = 1;
    final preview = LivePreview(
      read: () => value,
      write: (v) => value = v! as int,
      scope: scope,
    );
    preview.show(2);
    expect(value, 2);
    expect(preview.isShowing, isTrue);
    expect(scope.isAuthoredStateHeld, isTrue);
    expect(scope.history.canUndo.value, isFalse, reason: 'not recorded');

    scope.restoreAuthoredState();
    expect(value, 1);
    expect(preview.isShowing, isFalse);
    expect(scope.isAuthoredStateHeld, isFalse);

    preview
      ..show(3)
      ..show(4);
    preview.restore();
    expect(value, 1, reason: 'the value before the first show');
    expect(scope.authoredStateGuards, isEmpty);
    expect(scope.isAuthoredStateHeld, isFalse);
  });

  test('what is kept after a preview is a step of its own', () {
    final preview = LivePreview(read: () => 0, write: (_) {}, scope: scope);
    scope.history.push(_Merging());
    preview
      ..show(1)
      ..restore();
    scope.history.push(_Merging());
    expect(scope.history.undoEntries, hasLength(2));
  });

  test('without a scope, it tells nobody, and still puts back', () {
    var value = 'a';
    final history = EditorHistory();
    addTearDown(history.dispose);
    final preview = LivePreview(
      read: () => value,
      write: (v) => value = v! as String,
      history: history,
    );
    history.push(_Merging());
    preview.show('b');
    expect(value, 'b');
    preview.restore();
    expect(value, 'a');
    history.push(_Merging());
    expect(history.undoDepth, 2, reason: 'its own history told');
  });
}
