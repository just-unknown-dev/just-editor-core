import 'package:flutter/services.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../scope/editor_scope.dart';
import '../designer/designer_session.dart';
import 'editor_keys.dart';
import 'modifier_keys.dart';

/// When a command may run.
enum CommandScope {
  /// Needs an open designer session and authoring; the session dispatches.
  designer,

  /// Runs against the editor whenever it is open, after the designer has had
  /// its chance and never while typing in a text field.
  editor,

  /// Runs whenever the editor is open, even while typing (Save).
  always,
}

/// What a command is handed when it runs.
class CommandContext {
  const CommandContext({
    required this.scope,
    required this.modifiers,
    this.session,
    this.host,
    this.gridSize = 32,
  });

  /// The editor the command runs in: its scene state, registries and
  /// services.
  final EditorScope scope;

  /// The modifier keys held when the command was dispatched.
  final ModifierKeys modifiers;

  /// The open designer session, if any.
  final DesignerSession? session;

  /// What dispatched the command — the editor host — or null when a bare
  /// designer session did.
  final Object? host;

  /// The authoring grid, for commands that move by a cell.
  final double gridSize;
}

/// Something the editor can do on request: from a key, a menu, a module's
/// own button. Identified by id so a binding can name it.
class DesignerCommand {
  const DesignerCommand({
    required this.id,
    required this.label,
    required this.run,
    this.scope = CommandScope.designer,
    this.isEnabled,
    this.repeats = false,
    this.dimensions = jge.Dimensions.both,
  });

  /// Which scene modes it runs in. The 2-D layout commands — nudge, flip,
  /// quarter turns, align — say [jge.Dimensions.twoD].
  final jge.Dimensions dimensions;

  /// Stable id, namespaced: `'designer.nudgeLeft'`, `'mygame.spawnWave'`.
  final String id;

  /// Shown wherever commands are listed.
  final String label;

  /// When it may run: with a designer session open, in the editor, or even
  /// while typing. [CommandScope.designer] by default.
  final CommandScope scope;

  /// Whether the command can run right now; null means always.
  final bool Function(CommandContext context)? isEnabled;

  /// Whether a held key keeps firing it (nudging does; flipping must not).
  final bool repeats;

  /// Does the command. Called only when [enabledIn] allows it.
  final void Function(CommandContext context) run;

  /// Whether it may run in [context]: in the scene's mode, as [isEnabled]
  /// says, and — for a [CommandScope.designer] command — with a designer
  /// session open, which is what such a command acts on. A console or a
  /// menu can reach one with the designer shut.
  bool enabledIn(CommandContext context) =>
      (scope != CommandScope.designer || context.session != null) &&
      dimensions.allows(context.scope.sceneState.editingMode) &&
      (isEnabled?.call(context) ?? true);
}

/// A key chord that runs a command.
///
/// Matched on the exact modifier set, so `Shift+Z` and `Z` are different
/// bindings — which is what lets one key mean two things.
///
/// [control] is the platform's primary modifier: Ctrl, and Cmd on macOS
/// (see [EditorKeys]). One binding serves every platform, and a Delete
/// binding also answers the Mac's Backspace.
class KeyBinding {
  const KeyBinding(
    this.key,
    this.commandId, {
    this.control = false,
    this.shift = false,
    this.alt = false,
  });

  /// The key pressed with the modifiers.
  final LogicalKeyboardKey key;

  /// The [DesignerCommand.id] of the command it runs.
  final String commandId;

  /// The primary modifier: Ctrl, Cmd on macOS.
  final bool control;

  /// Whether Shift is part of the chord.
  final bool shift;

  /// Whether Alt (Option on macOS) is part of the chord.
  final bool alt;

  /// Whether [pressed] with [mods] is this chord: the same modifiers, and
  /// nothing held the editor binds nothing to ([ModifierKeys.other]).
  bool matches(LogicalKeyboardKey pressed, ModifierKeys mods) =>
      _isKey(pressed) &&
      mods.control == control &&
      mods.shift == shift &&
      mods.alt == alt &&
      !mods.other;

  /// [pressed] is [key] — or, for a Delete binding, a key that deletes.
  bool _isKey(LogicalKeyboardKey pressed) =>
      pressed == key ||
      key == LogicalKeyboardKey.delete && EditorKeys.isDeleteKey(pressed);

  /// The keys as a person would say them: `Ctrl+Shift+Z`, `F5` — and
  /// `Cmd+Shift+Z` on macOS. What a tooltip shows beside the command it
  /// triggers. A settings file stores [savedChord] instead.
  String get shortcut => chord(key, control: control, shift: shift, alt: alt);

