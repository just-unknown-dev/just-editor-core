/// The project's collision layers, as the editor keeps them.
library;

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_signals/just_signals.dart';

import '../../io.dart';
import '../services/project_files.dart';

/// The project's collision layers — their names, colours, descriptions and
/// which collide — from the project's layer file
/// ([jge.PhysicsLayers.defaultPath]).
///
/// Every change writes the file and goes straight into the engine the
/// editor runs, so a game being play-tested collides by the new grid at
/// once. Until a project changes something there is no file, and the
/// defaults stand: everything on `Default`, everything colliding.
///
/// Bodies refer to a layer by its number, so naming, renaming, recolouring
/// and describing one touch only this file. Taking a layer out of use while
/// bodies are on it is `LayerRefactor`'s job: it moves them first.
class ProjectPhysicsLayers {
  /// The layers kept in the file at [path]. `context` gives the engine
  /// context they are handed to — none, and they stay here; `onProblem` is
  /// told, in words, of each read or write that fails. Nothing is read
  /// until [load].
  ProjectPhysicsLayers({
    required this.path,
    jge.EngineContext? Function()? context,
    void Function(String problem)? onProblem,
  }) : _context = context ?? (() => null),
       _onProblem = onProblem;

  /// The layer file of the project the editor runs in — or, for a store
  /// rooted elsewhere (a test's temporary directory), `physics.json` there.
  static String pathFor({String? scenesRoot}) => scenesRoot == null
      ? '${Directory.current.path}/${jge.PhysicsLayers.defaultPath}'
      : '$scenesRoot/physics.json';

  /// Where the layer file is.
  final String path;

  final jge.EngineContext? Function() _context;

  /// The layers, as last read or set.
  late final Signal<jge.PhysicsLayers> layers = Signal(
    jge.PhysicsLayers.defaults,
    debugLabel: 'physicsLayers',
  );

  /// The layers now: [layers]'s value.
  jge.PhysicsLayers get value => layers.value;

  /// Whether the project has a layer file yet.
  bool get hasFile => File(path).existsSync();

  /// What went wrong reading or writing the file, or null.
  String? get error => _error;
  String? _error;

  /// Whether the layer file is there but could not be read — broken JSON, a
  /// newer engine's, unreadable — so it is left as it is: nothing is
  /// written over it, and no change is made, until it reads ([load]).
  bool get isUnreadable => _unreadable;
  bool _unreadable = false;

  final void Function(String problem)? _onProblem;

  /// Reads the layer file — the defaults without one — and hands the layers
  /// to the engine.
  ///
  /// A file that is there but cannot be read is left as it is: the defaults
  /// stand in for it, [error] says why, and every change is refused
  /// ([isUnreadable]) until the file is fixed and read again — so the
  /// defaults are never written over the project's layers.
  void load() {
    _error = null;
    _unreadable = false;
    final file = File(path);
    var next = jge.PhysicsLayers.defaults;
    try {
      if (file.existsSync()) {
        next = jge.PhysicsLayers.fromJson(jsonDecode(file.readAsStringSync()));
      }
    } on Object catch (e) {
      _unreadable = true;
      final why = switch (e) {
        jge.UnsupportedFormatVersionException() => '$e',
        FormatException(:final message) =>
          'The physics layers file is not valid: $message',
        FileSystemException(:final message) => 'Could not read $path: $message',
        _ => 'The physics layers file is not valid: $e',
      };
      _error =
          '$why It is left as it is: fix it and read it again to change '
          'layers.';
      _onProblem?.call(_error!);
    }
    _apply(next);
  }

  /// Makes [next] the project's layers: written to the file — whole or not
  /// at all — then given to the engine. False, with nothing changed, when
  /// the file cannot be read ([isUnreadable]) or written ([error]).
  bool set(jge.PhysicsLayers next) {
    if (next == layers.value) return true;
    if (_unreadable) {
      _onProblem?.call(_error!);
      return false;
    }
    final text = const JsonEncoder.withIndent('  ').convert(next.toJson());
    try {
      ProjectFiles.writeStringSync(path, '$text\n');
    } on Object catch (e) {
      _error =
          'Could not write $path: '
          '${e is FileSystemException ? e.message : e}';
      _onProblem?.call(_error!);
      return false;
    }
    _error = null;
    _apply(next);
    return true;
  }

  // ── Changing ─────────────────────────────────────────────────────────────

  /// Why [name] cannot be a new layer, or null when it can.
  String? problemWithNew(String name) {
    if (value.firstFree == null) {
      return 'All ${jge.PhysicsLayers.count} layers are in use.';
    }
    return value.problemWithName(name);
  }

  /// Why [layer] cannot be renamed [name], or null when it can.
  String? problemWithRename(int layer, String name) {
    if (name.trim() == value.nameOf(layer)) return 'That is its name already.';
    return value.problemWithName(name, except: layer);
  }

  /// Names the first free layer [name]; its number, or null when
  /// [problemWithNew] objects or the file could not be written.
  int? create(String name, {Color? color, String description = ''}) {
    if (problemWithNew(name) != null) return null;
    final layer = value.firstFree!;
    var next = value.withName(layer, name.trim());
    if (color != null) next = next.withColor(layer, color);
    if (description.isNotEmpty) next = next.withDescription(layer, description);
    return set(next) ? layer : null;
  }

  /// Renames [layer]; false when [problemWithRename] objects or the file
  /// could not be written. Bodies keep their layer by number, so nothing
  /// else changes.
  bool rename(int layer, String name) {
    if (problemWithRename(layer, name) != null) return false;
    return set(value.withName(layer, name.trim()));
  }

  /// Shows [layer] in [color]; null for its default.
  void recolor(int layer, Color? color) => set(value.withColor(layer, color));

  /// Describes what [layer] is for.
  void describe(int layer, String description) =>
      set(value.withDescription(layer, description.trim()));

  /// Takes [layer] out of use: no name, colour or description, colliding
  /// with everything again. Bodies still on it are left there — see
  /// `LayerRefactor`, which moves them first.
  void clear(int layer) => set(value.cleared(layer));

  /// Sets whether layers [a] and [b] collide ([collide]), both ways.
  void setCollision(int a, int b, bool collide) =>
      set(value.withCollision(a, b, collide));

  void _apply(jge.PhysicsLayers next) {
    layers.value = next;
    _context()?.physicsLayers = next;
  }

  /// Disposes [layers]; the scope that made this calls it.
  void dispose() => layers.dispose();
}
