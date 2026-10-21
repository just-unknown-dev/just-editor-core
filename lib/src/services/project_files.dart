import 'dart:convert';

import '../../io.dart';

/// Writing, moving and naming the project's files safely.
///
/// Every tool that saves a project file — a scene, a timeline, a material,
/// a settings file — goes through these, so that:
///
/// - a save is whole or not at all: written beside the file first and then
///   moved over it, so a crash, a full disk or an error halfway never leaves
///   half a file where the old one was;
/// - a rename that changes only letter case works on the file systems that
///   fold case (Windows and macOS), where `level.json` and `Level.json` are
///   one file and a copy-then-delete would delete it;
/// - a path read out of a project file cannot reach outside the project.
abstract final class ProjectFiles {
  /// Whether the file system here folds letter case: Windows and macOS,
  /// where `a.json` and `A.json` name one file.
  static bool get foldsCase => Platform.isWindows || Platform.isMacOS;

  /// Whether [a] and [b] name the same file here: separators made `/`, and
  /// letter case folded where the file system folds it ([foldsCase]).
  static bool samePath(String a, String b) {
    final x = _normal(a);
    final y = _normal(b);
    return foldsCase ? x.toLowerCase() == y.toLowerCase() : x == y;
  }

  /// Writes [text] to the file at [path], whole or not at all, making its
  /// folder when missing.
  ///
  /// The text goes to `<path>.saving` first, flushed to disk, and that file
  /// is then moved over [path]. When anything fails, the file at [path] is
  /// as it was, the `.saving` file is removed, and the error is rethrown.
  static Future<void> writeString(
    String path,
    String text, {
    Encoding encoding = utf8,
  }) => writeBytes(path, encoding.encode(text));

  /// [writeString], for bytes.
  static Future<void> writeBytes(String path, List<int> bytes) async {
    final target = File(path);
    await target.parent.create(recursive: true);
    final saving = File('$path.saving');
    try {
      await saving.writeAsBytes(bytes, flush: true);
      await _moveOver(saving, path);
    } catch (_) {
      await _discard(saving);
      rethrow;
    }
  }

  /// [writeString], waiting for the disk: for the few saves that must be
  /// done before the next line (an undo step's file, a setting written as
  /// the editor closes).
  static void writeStringSync(
    String path,
    String text, {
    Encoding encoding = utf8,
  }) {
    final target = File(path);
    target.parent.createSync(recursive: true);
    final saving = File('$path.saving');
    try {
      saving.writeAsBytesSync(encoding.encode(text), flush: true);
      _moveOverSync(saving, path);
    } catch (_) {
      try {
        if (saving.existsSync()) saving.deleteSync();
      } on FileSystemException {
        // Nothing more to do: the error below says what went wrong.
      }
      rethrow;
    }
  }

  /// Moves the file or folder at [from] to [to], making [to]'s parent
  /// folder when missing.
  ///
  /// A move that changes only letter case goes through a third name, as the
  /// file systems that fold case need. Throws a [FileSystemException] when
  /// something else is already at [to] — a rename never replaces anything.
  static Future<void> rename(String from, String to) async {
    if (_normal(from) == _normal(to)) return;
    final caseOnly = samePath(from, to);
    final there = await FileSystemEntity.type(to, followLinks: false);
    if (there != FileSystemEntityType.notFound &&
        !(caseOnly && await FileSystemEntity.identical(from, to))) {
      throw FileSystemException('Something is already there', to);
    }
    await Directory(to).parent.create(recursive: true);
    if (caseOnly) {
      final step = await _freeName(to);
      await _entity(from).rename(step);
      await _entity(step).rename(to);
      return;
    }
    await _entity(from).rename(to);
  }

  static FileSystemEntity _entity(String path) =>
      FileSystemEntity.isDirectorySync(path) ? Directory(path) : File(path);

  /// Whether [key] — a path relative to the project or a package, with `/`
  /// or `\` between parts — stays inside it: not absolute, no drive letter,
  /// and no `..` that climbs out of the folder it starts in.
  ///
  /// Paths read from project files (a scene's sprite, a material's maps, a
  /// timeline's file) are checked with this before anything is written next
  /// to them.
  static bool isContained(String key) {
    final k = key.replaceAll(r'\', '/');
    if (k.isEmpty || k.startsWith('/') || k.contains(':')) return false;
    var depth = 0;
    for (final part in k.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (--depth < 0) return false;
      } else {
        depth++;
      }
    }
    return true;
  }

  // On Windows a file another handle has open — a read still in flight, an
  // antivirus or indexer scan — cannot be replaced for a moment, and the
  // move fails with "Access is denied". It is tried again for about a second
  // before the error is the caller's.
  static const _retries = [10, 20, 40, 80, 160, 320, 400];

  static Future<void> _moveOver(File saving, String path) async {
    for (var i = 0; ; i++) {
      try {
        await saving.rename(path);
        return;
      } on FileSystemException {
        if (!Platform.isWindows || i == _retries.length) rethrow;
        await Future<void>.delayed(Duration(milliseconds: _retries[i]));
      }
    }
  }

  static void _moveOverSync(File saving, String path) {
    for (var i = 0; ; i++) {
      try {
        saving.renameSync(path);
        return;
      } on FileSystemException {
        if (!Platform.isWindows || i == _retries.length) rethrow;
        // No sleep without dart:io's sleep, which the web lacks: wait out
        // the moment by the clock.
        final until = Stopwatch()..start();
        while (until.elapsedMilliseconds < _retries[i] ~/ 4) {}
      }
    }
  }

  static Future<void> _discard(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing more to do: the caller rethrows the error that matters.
    }
  }

  static Future<String> _freeName(String path) async {
    for (var i = 0; ; i++) {
      final candidate = '$path.renaming$i';
      final type = await FileSystemEntity.type(candidate, followLinks: false);
      if (type == FileSystemEntityType.notFound) return candidate;
    }
  }

  static String _normal(String path) {
    var p = path.replaceAll(r'\', '/');
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
