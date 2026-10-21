/// The project's tag list, as the editor keeps it.
library;

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_signals/just_signals.dart';

import '../../io.dart';
import '../services/project_files.dart';

/// The tags a project knows, from three places:
///
/// * **the tag file** ([jge.TagLibrary.defaultPath]) — the tags people
///   made, and the colours and descriptions they set;
/// * **code** — tags the engine and each module look for by name
///   ([jge.EngineTags], `EditorModule.tags`), shown as built in: they
///   cannot be renamed or deleted, or code would go on looking for the old
///   name;
/// * **spawners** — the tags the game gives what it spawns
///   ([jge.Spawner.tags]), which exist only once the game runs. That is how
///   the editor knows a camera following `#player` in a level with no
///   player in it is not a mistake.
///
/// Until a project has a tag file, the list is the declared tags and the
/// tags its scenes already carry; the file is written with the first
/// change. Every change writes it.
class ProjectTags {
  /// The tags kept in the file at [path]. `spawners` gives the game's
  /// spawners whenever asked; `onProblem` is told, in words, of each read
  /// or write that fails. Nothing is read until [load], or the first
  /// question that needs the list.
  ProjectTags({
    required this.path,
    List<jge.Spawner> Function()? spawners,
    void Function(String problem)? onProblem,
  }) : _spawners = spawners ?? (() => const []),
       _onProblem = onProblem;

  /// The tag file of the project the editor runs in — or, for a store
  /// rooted elsewhere (a test's temporary directory), `tags.json` there.
  static String pathFor({String? scenesRoot}) => scenesRoot == null
      ? '${Directory.current.path}/${jge.TagLibrary.defaultPath}'
      : '$scenesRoot/tags.json';

  /// Where the tag file is.
  final String path;

  /// The list: the file's tags with the declared ones merged in.
  late final Signal<jge.TagLibrary> library = Signal(
    jge.TagLibrary.empty,
    debugLabel: 'projectTags',
  );

  final List<jge.Spawner> Function() _spawners;

  /// The game's spawners, as the app handed them to the editor.
  List<jge.Spawner> get spawners => _spawners();

  jge.TagLibrary _file = jge.TagLibrary.empty;
  List<jge.TagDefinition> _declared = jge.EngineTags.declared;
  bool _loaded = false;

  /// Whether the project has a tag file yet.
  bool get hasFile => File(path).existsSync();

  /// What went wrong reading the file, or null.
  String? get loadError => _loadError;
  String? _loadError;

  /// What went wrong writing the file last time, or null.
  String? get writeError => _writeError;
  String? _writeError;

  /// Whether the tag file is there but could not be read — broken JSON, a
  /// newer engine's, unreadable — so it is left as it is: nothing is
  /// written over it, and no change is made, until it reads ([load]).
  bool get isUnreadable => _unreadable;
  bool _unreadable = false;

  final void Function(String problem)? _onProblem;

  Iterable<String> Function()? _seed;

  /// Sets the tags code declares — the engine's and every module's. Called
  /// on each registration pass.
  void setDeclared(Iterable<jge.TagDefinition> declared) {
    _declared = [...jge.EngineTags.declared, ...declared];
    _publish();
  }

  /// Reads the tag file. Without one, [seed] — the tags the project's
  /// scenes carry — stands in for it until the first change writes it. Read
  /// again without one, the [seed] given before is used.
  ///
  /// A file that is there but cannot be read is left as it is: the list is
  /// the declared tags alone, [loadError] says why, and every change is
  /// refused ([isUnreadable]) until the file is fixed and read again — so
  /// the list is never written over the project's tags.
  void load({Iterable<String> Function()? seed}) {
    _loadError = null;
    _unreadable = false;
    final from = _seed = seed ?? _seed;
    final file = File(path);
    try {
      if (file.existsSync()) {
        _file = jge.TagLibrary.fromJson(jsonDecode(file.readAsStringSync()));
      } else {
        _file = jge.TagLibrary.empty.withNames(from?.call() ?? const []);
      }
    } on Object catch (e) {
      _unreadable = file.existsSync();
      _file = jge.TagLibrary.empty;
      final why = switch (e) {
        jge.UnsupportedFormatVersionException() => '$e',
        FormatException(:final message) =>
          'The tag file is not valid: $message',
        FileSystemException(:final message) => 'Could not read $path: $message',
        _ => 'The tag file is not valid: $e',
      };
      _loadError = _unreadable
          ? '$why It is left as it is: fix it and read it again to change '
                'tags.'
          : 'Could not find the tags the scenes carry: $e';
      _onProblem?.call(_loadError!);
    }
    _loaded = true;
    _publish();
  }

