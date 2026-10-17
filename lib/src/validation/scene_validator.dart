import 'dart:convert';
import 'dart:io';

import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../services/package_asset_paths.dart';
import '../scope/editor_scope.dart';

enum ProblemSeverity { warning, error }

/// A way to put a problem right in one click — `Use "player"`. Each one is
/// an ordinary edit: it goes on the undo stack like any other.
class ProblemFix {
  const ProblemFix({required this.label, required this.apply});

  final String label;
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

  final String message;
  final ProblemSeverity severity;

  /// Who it is about; clicking the problem selects it.
  final jge.Entity? entity;

  /// What to do about it.
  final String? hint;
}

/// What a validator looks at. File access goes through here so a check can
/// be tested without a project on disk.
class ValidationContext {
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

  final EditorScope scope;
  final String projectRoot;
  final bool Function(String path)? _fileExists;
  final String? Function(String path)? _readText;

  jge.World get world => scope.world;

  /// Where the project's packages are, for `packages/<name>/…` paths.
  PackageAssetPaths get packages => PackageAssetPaths.of(projectRoot);

  /// Whether the project-relative [path] is a file. A `packages/<name>/…`
  /// path is looked for in that package's folder.
  bool fileExists(String path) =>
      _fileExists?.call(path) ?? packages.file(path).existsSync();

  /// The text of [path], or null when it cannot be read.
  String? readText(String path) {
    if (_readText != null) return _readText(path);
    try {
      return packages.file(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  Map<String, dynamic>? readJson(String path) {
    final text = readText(path);
    if (text == null) return null;
    try {
      final json = jsonDecode(text);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }
}

/// One check over the scene. A module adds its own through
/// `EditorModule.validators`.
typedef SceneValidator = List<SceneProblem> Function(ValidationContext context);
