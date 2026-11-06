import 'dart:async';

import '../io/io.dart';
import 'asset_index.dart';
import 'project_files.dart';

/// Which files mention an asset, and rewriting them when it moves.
///
/// Project files refer to assets by path:
///
/// - scenes, atlases, animator graphs and the editor's other JSON files
///   (`.json`, and `.jsprite` sprite projects) as whole quoted strings —
///   `"assets/sprites/hero.png"`;
/// - the game's Dart code under `lib/` as string literals —
///   `'assets/audio/jump.wav'`;
/// - `pubspec.yaml` in its `flutter:` section's lists — `- assets/sprites/`;
/// - Tiled maps, tilesets and templates (`.tmx`, `.tsx`, `.tx`) in their
///   `source` and `template` attributes, relative to the file itself —
///   `source="../tilesets/grassland.png"`.
///
/// So "who uses this?" is a text search — exact: a file's path is matched
/// as a whole string, not a fragment. A folder matches every path under it.
abstract final class AssetReferences {
  /// The endings of the files under the index read as JSON.
  static const List<String> jsonEndings = ['.json', '.jsprite'];

  /// The endings of the Tiled files read for their relative paths.
  static const List<String> tiledEndings = ['.tmx', '.tsx', '.tx'];

  /// Where the game's code is, under the project: what is read for paths
  /// in string literals.
  static const String codeFolder = 'lib';

  /// The project's pubspec, which lists what the game ships.
  static const String pubspec = 'pubspec.yaml';

  /// Where [rewrite] keeps each file as it was before it changed it, in a
  /// folder per rewrite, under the project: never under `assets/`, which
  /// ships with the game.
  static const String backupFolder = '.editor_backups/references';

  /// How many rewrites' backups are kept; older ones are deleted.
  static const int backupsKept = 10;

  /// The files that mention [path]: for a file, its whole path; for a
  /// folder, any path under it — the folder's own files included, which
  /// name each other by path too.
  static Future<List<String>> find(AssetIndex index, String path) async {
    final folder = FileSystemEntity.isDirectorySync(index.absolute(path));
    final out = <String>[];
    for (final file in await _candidates(index)) {
      if (file == path) continue;
      final kind = _kindOf(file);
      if (kind == null) continue;
      final text = await _read(index, file);
      if (text == null) continue;
      if (_edit(kind, text, file, file, path, path, folder).$2) {
        out.add(file);
      }
    }
    return out;
  }

  /// Points every mention of [from] at [to], once [from] has been renamed
  /// [to] on disk: a file's path, or a folder's and so every path under it.
  /// Returns the files changed.
  ///
  /// Each file is written whole or not at all, and as it was before goes
  /// to a new folder in [backupFolder] first. Files of installed packages
  /// (`packages/…`) are theirs and are left as they are.
  static Future<List<String>> rewrite(
    AssetIndex index,
    String from,
    String to,
  ) async {
    if (from == to) return const [];
    final folder = FileSystemEntity.isDirectorySync(index.absolute(to));
    String? backups;
    final changed = <String>[];
    for (final file in await _candidates(index)) {
      if (file == to || AssetIndex.isPackagePath(file)) continue;
      final kind = _kindOf(file);
      if (kind == null) continue;
      final text = await _read(index, file);
      if (text == null) continue;
      // Where the file was before the rename: inside a renamed folder, it
      // moved with it.
      final was = _moved(file, to, from, folder) ?? file;
      final (edited, mentions) = _edit(kind, text, was, file, from, to, folder);
      if (!mentions || edited == text) continue;
      backups ??= await _newBackupFolder(index);
      await ProjectFiles.writeString('$backups/$file', text);
      await ProjectFiles.writeString(index.absolute(file), edited);
      changed.add(file);
    }
    return changed;
  }

  // ── Which files ─────────────────────────────────────────────────────────

  /// Every file that may mention a path: the index's JSON and Tiled files,
  /// the game's Dart code and the pubspec. Project-relative.
  static Future<List<String>> _candidates(AssetIndex index) async {
    final out = <String>[
      for (final e in index.entries)
        if (!e.isDirectory && _kindOf(e.path) != null) e.path,
    ];
    final code = Directory('${index.projectRoot}/$codeFolder');
    if (await code.exists()) {
      final found = <String>[];
      try {
        await for (final f in code.list(recursive: true, followLinks: false)) {
          if (f is File && f.path.toLowerCase().endsWith('.dart')) {
            found.add(index.relative(f.path));
          }
        }
      } on FileSystemException {
        // Unreadable: what was listed is searched.
      }
      out.addAll(found..sort());
    }
    if (await File('${index.projectRoot}/$pubspec').exists()) out.add(pubspec);
    return out;
  }

  static _Kind? _kindOf(String file) {
    if (file == pubspec) return _Kind.pubspec;
    final lower = file.toLowerCase();
    if (lower.startsWith('$codeFolder/')) {
      return lower.endsWith('.dart') ? _Kind.dart : null;
    }
    if (jsonEndings.any(lower.endsWith)) return _Kind.json;
    if (tiledEndings.any(lower.endsWith)) return _Kind.tiled;
    return null;
  }

  static Future<String?> _read(AssetIndex index, String file) async {
    try {
      return await File(index.absolute(file)).readAsString();
    } on FileSystemException {
      // Unreadable: it cannot be said to use anything.
      return null;
    } on FormatException {
      // Not text.
      return null;
    }
  }

