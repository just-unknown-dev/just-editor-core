import 'dart:convert';

import 'package:just_game_engine/just_game_engine.dart';

import '../../io.dart';
import '../services/project_files.dart';
import 'editor_scene.dart';
import 'scene_codec.dart';

/// Reads and writes the project's scene files.
///
/// Scenes are plain JSON assets, flat in one directory, listed in order by a
/// manifest:
///
/// ```
/// assets/scenes/
///   scenes.json            ← {"scenes": ["level_01", "level_02"]}
///   level_01.scene.json
///   level_02.scene.json
/// ```
///
/// There is no generated code. The shipped game loads these same files with
/// the engine's `SceneLoader`, through the same codecs the editor saves with,
/// so what you save is exactly what ships — and nothing here is imported by
/// the game.
///
/// Flat on purpose: `assets/scenes/` is declared once in `pubspec.yaml` and
/// every scene saved into it ships. A folder per scene needed a pubspec edit
/// for each new level.
///
/// Every write is whole or not at all ([ProjectFiles.writeString]): a crash
/// or a full disk mid-save leaves the file that was there. A scene's name is
/// one plain file name — no folder separators, no `..` — or the store
/// refuses it with an [ArgumentError]; and a `scenes.json` that cannot be
/// read is never rewritten from nothing (a [FormatException] says so).
///
/// Uses `dart:io`, so only runs where the editor does: native desktop, debug.
/// The project folder must be writable — a sandboxed macOS debug app is not
/// (see the package README).
class SceneStore {
  /// A store rooted at [root], or at the project's `assets/scenes` when
  /// null. Tests point it at a temporary directory.
  SceneStore({required this.codec, String? root}) : _root = root;

  /// Encodes what is written here; the scope's codec.
  final SceneCodec codec;

  final String? _root;

  /// Directory scenes live in.
  String get scenesRoot =>
      _root ?? '${Directory.current.path}/${SceneAssets.directory}';

  String _jsonPath(String name) => '$scenesRoot/$name.scene.json';
  String get _manifestPath => '$scenesRoot/scenes.json';

  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  /// Whether [name] can name a scene file here: one plain file name — not
  /// empty, no `/`, `\` or `:`, no control characters, not `.` or `..`.
  ///
  /// Looser than the rules for naming a new scene (`SceneNames.problem`):
  /// this is what keeps a name read from a file — or a scene copied in by
  /// hand — from reaching outside the scenes and backups folders.
  static bool isFileName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains(RegExp(r'[/\\:\x00-\x1f]'));

  static void _check(String name) {
    if (!isFileName(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Not a scene name: a scene is one file in the scenes folder',
      );
    }
  }

  /// Why the editor cannot write the project here, or null when it can —
  /// found by writing a small file beside the scenes (in the project
  /// folder before there are any) and taking it away again.
  ///
  /// For the editor to say once, when it starts, rather than as a failed
  /// save after an hour's work: a sandboxed macOS debug app may write only
  /// inside its container, and a read-only checkout nowhere.
  String? writeAccessProblem() {
    final scenes = Directory(scenesRoot);
    final dir = scenes.existsSync()
        ? scenes.path
        : (_root ?? Directory.current.path);
    final probe = File('$dir/.editor_write_check_$pid');
    try {
      probe.writeAsStringSync('ok', flush: true);
      probe.deleteSync();
      return null;
    } on FileSystemException catch (e) {
      final why = e.osError?.message ?? e.message;
      return 'The editor cannot save into $dir ($why), so scenes, backups '
          'and the play order cannot be written. '
          '${Platform.isMacOS ? 'A sandboxed macOS app writes only inside its container: set com.apple.security.app-sandbox to false in macos/Runner/DebugProfile.entitlements.' : 'Check that the project folder can be written to.'}';
    }
  }

  Future<void> _ensureRoot() async {
    final dir = Directory(scenesRoot);
    if (!dir.existsSync()) await dir.create(recursive: true);
  }

  // ── Write ────────────────────────────────────────────────────────────────

