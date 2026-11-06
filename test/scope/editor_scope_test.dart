// The scope stays whole around modules with bugs, and around workspaces
// that ask about unsaved work: a module that throws is left out and said in
// the log; a question from a window already gone is not taken.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

DesignerCommand _command(String id) =>
    DesignerCommand(id: id, label: id, run: (_) {});

DockDefinition _dock(String id) => DockDefinition(
  id: id,
  label: id,
  icon: const IconData(0xe000),
  build: (context, dock) => const SizedBox(),
);

WorkspaceDefinition _workspace(String id) => WorkspaceDefinition(
  id: id,
  label: id,
  icon: const IconData(0xe000),
  build: (context, workspace) => const SizedBox(),
);

class _Good extends EditorModule {
  @override
  String get id => 'good';
  @override
  String get name => 'Good';
  @override
  List<DesignerCommand> get commands => [_command('good.run')];
  @override
  List<DockDefinition> get docks => [_dock('good.dock')];
  @override
  List<WorkspaceDefinition> get workspaces => [
    _workspace('a'),
    _workspace('b'),
  ];
}

/// Throws from one getter, after giving others.
class _BrokenDocks extends EditorModule {
  @override
  String get id => 'broken';
  @override
  String get name => 'Broken';
  @override
  List<DesignerCommand> get commands => [_command('broken.run')];
  @override
  List<DockDefinition> get docks => throw StateError('a bug in docks');
}

class _BrokenSetup extends EditorModule {
  int registered = 0;
  @override
  String get id => 'setup';
  @override
  String get name => 'Setup';
  @override
  List<DockDefinition> get docks => [_dock('setup.dock')];
  @override
  void onRegister(EditorModuleContext context) {
    registered++;
    throw StateError('a bug in onRegister');
  }

  @override
  void onReassemble(EditorModuleContext context) =>
      throw StateError('a bug in onReassemble');
}

void main() {
  EditorScope scopeWith(List<EditorModule> modules) {
    final scope = EditorScope(world: World()..initialize(), modules: modules);
    addTearDown(scope.dispose);
    return scope;
  }

  List<String> errors(EditorScope scope) => [
    for (final e in scope.log.entries.value)
      if (e.level == DebuggerLogLevel.error) e.message,
  ];

  group('a module with a bug', () {
    test('is left out whole, and the editor starts without it', () {
      final scope = scopeWith([_BrokenDocks(), _Good()]);
      expect(scope.docks.map((d) => d.id), ['good.dock']);
      expect(scope.commands.byId('good.run'), isNotNull);
      expect(
        scope.commands.byId('broken.run'),
        isNull,
        reason: 'none of what it brings, not half',
      );
      expect(errors(scope).single, contains('"broken"'));
    });

    test('whose setup throws is still there; a hot reload finishes', () {
      final setup = _BrokenSetup();
      final scope = scopeWith([setup, _Good()]);
      expect(scope.docks.map((d) => d.id), containsAll(['setup.dock']));
      expect(setup.registered, 1);
      scope.reassemble();
      expect(setup.registered, 1, reason: 'set up once');
      expect(scope.commands.byId('good.run'), isNotNull);
      expect(errors(scope), hasLength(2));
    });
  });

  group('a workspace asking about unsaved work', () {
    test('a question from a window already gone is not taken', () async {
      final scope = scopeWith([_Good()]);
      expect(scope.openWorkspace('a'), isTrue);
      final first = scope.activeWorkspace.value;
      expect(scope.openWorkspace('b'), isTrue);
      var asked = 0;
      scope.setWorkspaceCloseGuard(() async {
        asked++;
        return false;
      }, of: first);
      expect(await scope.requestCloseWorkspace(), isTrue);
      expect(asked, 0);
    });

    test('one that throws keeps the window open, and says so', () async {
      final scope = scopeWith([_Good()]);
      scope.openWorkspace('a');
      final open = scope.activeWorkspace.value;
      scope.setWorkspaceCloseGuard(() async => throw StateError('no dialog'));
      expect(await scope.requestCloseWorkspace(), isFalse);
      scope.openWorkspace('b');
      await pumpEventQueue();
      expect(scope.activeWorkspace.value, same(open));
      expect(errors(scope), hasLength(2));
    });

    test('a scope gone while it asked is left alone', () async {
      final scope = EditorScope(
        world: World()..initialize(),
        modules: [_Good()],
      );
      scope.openWorkspace('a');
      scope.setWorkspaceCloseGuard(() async {
        await pumpEventQueue();
        return true;
      });
      scope.openWorkspace('b');
      scope.dispose();
      await pumpEventQueue(times: 40);
    });
  });
}