  // ── What they say ───────────────────────────────────────────────────────

  /// [text] (of a [kind] file, at [file] now and at [was] before the move)
  /// with every mention of [from] pointed at [to], and whether there was
  /// one. With [from] and [to] the same it only looks.
  static (String, bool) _edit(
    _Kind kind,
    String text,
    String was,
    String file,
    String from,
    String to,
    bool folder,
  ) => switch (kind) {
    _Kind.json => _quoted(text, const ['"'], from, to, folder),
    _Kind.dart => _quoted(text, const ["'", '"'], from, to, folder),
    _Kind.pubspec => _pubspec(text, from, to, folder),
    _Kind.tiled => _tiled(text, was, file, from, to, folder),
  };

  /// Whole quoted strings: `"from"`, or for a folder any string starting
  /// `"from/`.
  static (String, bool) _quoted(
    String text,
    List<String> quotes,
    String from,
    String to,
    bool folder,
  ) {
    var out = text;
    var found = false;
    for (final q in quotes) {
      final needle = folder ? '$q$from/' : '$q$from$q';
      if (!out.contains(needle)) continue;
      found = true;
      out = out.replaceAll(needle, folder ? '$q$to/' : '$q$to$q');
    }
    return (out, found);
  }

  // A list entry in the pubspec: `- assets/x/`, `- path: assets/x/`,
  // `- asset: assets/fonts/a.ttf`, quoted or not, a comment after it.
  static final RegExp _pubspecEntry = RegExp(
    r'''^(\s*-\s*(?:(?:asset|path):\s*)?)(["']?)([^"'#\s]+)\2''',
  );

  /// The `flutter:` section's list entries that are [from], or under it.
  static (String, bool) _pubspec(
    String text,
    String from,
    String to,
    bool folder,
  ) {
    final lines = text.split('\n');
    var found = false;
    var inFlutter = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (!line.startsWith(' ') && !line.startsWith('\t')) {
        inFlutter = trimmed == 'flutter:';
        continue;
      }
      if (!inFlutter) continue;
      final m = _pubspecEntry.firstMatch(line);
      if (m == null) continue;
      final next = _moved(m.group(3)!, from, to, folder);
      if (next == null) continue;
      found = true;
      lines[i] =
          '${m.group(1)}${m.group(2)}$next${m.group(2)}'
          '${line.substring(m.end)}';
    }
    return (found ? lines.join('\n') : text, found);
  }

  static final RegExp _tiledAttribute = RegExp(
    r'''\b(source|template)\s*=\s*"([^"]*)"''',
  );

  /// Tiled's `source="…"` and `template="…"`, relative to the file's folder
  /// — [was] before the move, [file] after.
  static (String, bool) _tiled(
    String text,
    String was,
    String file,
    String from,
    String to,
    bool folder,
  ) {
    var found = false;
    final out = text.replaceAllMapped(_tiledAttribute, (m) {
      final value = m.group(2)!;
      final target = _resolve(_folderOf(was), value);
      if (target == null) return m.group(0)!;
      final moved = _moved(target, from, to, folder);
      if (moved == null) return m.group(0)!;
      found = true;
      final next = _relative(_folderOf(file), moved);
      return '${m.group(1)}="$next"';
    });
    return (found ? out : text, found);
  }

  // ── Paths ───────────────────────────────────────────────────────────────

  /// [path] with [from] made [to]: [from] itself, or for a [folder] a path
  /// under it. Null when it is neither.
  static String? _moved(String path, String from, String to, bool folder) {
    if (path == from) return to;
    if (folder && path.startsWith('$from/')) {
      return '$to${path.substring(from.length)}';
    }
    return null;
  }

  static String _folderOf(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  /// [value], relative to the folder [dir], as a project path; null when it
  /// is not a relative path inside the project.
  static String? _resolve(String dir, String value) {
    final v = value.replaceAll(r'\', '/');
    if (v.isEmpty || v.startsWith('/') || v.contains(':')) return null;
    final parts = dir.isEmpty ? <String>[] : dir.split('/');
    for (final part in v.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isEmpty) return null;
        parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }

  /// The way from the folder [dir] to [path], both project paths.
  static String _relative(String dir, String path) {
    final from = dir.isEmpty ? <String>[] : dir.split('/');
    final to = path.split('/');
    var same = 0;
    while (same < from.length &&
        same < to.length - 1 &&
        from[same] == to[same]) {
      same++;
    }
    return [
      for (var i = same; i < from.length; i++) '..',
      ...to.sublist(same),
    ].join('/');
  }

  // ── Backups ─────────────────────────────────────────────────────────────

  /// A new folder for this rewrite's backups, the oldest beyond
  /// [backupsKept] deleted. Absolute.
  static Future<String> _newBackupFolder(AssetIndex index) async {
    final root = Directory('${index.projectRoot}/$backupFolder');
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}-'
        '${t.millisecond.toString().padLeft(3, '0')}';
    var name = stamp;
    for (var n = 2; await Directory('${root.path}/$name').exists(); n++) {
      name = '$stamp-$n';
    }
    final dir = Directory('${root.path}/$name');
    await dir.create(recursive: true);
    try {
      final all = root.listSync().whereType<Directory>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in all.skip(backupsKept)) {
        await old.delete(recursive: true);
      }
    } on FileSystemException {
      // In use elsewhere: it goes next time.
    }
    return dir.path;
  }
}

enum _Kind { json, dart, pubspec, tiled }
