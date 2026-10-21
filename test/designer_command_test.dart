// A designer command acts on an open designer session: reached from a
// console or a menu with the designer shut, it is not available rather
// than run against nothing.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

/// Stands in for an open session: these tests never call into it.
class _Session implements DesignerSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late EditorScope scope;

  setUp(() => scope = EditorScope(world: World()..initialize()));
  tearDown(() => scope.dispose());

  test('a designer command needs a designer session to run', () {
    var ran = 0;
    final designer = DesignerCommand(id: 'd', label: 'D', run: (_) => ran++);
    final editor = DesignerCommand(
      id: 'e',
      label: 'E',
      scope: CommandScope.editor,
      run: (_) {},
    );
    final shut = CommandContext(scope: scope, modifiers: const ModifierKeys());
    final open = CommandContext(
      scope: scope,
      modifiers: const ModifierKeys(),
      session: _Session(),
    );
    expect(designer.enabledIn(shut), isFalse);
    expect(designer.enabledIn(open), isTrue);
    expect(editor.enabledIn(shut), isTrue, reason: 'not a designer command');

    final registry = CommandRegistry()
      ..register(designer)
      ..bind(const KeyBinding(LogicalKeyboardKey.keyQ, 'd'));
    expect(
      registry.dispatch(
        LogicalKeyboardKey.keyQ,
        shut,
        scopes: const {CommandScope.designer},
      ),
      isFalse,
    );
    expect(ran, 0);
  });
}