  /// Creates [sceneName] with a camera and a spawn point, and lists it in the
  /// manifest. Never overwrites a scene that already exists. [mode] is how
  /// it will be authored — 2-D unless 3-D authoring is switched on.
  Future<void> writeInitialFiles(
    String sceneName, {
    SceneMode mode = SceneMode.twoD,
  }) async {
    _check(sceneName);
    await _readManifestStrict();
    await _ensureRoot();
    final file = File(_jsonPath(sceneName));
    if (!file.existsSync()) {
      await ProjectFiles.writeString(
        file.path,
        _buildInitialScene(sceneName, mode),
      );
    }
    await _editManifest((names) {
      if (!names.contains(sceneName)) names.add(sceneName);
    });
  }

  // The starters are shared with `just game scene new`, so a level made either
  // way is the same file (test/scene_starters_parity_test.dart checks they
  // still match the live components, encoded).
  String _buildInitialScene(String sceneName, SceneMode mode) =>
      SceneStarters.encode(SceneStarters.forMode(sceneName, mode: mode.id));

  /// Saves [entities] as [sceneName].
  Future<void> writeJsonSidecar(
    String sceneName,
    EditorScene scene,
    List<Entity> entities,
  ) => writeSceneJson(sceneName, scene, codec.encodeEntities(entities));

  /// Saves already-encoded [entities] as [sceneName] — for writing a snapshot
  /// taken earlier rather than the live world.
  ///
  /// [editor] is saved alongside as the `editor` section — guides, camera
  /// bookmarks — which the game's scene loader ignores.
  ///
  /// The scene is written first; a manifest that cannot be read is then
  /// left as it is, and the [FormatException] says so.
  Future<void> writeSceneJson(
    String sceneName,
    EditorScene scene,
    List<Map<String, dynamic>> entities, {
    Map<String, dynamic>? editor,
  }) async {
    _check(sceneName);
    await _ensureRoot();
    _summaries.remove(sceneName);
    await ProjectFiles.writeString(
      _jsonPath(sceneName),
      encodeScene(scene, entities, editor: editor),
    );
    await _editManifest((names) {
      if (!names.contains(sceneName)) names.add(sceneName);
    });
  }

  /// [scene] with [entities] — and [editor], the section the game ignores
  /// — exactly as its file holds them.
  String encodeScene(
    EditorScene scene,
    List<Map<String, dynamic>> entities, {
    Map<String, dynamic>? editor,
  }) => _pretty.convert({
    'version': SceneFormat.current,
    ...scene.toJson(),
    'entities': entities,
    'editor': ?editor,
  });

  // ── Backups ─────────────────────────────────────────────────────────────

  /// Where backups go: `.editor_backups/` in the project, never under
  /// `assets/`, which ships with the game — or `.backups` under a test's
  /// root. A folder per scene, a file per backup, named by when.
  String get backupsRoot => _root != null
      ? '$_root/.backups'
      : '${Directory.current.path}/.editor_backups';

  /// Where a deleted scene goes, so it can be got back: `.editor_trash/`
  /// in the project (the folder the Assets dock's trash uses), or `.trash`
  /// under a test's root.
  String get trashRoot => _root != null
      ? '$_root/.trash'
      : '${Directory.current.path}/.editor_trash';

  static const String _backupSuffix = '.scene.json';