  /// The chord as settings files store it: always `Ctrl+` for the primary
  /// modifier, so a saved file reads the same on every OS. [parse] reads it
  /// back on any platform.
  String get savedChord =>
      _write('Ctrl', key, control: control, shift: shift, alt: alt);

  /// [key] with the modifiers, as [shortcut] writes a chord: the primary
  /// modifier is `Ctrl` or, on macOS, `Cmd`.
  static String chord(
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
  }) => _write(
    EditorKeys.primaryLabel,
    key,
    control: control,
    shift: shift,
    alt: alt,
  );

  static String _write(
    String primary,
    LogicalKeyboardKey key, {
    required bool control,
    required bool shift,
    required bool alt,
  }) =>
      '${control ? '$primary+' : ''}${shift ? 'Shift+' : ''}'
      '${alt ? 'Alt+' : ''}${nameOf(key)}';

  /// What [key] is called in a chord.
  static String nameOf(LogicalKeyboardKey key) =>
      key.keyLabel.isEmpty ? (key.debugName ?? '${key.keyId}') : key.keyLabel;

  /// Whether [key] is one a chord is made with rather than of.
  static bool isModifier(LogicalKeyboardKey key) => _modifiers.contains(key);

  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  /// The binding [text] names — a chord as [shortcut] or [savedChord]
  /// writes it, `Ctrl+Shift+Z` — for [commandId]; null when it names no
  /// key. `Ctrl+`, `Cmd+` and `⌘` all name the primary modifier, on every
  /// platform, so a file saved on one OS reads the same on another.
  static KeyBinding? parse(String text, String commandId) {
    var rest = text.trim();
    var control = false, shift = false, alt = false;
    while (true) {
      final primary = _primaryPrefixes.firstWhere(
        (p) => rest.length > p.length && rest.startsWith(p),
        orElse: () => '',
      );
      if (primary.isNotEmpty) {
        control = true;
        rest = rest.substring(primary.length);
      } else if (rest.length > 6 && rest.startsWith('Shift+')) {
        shift = true;
        rest = rest.substring(6);
      } else if (rest.length > 4 && rest.startsWith('Alt+')) {
        alt = true;
        rest = rest.substring(4);
      } else {
        break;
      }
    }
    final key = _keyNamed(rest);
    if (key == null) return null;
    return KeyBinding(key, commandId, control: control, shift: shift, alt: alt);
  }

  /// What [parse] reads as the primary modifier (`⌘+` before `⌘`).
  static const List<String> _primaryPrefixes = ['Ctrl+', 'Cmd+', '⌘+', '⌘'];

  static Map<String, LogicalKeyboardKey>? _byName;

  /// The key [nameOf] calls [name]. Where two share a name, the one with
  /// the lower id: the key on the main keyboard, not a pad's.
  static LogicalKeyboardKey? _keyNamed(String name) {
    final byName = _byName ??= () {
      final map = <String, LogicalKeyboardKey>{};
      for (final key in LogicalKeyboardKey.knownLogicalKeys) {
        final named = nameOf(key).toLowerCase();
        final had = map[named];
        if (had == null || key.keyId < had.keyId) map[named] = key;
      }
      return map;
    }();
    return byName[name.toLowerCase()];
  }

  @override
  String toString() => '$shortcut → $commandId';
}

/// The commands one editor knows and the keys that run them.
///
/// Bindings are resolved last-registered-first, so a module's binding for a
/// chord replaces a built-in's without the built-in having to know.
class CommandRegistry {
  CommandRegistry();

  final Map<String, DesignerCommand> _commands = {};
  final List<KeyBinding> _bindings = [];

  /// The bindings as built — the built-ins and the modules' — before any
  /// were changed in the settings.
  List<KeyBinding> _built = const [];
  bool _hasBuilt = false;

  /// Every registered command, in the order first registered; read-only.
  List<DesignerCommand> get all => List.unmodifiable(_commands.values);

  /// Every binding in the order added (later ones win a shared chord), as
  /// changed in the settings; read-only.
  List<KeyBinding> get bindings => List.unmodifiable(_bindings);

  /// The command registered under [id], or null.
  DesignerCommand? byId(String id) => _commands[id];

  /// Registers [command]; a second registration of the same id replaces the
  /// first only with [override].
  void register(DesignerCommand command, {bool override = false}) {
    if (!override && _commands.containsKey(command.id)) {
      throw StateError(
        'Command "${command.id}" is already registered; pass override: true',
      );
    }
    _commands[command.id] = command;
  }

