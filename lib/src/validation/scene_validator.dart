import 'dart:convert';

import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../../io.dart';
import '../services/package_asset_paths.dart';
import '../scope/editor_scope.dart';

/// How bad a [SceneProblem] is: the colour and icon it is shown with, and
/// the Problems dock lists errors first.
enum ProblemSeverity {
  /// Worth a look: it may be meant, or work less well than it could.
  warning,

  /// Broken: it will not work as set up in the game.
  error,
}

/// A way to put a problem right in one click — `Use "player"`. Each one is
/// an ordinary edit: it goes on the undo stack like any other.
class ProblemFix {
  const ProblemFix({required this.label, required this.apply});

  /// The fix's button text: what it does, in a few words.
  final String label;

  /// Makes the fix; the Problems dock checks the scene again straight
  /// after.
  final void Function() apply;
}

/// Something wrong with the open scene, said in words an author can act on.
class SceneProblem {
  const SceneProblem({
    required this.message,
    this.severity = ProblemSeverity.warning,
    this.entity,
    this.hint,
    this.fixes = const [],
  });

  /// Ways to fix it in one click, best first.
  final List<ProblemFix> fixes;

  /// What is wrong: the problem's line in the Problems dock, and the
  /// tooltip of the mark on its entity's scene-tree row.
  final String message;

  /// How bad it is; a warning unless said.
  final ProblemSeverity severity;

  /// Who it is about; clicking the problem selects it.
  final jge.Entity? entity;

  /// What to do about it.
  final String? hint;
}

/// What a validator looks at. File access goes through here so a check can
/// be tested without a project on disk.
///
/// The checks run every second or so while the scene is edited, on the UI
/// thread, and many entities name the same few files: each path is looked
/// up once per run ([fileExists], [readText], [readJson]), and a file whose
/// time and size on disk have not changed since an earlier run is not read
/// or decoded again. What [readJson] returns is shared: read it, never
/// change it.
class ValidationContext {
  /// A context for one run of the checks over [scope]'s scene.
  ///
  /// `projectRoot` is the current directory when null. `fileExists` and
  /// `readText`, when given, stand in for the disk — for a test — in
  /// [fileExists], and in [readText] and [readJson].
  ValidationContext({
    required this.scope,
    String? projectRoot,
    bool Function(String path)? fileExists,
    String? Function(String path)? readText,
  }) : projectRoot = (projectRoot ?? Directory.current.path).replaceAll(
         r'\',
         '/',
       ),
       _fileExists = fileExists,
       _readText = readText;

  /// The editor whose open scene is checked.
  final EditorScope scope;

  /// The project's folder, which the checked paths are relative to:
  /// absolute, with forward slashes.
  final String projectRoot;
  final bool Function(String path)? _fileExists;
  final String? Function(String path)? _readText;

  /// The world being checked: [scope]'s.
  jge.World get world => scope.world;

  /// Where the project's packages are, for `packages/<name>/…` paths.
  PackageAssetPaths get packages => PackageAssetPaths.of(projectRoot);

  // This run's answers, by path.
  final Map<String, bool> _exists = {};
  final Map<String, _ReadFile?> _read = {};

  /// Whether the project-relative [path] is a file. A `packages/<name>/…`
  /// path is looked for in that package's folder.
  bool fileExists(String path) => _exists[path] ??=
      _fileExists?.call(path) ?? packages.file(path).existsSync();

  /// The text of [path], or null when it cannot be read.
  String? readText(String path) {
    if (_readText != null) return _readText(path);
    return _readFile(path)?.text;
  }

  /// [path] decoded as a JSON object, or null when it cannot be read or is
  /// not one. Shared with the other checks of this run (and later runs while
  /// the file is unchanged): not to be changed.
  Map<String, dynamic>? readJson(String path) {
    if (_readText != null) return _decode(_readText(path));
    final file = _readFile(path);
    if (file == null) return null;
    if (!file.decoded) {
      file
        ..json = _decode(file.text)
        ..decoded = true;
    }
    return file.json;
  }

  static Map<String, dynamic>? _decode(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  /// [path] as read — this run, or an earlier one while its time and size
  /// on disk are the same.
  _ReadFile? _readFile(String path) {
    if (_read.containsKey(path)) return _read[path];
    final file = packages.file(path);
    _ReadFile? out;
    try {
      final stat = file.statSync();
      if (stat.type == FileSystemEntityType.notFound) return _read[path] = null;
      final key = file.path;
      final known = _ReadFile.recent.remove(key);
      if (known != null &&
          known.modified == stat.modified &&
          known.size == stat.size) {
        out = known;
      } else {
        out = _ReadFile(stat.modified, stat.size, file.readAsStringSync());
      }
      // Most recent last; the oldest go past the limit.
      _ReadFile.recent[key] = out;
      while (_ReadFile.recent.length > _ReadFile.keep) {
        _ReadFile.recent.remove(_ReadFile.recent.keys.first);
      }
    } on FileSystemException {
      out = null;
    }
    return _read[path] = out;
  }
}

/// A file the checks read, kept between runs while it is unchanged.
class _ReadFile {
  _ReadFile(this.modified, this.size, this.text);

  /// How many are kept.
  static const int keep = 128;

  /// By absolute path, the most recently used last.
  static final Map<String, _ReadFile> recent = {};

  final DateTime modified;
  final int size;
  final String text;
  Map<String, dynamic>? json;
  bool decoded = false;
}

/// One check over the scene. A module adds its own through
/// `EditorModule.validators`.
typedef SceneValidator = List<SceneProblem> Function(ValidationContext context);