  /// A backup's name: when it was made, in UTC (`Z`) — or, for one made
  /// before backups were stamped in UTC, local time — then the suffix, and
  /// `.declined` once set aside.
  static final RegExp _backupName = RegExp(
    r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})-(\d{3})(Z?)\.scene\.json'
    r'(\.declined)?$',
  );

  /// When [file] — a backup — was made: from its name, else its date on
  /// disk.
  static DateTime _madeAt(File file) {
    final m = _backupName.firstMatch(file.uri.pathSegments.last);
    if (m == null) {
      try {
        return file.lastModifiedSync().toUtc();
      } on FileSystemException {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }
    final parts = [for (var i = 1; i <= 7; i++) int.parse(m.group(i)!)];
    return m.group(8) == 'Z'
        ? DateTime.utc(
            parts[0],
            parts[1],
            parts[2],
            parts[3],
            parts[4],
            parts[5],
            parts[6],
          )
        : DateTime(
            parts[0],
            parts[1],
            parts[2],
            parts[3],
            parts[4],
            parts[5],
            parts[6],
          ).toUtc();
  }

  /// [files], newest first by when each was made ([_madeAt]).
  static List<File> _newestFirst(Iterable<File> files) {
    final dated = [for (final f in files) (f, _madeAt(f))];
    dated.sort((a, b) {
      final byTime = b.$2.compareTo(a.$2);
      return byTime != 0 ? byTime : b.$1.path.compareTo(a.$1.path);
    });
    return [for (final d in dated) d.$1];
  }

  /// Writes [text] as a backup of [sceneName] and deletes all but the
  /// newest [keep] of its backups.
  ///
  /// Stamped in UTC, so the hour the clocks go back cannot make a later
  /// backup look older. Only backups are pruned — files named as this
  /// writes them — never anything else that happens to be in the folder.
  Future<File> writeBackup(
    String sceneName,
    String text, {
    required int keep,
  }) async {
    _check(sceneName);
    final dir = Directory('$backupsRoot/$sceneName');
    await dir.create(recursive: true);
    final t = DateTime.now().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}-'
        '${t.millisecond.toString().padLeft(3, '0')}Z';
    final file = File('${dir.path}/$stamp$_backupSuffix');
    await ProjectFiles.writeString(file.path, text);
    // Newest first; a backup set aside counts.
    final all = _newestFirst(
      dir.listSync().whereType<File>().where(
        (f) => _backupName.hasMatch(f.uri.pathSegments.last),
      ),
    );
    for (final old in all.skip(keep < 1 ? 1 : keep)) {
      if (old.path == file.path) continue;
      try {
        await old.delete();
      } on FileSystemException {
        // Open elsewhere: it goes next time.
      }
    }
    return file;
  }

  /// The backups of [sceneName] that can be recovered, newest first.
  List<File> backupsOf(String sceneName) {
    if (!isFileName(sceneName)) return const [];
    final dir = Directory('$backupsRoot/$sceneName');
    if (!dir.existsSync()) return const [];
    return _newestFirst(
      dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith(_backupSuffix),
      ),
    );
  }

  /// The newest backup of [sceneName] holding changes that were never
  /// saved: made after the scene file was last written, and not the same.
  /// Null when there is none.
  File? unsavedBackupOf(String sceneName) {
    final backups = backupsOf(sceneName);
    if (backups.isEmpty) return null;
    final latest = backups.first;
    final saved = File(_jsonPath(sceneName));
    try {
      if (saved.existsSync()) {
        if (!latest.lastModifiedSync().isAfter(saved.lastModifiedSync())) {
          return null;
        }
        if (latest.readAsStringSync() == saved.readAsStringSync()) {
          return null;
        }
      }
    } on FileSystemException {
      // Either one unreadable now: offer the backup, the safer mistake.
    }
    return latest;
  }

  /// [backup]'s scene, or null when it cannot be read.
  Future<Map<String, dynamic>?> readBackup(File backup) async {
    try {
      final decoded = jsonDecode(await backup.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  /// Sets [backup] aside: kept on disk, and never offered again.
  Future<void> setAside(File backup) async {
    try {
      await backup.rename('${backup.path}.declined');
    } on FileSystemException {
      // Gone already.
    }
  }

  // ── Delete / rename / duplicate ─────────────────────────────────────────

  /// Takes [name] out of the project and drops it from the manifest. A
  /// missing scene is a no-op.
  ///
  /// The file is not destroyed: it moves to [trashRoot], under the time
  /// it was deleted and its path in the project, where it can be got
  /// back. Returns where it went, or null when there was no file. Its
  /// backups stay where they are.
  Future<String?> deleteSceneFiles(String name) async {
    _check(name);
    await _readManifestStrict();
    final file = File(_jsonPath(name));
    _summaries.remove(name);
    String? kept;
    if (file.existsSync()) {
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      kept = '$trashRoot/$stamp/${SceneAssets.directory}/$name.scene.json';
      await ProjectFiles.rename(file.path, kept);
    }
    await _editManifest((names) => names.remove(name));
    return kept;
  }

  /// Renames [oldName] to [newName], keeping its place in the manifest,
  /// and its backups with it.
  ///
  /// A move, not a copy and a delete, so a change of letter case only
  /// (`level_01` to `Level_01`) works where the file system folds case —
  /// Windows, macOS — instead of deleting the scene. Throws a
  /// [FileSystemException] when another scene already has [newName], or
  /// a case variant of it where case folds.
  Future<void> renameSceneFiles(String oldName, String newName) async {
    _check(oldName);
    _check(newName);
    if (oldName == newName) return;
    await _readManifestStrict();
    _summaries
      ..remove(oldName)
      ..remove(newName);
    final from = _jsonPath(oldName);
    final to = _jsonPath(newName);
    if (File(from).existsSync()) {
      // Refuses — and changes nothing — when something else is at [to].
      await ProjectFiles.rename(from, to);
      await _rename(to, newName);
    } else if (File(to).existsSync()) {
      throw FileSystemException('A scene is already called that', to);
    }
    // Its backups go with it, so recovery still finds them.
    final oldBackups = '$backupsRoot/$oldName';
    final newBackups = '$backupsRoot/$newName';
    if (Directory(oldBackups).existsSync() &&
        (ProjectFiles.samePath(oldBackups, newBackups) ||
            !Directory(newBackups).existsSync())) {
      try {
        await ProjectFiles.rename(oldBackups, newBackups);
      } on FileSystemException {
        // Kept under the old name; the scene itself has moved.
      }
    }
    await _editManifest((names) {
      final i = names.indexOf(oldName);
      if (i >= 0) {
        names[i] = newName;
      } else if (!names.contains(newName)) {
        names.add(newName);
      }
    });
  }

  /// Copies [fromName] to [toName], listed straight after the original.
  ///
  /// Throws a [FileSystemException] — writing nothing — when [toName] is
  /// taken: by another scene, by [fromName] itself, or by a case variant of
  /// either where the file system folds case.
  Future<void> duplicateSceneFiles(String fromName, String toName) async {
    _check(fromName);
    _check(toName);
    final from = _jsonPath(fromName);
    final to = _jsonPath(toName);
    if (fromName == toName ||
        ProjectFiles.samePath(from, to) ||
        FileSystemEntity.typeSync(to) != FileSystemEntityType.notFound) {
      throw FileSystemException('A scene is already called that', to);
    }
    await _readManifestStrict();
    _summaries.remove(toName);
    await _copyScene(fromName, toName);
    await _editManifest((names) {
      if (names.contains(toName)) return;
      final i = names.indexOf(fromName);
      i >= 0 ? names.insert(i + 1, toName) : names.add(toName);
    });
  }

  Future<void> _copyScene(String fromName, String toName) async {
    final from = File(_jsonPath(fromName));
    if (!from.existsSync()) return;
    await _ensureRoot();
    final raw = await from.readAsString();
    final to = _jsonPath(toName);
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) throw const FormatException();
      data['name'] = toName;
      await ProjectFiles.writeString(to, _pretty.convert(data));
    } on FormatException {
      // Not a scene's JSON — keep the content rather than lose it.
      await ProjectFiles.writeString(to, raw);
    }
  }

  /// Writes [name] into the scene file at [path] — after a rename, so the
  /// file says what it is called. A file that is not a scene's JSON is
  /// left as it is.
  Future<void> _rename(String path, String name) async {
    try {
      final data = jsonDecode(await File(path).readAsString());
      if (data is! Map<String, dynamic> || data['name'] == name) return;
      data['name'] = name;
      await ProjectFiles.writeString(path, _pretty.convert(data));
    } on FormatException {
      // Not JSON: the file's name is the scene's name anyway.
    }
  }

  // ── Manifest ─────────────────────────────────────────────────────────────

  /// The manifest's names; none for one missing or unreadable — for
  /// reading only.
  List<String> _readManifest() {
    try {
      final file = File(_manifestPath);
      if (!file.existsSync()) return [];
      return SceneManifest.parse(file.readAsStringSync());
    } on FileSystemException {
      return [];
    } on FormatException {
      return [];
    }
  }

  /// The manifest's names, for changing them: none for a missing (or
  /// empty) file, and a [FormatException] for one that is there but is not
  /// a scene list — rewriting it from nothing would drop the play order.
  Future<List<String>> _readManifestStrict() async {
    final file = File(_manifestPath);
    if (!file.existsSync()) return [];
    final text = await _readText(file);
    if (text.trim().isEmpty) return [];
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException(
        '$_manifestPath cannot be read (${e.message}), so it was left as it '
        'is. Fix or delete it, then try again.',
      );
    }
    if (json is! Map || json['scenes'] is! List) {
      throw FormatException(
        '$_manifestPath is not a scene list ({"scenes": [...]}), so it was '
        'left as it is. Fix or delete it, then try again.',
      );
    }
    return SceneManifest.parse(text);
  }

  /// [file]'s text. A file just written can be held for a moment by
  /// something else on Windows (a virus scanner looking at it): read again
  /// a few times, briefly, before giving up.
  static Future<String> _readText(File file) async {
    for (var tries = 0; ; tries++) {
      try {
        return await file.readAsString();
      } on FileSystemException {
        if (tries >= 4 || !Platform.isWindows) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
  }

  Future<void> _editManifest(void Function(List<String> names) edit) async {
    await _ensureRoot();
    final names = await _readManifestStrict();
    final before = List.of(names);
    edit(names);
    final file = File(_manifestPath);
    if (file.existsSync() && _sameList(before, names)) return;
    await ProjectFiles.writeString(_manifestPath, SceneManifest.encode(names));
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Play order ───────────────────────────────────────────────────────────

  /// The scenes the game plays, in order: the manifest's names that have a
  /// file. The first is where the shipped game starts.
  List<String> playOrder() {
    final onDisk = listSceneNames().toSet();
    return _readManifest().where(onDisk.contains).toList();
  }

  /// Makes [names] the game's play order: the manifest lists exactly these,
  /// in this order. A scene left out stays on disk, unlisted.
  Future<void> writePlayOrder(List<String> names) {
    names.forEach(_check);
    return _editManifest(
      (list) => list
        ..clear()
        ..addAll(names),
    );
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  /// What the Scenes list tells about [name] without opening it: its mode,
  /// how many entities it holds and when it was last saved. Null when the
  /// file is missing; a file that is not a scene's JSON — not JSON at all,
  /// the wrong shape, unreadable — has no mode or count.
  ///
  /// Read at once, like [listSceneNames], so the rows show what is in
  /// them from the first frame — but each file is decoded only when it
  /// changed since it was last read: the list is drawn again after every
  /// rename, duplicate and reorder, and a 3-D level can be megabytes.
  SceneSummary? summaryOf(String name) {
    if (!isFileName(name)) return null;
    final file = File(_jsonPath(name));
    final FileStat stat;
    try {
      stat = file.statSync();
    } on FileSystemException {
      return null;
    }
    if (stat.type != FileSystemEntityType.file) return null;
    final known = _summaries[name];
    if (known != null && known.$1 == stat.modified && known.$2 == stat.size) {
      return known.$3;
    }
    final summary = _readSummary(name, file, stat.modified);
    _summaries[name] = (stat.modified, stat.size, summary);
    return summary;
  }

  /// What [summaryOf] read, by scene name, with the file's date and size
  /// then: used again while both are the same. Every write here drops the
  /// scene's entry as well.
  final Map<String, (DateTime, int, SceneSummary)> _summaries = {};

  SceneSummary _readSummary(String name, File file, DateTime saved) {
    try {
      final json = jsonDecode(file.readAsStringSync());
      final entities = json is Map<String, dynamic> ? json['entities'] : null;
      if (json is! Map<String, dynamic> ||
          (entities != null && entities is! List)) {
        return SceneSummary(name: name, savedAt: saved);
      }
      return SceneSummary(
        name: name,
        mode: SceneMode.fromId(json['mode']),
        entityCount: (entities as List?)?.length ?? 0,
        savedAt: saved,
      );
    } on Object {
      // Not JSON, not UTF-8, gone since: unreadable, not a crash.
      return SceneSummary(name: name, savedAt: saved);
    }
  }

  /// The raw JSON for [sceneName], or null if there is no such file.
  ///
  /// Throws a [FormatException] naming the file when it is there but is
  /// not a scene — not valid JSON (a trailing comma, a merge marker left
  /// in), not UTF-8, or JSON that is not an object. Missing and unreadable
  /// are not the same: a missing scene opens empty, an unreadable one must
  /// not open at all, or the next save would write the empty scene over the
  /// file.
  Future<Map<String, dynamic>?> loadRawSidecar(String sceneName) async {
    if (!isFileName(sceneName)) return null;
    final file = File(_jsonPath(sceneName));
    if (!file.existsSync()) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException catch (error) {
      throw FormatException(
        '${file.path} is not valid JSON: ${error.message}',
        error.source,
        error.offset,
      );
    } on FileSystemException catch (error) {
      throw FormatException(
        '${file.path} cannot be read as text: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('${file.path} does not hold a JSON object.');
    }
    return decoded;
  }

  /// [raw] as its file holds it — for a backup of a scene about to be
  /// rewritten.
  String encodeRawText(Map<String, dynamic> raw) => _pretty.convert(raw);

  /// The raw JSON for [sceneName], read at once — for a check that cannot
  /// wait. Null when it is missing or is not a scene (not valid JSON, or
  /// not an object): a caller that lists scenes it found on disk can tell
  /// the two apart, since those are there.
  Map<String, dynamic>? readRawSync(String sceneName) {
    if (!isFileName(sceneName)) return null;
    final file = File(_jsonPath(sceneName));
    try {
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync());
      return json is Map<String, dynamic> ? json : null;
    } on Object {
      return null;
    }
  }

  /// The scene stored as [sceneName], or null when it is missing or
  /// cannot be read. Its name is [sceneName] — the file's — whatever the
  /// file says inside.
  Future<EditorScene?> loadFromSidecar(String sceneName) async {
    try {
      final raw = await loadRawSidecar(sceneName);
      if (raw == null) return null;
      return EditorScene.fromJson(raw, name: sceneName);
    } on Object {
      return null;
    }
  }

  /// Every scene: manifest order first, then any scene file the manifest
  /// does not list yet — copied in by hand, say — so none are invisible. A
  /// file whose name could not be a scene's ([isFileName]) is left out.
  List<String> listSceneNames() {
    final dir = Directory(scenesRoot);
    if (!dir.existsSync()) return [];
    const suffix = '.scene.json';
    final Set<String> onDisk;
    try {
      onDisk = <String>{
        for (final f in dir.listSync().whereType<File>())
          if (f.uri.pathSegments.last.endsWith(suffix))
            f.uri.pathSegments.last.substring(
              0,
              f.uri.pathSegments.last.length - suffix.length,
            ),
      }..removeWhere((name) => !isFileName(name));
    } on FileSystemException {
      return [];
    }
    final listed = _readManifest().where(onDisk.contains).toList();
    return [...listed, ...(onDisk.difference(listed.toSet()).toList()..sort())];
  }
}

/// A scene as the Scenes list shows it, read from its file.
class SceneSummary {
  const SceneSummary({
    required this.name,
    required this.savedAt,
    this.mode,
    this.entityCount,
  });

  /// The scene's name: its file name without `.scene.json`.
  final String name;

  /// How it is authored; null when the file could not be read.
  final SceneMode? mode;

  /// Every entity in it, children too; null when unreadable.
  final int? entityCount;

  /// When its file was last written.
  final DateTime savedAt;

  /// Whether the file could be read as a scene.
  bool get isReadable => mode != null;
}
