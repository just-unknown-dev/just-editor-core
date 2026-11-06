// A designer command acts on an open designer session: reached from a
// console or a menu with the designer shut, it is not available rather
// than run against nothing.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

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
      availability: CommandAvailability.editor,
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
        availabilities: const {CommandAvailability.designer},
      ),
      isFalse,
    );
    expect(ran, 0);
  });

  group('a key saved in the settings', () {
    test('reads back as the key it was, for every key there is', () {
      final lost = <String>[];
      for (final key in LogicalKeyboardKey.knownLogicalKeys) {
        if (KeyBinding.isModifier(key)) continue;
        for (final binding in [
          KeyBinding(key, 'x'),
          KeyBinding(key, 'x', control: true, shift: true),
        ]) {
          final again = KeyBinding.parse(binding.savedChord, 'x');
          // Two keys of one name (a pad's and the main keyboard's) are one
          // in a file: the same chord back is what counts.
          if (again?.savedChord != binding.savedChord) {
            lost.add('"${binding.savedChord}" -> ${again?.savedChord}');
          }
        }
      }
      expect(lost, isEmpty);
    });

    test('Space is saved by its name, and read back', () {
      const space = KeyBinding(LogicalKeyboardKey.space, 'x', control: true);
      expect(space.savedChord, 'Ctrl+Space');
      expect(
        KeyBinding.parse('Ctrl+Space', 'x')?.key,
        LogicalKeyboardKey.space,
      );
    });

    test('Space as an older editor saved it, a blank, is read as Space', () {
      for (final (saved, control, shift) in [
        (' ', false, false),
        ('Ctrl+ ', true, false),
        ('Ctrl+Shift+ ', true, true),
      ]) {
        final binding = KeyBinding.parse(saved, 'x');
        expect(binding?.key, LogicalKeyboardKey.space, reason: '"$saved"');
        expect(binding?.control, control, reason: '"$saved"');
        expect(binding?.shift, shift, reason: '"$saved"');
      }
      expect(KeyBinding.parse('', 'x'), isNull);
      expect(KeyBinding.parse('Ctrl+', 'x'), isNull);
      expect(
        KeyBinding.parse('Ctrl++', 'x')?.key,
        LogicalKeyboardKey.add,
        reason: 'the plus key is still itself',
      );
    });

    test('a command none of whose saved keys can be read keeps its own', () {
      final registry = CommandRegistry()
        ..register(DesignerCommand(id: 'frame', label: 'Frame', run: (_) {}))
        ..register(DesignerCommand(id: 'other', label: 'Other', run: (_) {}))
        ..bind(const KeyBinding(LogicalKeyboardKey.keyF, 'frame'))
        ..bind(const KeyBinding(LogicalKeyboardKey.keyO, 'other'))
        ..markBuilt();

      final unread = registry.applyShortcuts({
        'frame': ['Hyper+Nothing'],
        'other': ['Ctrl+O', 'Nonsense'],
      });
      expect(unread, {
        'frame': ['Hyper+Nothing'],
        'other': ['Nonsense'],
      });
      expect(registry.shortcutOf('frame'), 'F', reason: 'kept as built');
      expect(
        [for (final b in registry.bindingsFor('other')) b.savedChord],
        ['Ctrl+O'],
        reason: 'what could be read, and nothing else',
      );

      // Bound to nothing on purpose: no key at all.
      expect(registry.applyShortcuts({'frame': []}), isEmpty);
      expect(registry.shortcutOf('frame'), isNull);

      // Space, as saved before: bound again.
      expect(
        registry.applyShortcuts({
          'frame': [' '],
        }),
        isEmpty,
      );
      expect(
        registry.bindingsFor('frame').single.key,
        LogicalKeyboardKey.space,
      );
    });

    test('what the settings name that is no key is told in the log', () {
      final logged = EditorScope(
        world: World()..initialize(),
        settingsStore: MemorySettingsStore(),
      );
      addTearDown(logged.dispose);
      logged.prefs.settings.value = const OverlayUiSettings.defaults().copyWith(
        shortcuts: {
          'frame': ['Hyper+Nothing'],
        },
      );
      // Made now, it takes the settings as they are.
      expect(logged.commands.bindingsFor('frame'), isEmpty);
      expect(
        [
          for (final e in logged.log.entries.value)
            if (e.category == 'shortcuts') e.message,
        ],
        [contains('"Hyper+Nothing"')],
      );
    });
  });
}