  void _ensureLoaded() {
    if (!_loaded) load();
  }

  void _publish() => library.value = _file.withDeclared(_declared);

  // ── Reading ──────────────────────────────────────────────────────────────

  /// Every tag the game's spawners give.
  Set<String> get spawnedTags => {for (final s in spawners) ...s.tags};

  /// The spawners whose entities carry [tag].
  List<jge.Spawner> spawnersGiving(String tag) => [
    for (final s in spawners)
      if (s.tags.contains(tag)) s,
  ];

  /// Whether [tag] is one the project knows: listed, or given by a spawner.
  bool isKnown(String tag) {
    _ensureLoaded();
    return library.value.contains(tag) || spawnedTags.contains(tag);
  }

  /// Every tag to offer in a picker, in list order, spawned ones last.
  List<String> get names {
    _ensureLoaded();
    final listed = library.value.names.toList();
    return [
      ...listed,
      for (final t in spawnedTags)
        if (!listed.contains(t)) t,
    ];
  }

  /// The listed tag called [name], declared ones included; null when it is
  /// not on the list.
  jge.TagDefinition? operator [](String name) {
    _ensureLoaded();
    return library.value[name];
  }

  /// [tag]'s chip colour: its own, or one picked from its name, the same
  /// on every run.
  Color colorOf(String tag) => library.value.colorOf(tag);

  /// The listed tag [name] most likely meant, or null.
  String? closest(String name) => jge.TagNames.closest(name, names);

  // ── Changing ─────────────────────────────────────────────────────────────

  /// Why [name] cannot be a new tag, or null when it can.
  String? problemWithNew(String name) {
    _ensureLoaded();
    final problem = jge.TagNames.problemWith(name);
    if (problem != null) return problem;
    if (library.value.contains(name)) return 'There is already a "$name".';
    final near = library.value.nearDuplicateOf(name);
    if (near != null) {
      return 'Too close to "$near" to tell apart — use that one, or pick a '
          'clearly different name.';
    }
    return null;
  }

  /// Adds a tag; null when [problemWithNew] objects.
  jge.TagDefinition? create(
    String name, {
    Color? color,
    String description = '',
  }) {
    if (problemWithNew(name) != null) return null;
    final tag = jge.TagDefinition(
      name,
      color: color ?? jge.TagLibrary.colorFor(name),
      description: description,
    );
    if (!_write(_file.put(tag))) return null;
    return library.value[name];
  }

  /// Adds [names] that are not listed yet, as plain tags — for tags a scene
  /// already uses. Returns how many were added.
  int adopt(Iterable<String> names) {
    _ensureLoaded();
    final missing = [
      for (final n in jge.TagNames.normalize(names))
        if (!library.value.contains(n)) n,
    ];
    if (missing.isEmpty) return 0;
    if (!_write(_file.withNames(missing))) return 0;
    return missing.length;
  }

  /// Changes a tag's colour or description. False when the file could not
  /// be written, and nothing changed.
  bool update(jge.TagDefinition tag) {
    _ensureLoaded();
    return _write(_file.put(tag));
  }

  /// Renames [from] in the list — not in the scenes: see `TagRefactor`.
  /// Refused for a declared tag, and false when the file could not be
  /// written.
  bool rename(String from, String to) {
    _ensureLoaded();
    if (library.value[from]?.isDeclared ?? false) return false;
    final source = _file.contains(from)
        ? _file
        : _file.put(library.value[from] ?? jge.TagDefinition(from));
    return _write(source.rename(from, to));
  }

  /// Takes [name] off the list. Refused for a declared tag, and false when
  /// the file could not be written.
  bool remove(String name) {
    _ensureLoaded();
    if (library.value[name]?.isDeclared ?? false) return false;
    return _write(_file.remove(name));
  }

  /// Writes [next] to the file — whole or not at all — and then makes it
  /// the list. False, with nothing changed, when the file cannot be read
  /// ([isUnreadable]) or written ([writeError]).
  bool _write(jge.TagLibrary next) {
    if (_unreadable) {
      _onProblem?.call(_loadError!);
      return false;
    }
    // What the file has written is what the list shows, declared tags
    // included, so it reads as the whole list.
    final text = const JsonEncoder.withIndent(
      '  ',
    ).convert(next.withDeclared(_declared).toJson());
    try {
      ProjectFiles.writeStringSync(path, '$text\n');
    } on Object catch (e) {
      _writeError =
          'Could not write $path: '
          '${e is FileSystemException ? e.message : e}';
      _onProblem?.call(_writeError!);
      return false;
    }
    _writeError = null;
    _file = next;
    _publish();
    return true;
  }

  /// Disposes [library]; the scope that made this calls it.
  void dispose() => library.dispose();
}