  /// Registers each of [commands] in turn, as [register] does.
  void registerAll(
    Iterable<DesignerCommand> commands, {
    bool override = false,
  }) {
    for (final c in commands) {
      register(c, override: override);
    }
  }

  /// Adds [binding]. It takes precedence over any earlier binding of the
  /// same chord.
  void bind(KeyBinding binding) => _bindings.add(binding);

  /// Adds each of [bindings] in order, as [bind] does.
  void bindAll(Iterable<KeyBinding> bindings) => _bindings.addAll(bindings);

  /// Removes every binding of [commandId].
  void unbind(String commandId) =>
      _bindings.removeWhere((b) => b.commandId == commandId);

  /// The bindings that run [commandId], for tooltips.
  List<KeyBinding> bindingsFor(String commandId) => [
    for (final b in _bindings)
      if (b.commandId == commandId) b,
  ];

  /// The keys that run [commandId] as a tooltip shows them — its first
  /// binding's [KeyBinding.shortcut], `Cmd+D` on a Mac — or null when no
  /// key does. It follows the bindings as changed in the settings.
  String? shortcutOf(String commandId) {
    for (final b in _bindings) {
      if (b.commandId == commandId) return b.shortcut;
    }
    return null;
  }

  /// The command bound to [key] with [mods], or null.
  DesignerCommand? resolve(LogicalKeyboardKey key, ModifierKeys mods) {
    for (final b in _bindings.reversed) {
      if (b.matches(key, mods)) return _commands[b.commandId];
    }
    return null;
  }

  /// Runs the command bound to [key], if it is in one of [scopes], enabled,
  /// and (on a repeat) repeatable. Returns whether anything ran.
  bool dispatch(
    LogicalKeyboardKey key,
    CommandContext context, {
    required Set<CommandScope> scopes,
    bool isRepeat = false,
  }) {
    // The newest binding of the chord whose command belongs to [scopes] and
    // the scene's mode owns it: one chord can mean a designer command, an
    // editor command and a 3-D view command, each where it applies.
    final mode = context.scope.sceneState.editingMode;
    for (final b in _bindings.reversed) {
      if (!b.matches(key, context.modifiers)) continue;
      final command = _commands[b.commandId];
      if (command == null || !scopes.contains(command.scope)) continue;
      if (!command.dimensions.allows(mode)) continue;
      if (isRepeat && !command.repeats) return false;
      if (!command.enabledIn(context)) return false;
      command.run(context);
      return true;
    }
    return false;
  }

  /// Remembers the bindings as they are now as the ones built: what
  /// [applyShortcuts] lays changes over, and what a reset goes back to.
  void markBuilt() {
    _built = List.unmodifiable(_bindings);
    _hasBuilt = true;
  }

  /// The bindings [commandId] had as built, before any change.
  List<KeyBinding> builtBindingsFor(String commandId) => [
    for (final b in _hasBuilt ? _built : _bindings)
      if (b.commandId == commandId) b,
  ];

  /// Puts back the bindings as built, then lays [changed] over them: each
  /// command named runs from the chords listed — `Ctrl+Shift+S` — and from
  /// nothing else. A chord that names no key is skipped.
  void applyShortcuts(Map<String, List<String>> changed) {
    if (!_hasBuilt) markBuilt();
    _bindings
      ..clear()
      ..addAll(_built);
    for (final e in changed.entries) {
      unbind(e.key);
      for (final chord in e.value) {
        final binding = KeyBinding.parse(chord, e.key);
        if (binding != null) bind(binding);
      }
    }
  }

  /// The command [binding]'s chord runs now, other than [binding]'s own —
  /// what binding it would take the chord from. A chord that sets off a
  /// binding counts, so on macOS Backspace is Delete's.
  DesignerCommand? conflictWith(KeyBinding binding) {
    final mods = ModifierKeys(
      control: binding.control,
      shift: binding.shift,
      alt: binding.alt,
    );
    for (final b in _bindings.reversed) {
      if (b.commandId == binding.commandId) continue;
      if (b.matches(binding.key, mods)) return _commands[b.commandId];
    }
    return null;
  }

  /// Forgets every command and binding, and the bindings as built; the
  /// scope calls it before it registers the modules again.
  void clear() {
    _commands.clear();
    _bindings.clear();
    _built = const [];
    _hasBuilt = false;
  }
}
