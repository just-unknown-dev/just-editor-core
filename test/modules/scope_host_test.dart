// What only the editor hosting a scope does with it. A built-in asked for
// again, when one of its id is there already, changes nothing — and the
// one made for the asking is let go of, not left holding what it opened.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

class _BuiltIn extends EditorModule {
  _BuiltIn(this.made);

  /// Every one made so far, this one among them.
  final List<_BuiltIn> made;
  bool disposed = false;

  @override
  String get id => 'test.builtIn';

  @override
  String get name => 'Built in';

  @override
  void dispose() => disposed = true;
}

void main() {
  test('a built-in added twice keeps the first, and lets go of the '
      'second', () {
    final scope = EditorScope(
      world: World()..initialize(),
      settingsStore: MemorySettingsStore(),
    );
    addTearDown(scope.dispose);
    final made = <_BuiltIn>[];
    EditorModule make(EditorScope _) {
      final module = _BuiltIn(made);
      made.add(module);
      return module;
    }

    scope
      ..addBuiltIn(make)
      ..addBuiltIn(make);
    expect(made, hasLength(2));
    expect(scope.modules.byId('test.builtIn'), same(made.first));
    expect(made.first.disposed, isFalse);
    expect(made.last.disposed, isTrue, reason: 'made, and not used');
  });

  test('the same module handed back again is not disposed', () {
    final scope = EditorScope(
      world: World()..initialize(),
      settingsStore: MemorySettingsStore(),
    );
    addTearDown(scope.dispose);
    final module = _BuiltIn([]);
    scope
      ..addBuiltIn((_) => module)
      ..addBuiltIn((_) => module);
    expect(module.disposed, isFalse);
    expect(scope.modules.byId('test.builtIn'), same(module));
  });
}
