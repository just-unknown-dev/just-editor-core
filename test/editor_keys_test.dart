// The primary modifier is Cmd on macOS and Ctrl everywhere else: what a
// binding's `control` means, what a chord is shown as, and what a Delete
// binding answers. Settings store `Ctrl+` on every OS.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  void on(TargetPlatform platform) =>
      debugDefaultTargetPlatformOverride = platform;

  const undo = KeyBinding(
    LogicalKeyboardKey.keyZ,
    'editor.undo',
    control: true,
  );
  const redo = KeyBinding(
    LogicalKeyboardKey.keyZ,
    'editor.redo',
    control: true,
    shift: true,
  );
  const turn = KeyBinding(LogicalKeyboardKey.keyZ, 'designer.turn');
  const delete = KeyBinding(LogicalKeyboardKey.delete, 'editor.delete');

  group('chords as shown and as saved', () {
    test('Cmd on a Mac, Ctrl elsewhere; saved as Ctrl on both', () {
      on(TargetPlatform.macOS);
      expect(undo.shortcut, 'Cmd+Z');
      expect(redo.shortcut, 'Cmd+Shift+Z');
      expect(undo.savedChord, 'Ctrl+Z');
      expect(redo.savedChord, 'Ctrl+Shift+Z');
      expect(EditorKeys.primaryLabel, 'Cmd');
      expect(EditorKeys.withPrimary('click'), 'Cmd+click');

      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        on(platform);
        expect(undo.shortcut, 'Ctrl+Z');
        expect(undo.savedChord, 'Ctrl+Z');
        expect(EditorKeys.withPrimary('S'), 'Ctrl+S');
      }
    });

    test('Cmd+, Ctrl+ and ⌘ all read as the primary modifier', () {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
        on(platform);
        final ctrl = KeyBinding.parse('Ctrl+S', 'editor.save')!;
        for (final text in ['Cmd+S', '⌘S', '⌘+S']) {
          final other = KeyBinding.parse(text, 'editor.save')!;
          expect(
            (other.key, other.control, other.shift, other.alt),
            (ctrl.key, ctrl.control, ctrl.shift, ctrl.alt),
            reason: text,
          );
        }
        expect(ctrl.control, isTrue);
        expect(KeyBinding.parse('Cmd+Shift+Z', 'x')!.shift, isTrue);
      }
    });

    test('a chord saved on a Mac reads back as the same keys elsewhere', () {
      on(TargetPlatform.macOS);
      final saved = redo.savedChord;
      on(TargetPlatform.linux);
      final back = KeyBinding.parse(saved, redo.commandId)!;
      expect(
        (back.key, back.control, back.shift, back.alt),
        (redo.key, true, true, false),
      );
      expect(back.shortcut, 'Ctrl+Shift+Z');
    });
  });

  group('matching', () {
    test('control is the primary modifier, and the other one stops all', () {
      const primary = ModifierKeys(control: true);
      const other = ModifierKeys(other: true);
      expect(undo.matches(LogicalKeyboardKey.keyZ, primary), isTrue);
      expect(turn.matches(LogicalKeyboardKey.keyZ, primary), isFalse);
      expect(
        turn.matches(LogicalKeyboardKey.keyZ, const ModifierKeys()),
        isTrue,
      );
      // Ctrl on a Mac (the Windows key elsewhere): neither the plain Z nor
      // the undo.
      expect(turn.matches(LogicalKeyboardKey.keyZ, other), isFalse);
      expect(
        undo.matches(
          LogicalKeyboardKey.keyZ,
          const ModifierKeys(control: true, other: true),
        ),
        isFalse,
      );
    });

    test('a Delete binding answers Backspace on a Mac only', () {
      on(TargetPlatform.macOS);
      expect(
        delete.matches(LogicalKeyboardKey.backspace, const ModifierKeys()),
        isTrue,
      );
      expect(EditorKeys.isDeleteKey(LogicalKeyboardKey.backspace), isTrue);
      expect(EditorKeys.deleteKeys, contains(LogicalKeyboardKey.backspace));

      on(TargetPlatform.windows);
      expect(
        delete.matches(LogicalKeyboardKey.backspace, const ModifierKeys()),
        isFalse,
      );
      expect(
        delete.matches(LogicalKeyboardKey.delete, const ModifierKeys()),
        isTrue,
      );
      expect(EditorKeys.deleteKeys, {LogicalKeyboardKey.delete});
    });

    test('on a Mac, Backspace bound elsewhere is Delete\'s chord', () {
      final registry = CommandRegistry()
        ..register(
          DesignerCommand(id: 'editor.delete', label: 'Delete', run: (_) {}),
        )
        ..bind(delete);
      const backspace = KeyBinding(LogicalKeyboardKey.backspace, 'other');
      on(TargetPlatform.macOS);
      expect(registry.conflictWith(backspace)?.id, 'editor.delete');
      on(TargetPlatform.windows);
      expect(registry.conflictWith(backspace), isNull);
    });

    test('shortcutOf shows the first binding, or nothing', () {
      on(TargetPlatform.macOS);
      final registry = CommandRegistry()..bindAll([undo, redo]);
      expect(registry.shortcutOf('editor.redo'), 'Cmd+Shift+Z');
      expect(registry.shortcutOf('nothing'), isNull);
    });

    test('a primary activator is meta on a Mac, control elsewhere', () {
      on(TargetPlatform.macOS);
      final mac = EditorKeys.primary(LogicalKeyboardKey.keyS, shift: true);
      expect((mac.meta, mac.control, mac.shift), (true, false, true));
      on(TargetPlatform.linux);
      final linux = EditorKeys.primary(LogicalKeyboardKey.keyS);
      expect((linux.meta, linux.control), (false, true));
    });
  });

  group('reading the keyboard', () {
    testWidgets('on a Mac Cmd is the primary modifier and Ctrl is not', (
      tester,
    ) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      var mods = ModifierKeys.fromHardwareKeyboard();
      expect((mods.control, mods.other), (true, false));
      expect(EditorKeys.primaryPressed, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      mods = ModifierKeys.fromHardwareKeyboard();
      expect((mods.control, mods.other), (false, true));
      expect(EditorKeys.primaryPressed, isFalse);
      expect(EditorKeys.otherPressed, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'elsewhere Ctrl is, and the Windows or Super key is not',
      (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        var mods = ModifierKeys.fromHardwareKeyboard();
        expect((mods.control, mods.other), (true, false));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        mods = ModifierKeys.fromHardwareKeyboard();
        expect((mods.control, mods.other), (false, true));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  });

  group('a workspace header', () {
    Future<void> pumpHeader(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceHeader(
            icon: Icons.texture,
            title: 'Material',
            dirty: true,
            onSave: () {},
            onUndo: () {},
            onRedo: () {},
          ),
        ),
      ),
    );

    testWidgets('says Cmd on a Mac', (tester) async {
      await pumpHeader(tester);
      expect(find.byTooltip('Save  (Cmd+S)'), findsOneWidget);
      expect(find.byTooltip('Undo  (Cmd+Z)'), findsOneWidget);
      expect(find.byTooltip('Redo  (Cmd+Y)'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'and Ctrl elsewhere',
      (tester) async {
        await pumpHeader(tester);
        expect(find.byTooltip('Save  (Ctrl+S)'), findsOneWidget);
        expect(find.byTooltip('Undo  (Ctrl+Z)'), findsOneWidget);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  });

  test('the editor scope dispatches the primary chord', () {
    final scope = EditorScope(world: World()..initialize());
    addTearDown(scope.dispose);
    var undone = 0, turned = 0;
    final registry = scope.commands
      ..register(
        DesignerCommand(
          id: 'editor.undo',
          label: 'Undo',
          scope: CommandScope.editor,
          run: (_) => undone++,
        ),
        override: true,
      )
      ..register(
        DesignerCommand(
          id: 'designer.turn',
          label: 'Turn',
          scope: CommandScope.editor,
          run: (_) => turned++,
        ),
        override: true,
      )
      ..bindAll([turn, undo]);
    bool press(ModifierKeys mods) => registry.dispatch(
      LogicalKeyboardKey.keyZ,
      CommandContext(scope: scope, modifiers: mods),
      scopes: const {CommandScope.editor},
    );
    expect(press(const ModifierKeys(control: true)), isTrue);
    expect((undone, turned), (1, 0));
    expect(press(const ModifierKeys(other: true)), isFalse);
    expect((undone, turned), (1, 0));
    expect(press(const ModifierKeys()), isTrue);
    expect((undone, turned), (1, 1));
  });
}
