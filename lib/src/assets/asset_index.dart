import 'dart:async';

import 'package:flutter/foundation.dart';

import '../io/io.dart';
import 'package_asset_paths.dart';
import 'project_files.dart';
import 'asset_kind.dart';

/// One file or folder under the project's assets.
class AssetEntry {
  const AssetEntry({
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.kinds,
  });

  /// Project-relative, forward slashes: `assets/sprites/hero.png`.
  final String path;

  /// Whether it is a folder.
  final bool isDirectory;

  /// The file's size in bytes; 0 for a folder.
  final int size;

  /// When the file last changed on disk; null for a folder.
  final DateTime? modified;

  /// The last part of [path]: `hero.png`.
  String get name => path.substring(path.lastIndexOf('/') + 1);

  /// The folder this sits in; empty for the root.
  String get parent {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  /// The kinds of file [kind] is told by: its index's ([AssetIndex.kinds]),
  /// or, with none, the editor's own.
  final AssetKinds? kinds;

  /// What it is: an image, a scene, a module's model.
  AssetKind get kind =>
      kinds?.of(path, isDirectory: isDirectory) ??
      AssetKinds.editorKindOf(path, isDirectory: isDirectory);

  /// Whether it belongs to an installed package (`packages/…`): listed so
  /// it can be used, but not renamed, moved or deleted here.
  bool get isPackage => AssetIndex.isPackagePath(path);

  /// `12 B`, `3.4 KB`, `1.2 MB`.
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Every file under a project folder, kept current as the disk changes.
///
/// Paths are project-relative with forward slashes — the form components
/// store — so what the browser shows is what an inspector field wants.
class AssetIndex {
  /// An index of [folder] under `projectRoot` (the current directory when
  /// null). Nothing is read until [scan]; [startWatching] keeps it
  /// current.
  AssetIndex({String? projectRoot, this.folder = 'assets', this.kinds})
    : projectRoot = (projectRoot ?? Directory.current.path).replaceAll(
        r'\',
        '/',
      );

  /// The project's folder: absolute, with forward slashes.
  final String projectRoot;

  /// The folder indexed, relative to [projectRoot].
  final String folder;

  /// The kinds of file its entries are told by — an editor's scope's
  /// (`ScopeAssets.assetKinds`), which knows its modules' — or null for the
  /// editor's own.
  final AssetKinds? kinds;

  /// Where deleted files go, so a delete can be taken back.
  static const String trashFolder = '.editor_trash';

  /// The folder installed packages' assets are listed under, as their keys
  /// read: `packages/<name>/…`. It is not a folder on disk.
  static const String packagesFolder = 'packages';

  /// Whether [path] is in [packagesFolder].
  static bool isPackagePath(String path) =>
      path == packagesFolder || path.startsWith('$packagesFolder/');

  /// Where the project's packages are.
  PackageAssetPaths get packages => PackageAssetPaths.of(projectRoot);

  /// Bumped after every scan; what a view listens to.
  final ValueNotifier<int> revision = ValueNotifier(0);

  List<AssetEntry> _entries = const [];

  /// [_entries] by path, and by the folder they are directly in: what the
  /// browser asks many times a frame, answered without a walk.
  Map<String, AssetEntry> _byPath = const {};
  Map<String, List<AssetEntry>> _byParent = const {};
  int _fileCount = 0;

  StreamSubscription<FileSystemEvent>? _watch;

  /// Where one watch cannot see a whole tree (Linux, whose file watching
  /// is not recursive): a watch per folder, by absolute path.
  final Map<String, StreamSubscription<FileSystemEvent>> _folderWatches = {};
  final Map<String, StreamSubscription<FileSystemEvent>> _packageWatches = {};
  Timer? _rescan;
  Future<void>? _scanRunning;
  Completer<void>? _scanAgain;
  bool _disposed = false;

  /// Whether one watch of a folder hears about everything under it. Not on
  /// Linux, where `Directory.watch(recursive: true)` only hears the
  /// folder's own entries.
  static bool get _watchesTrees => !Platform.isLinux;

  /// Every file and folder the last [scan] found, installed packages' under
  /// [packagesFolder] among them: folders first, then by path ignoring
  /// case.
  List<AssetEntry> get entries => _entries;

  /// How many of [entries] are files rather than folders.
  int get fileCount => _fileCount;

  /// Whether any installed package ships assets.
  bool get hasPackages => _byPath.containsKey(packagesFolder);

  /// The file or folder at [relative]: in the project, or — for
  /// `packages/<name>/…` — in that package's folder.
  String absolute(String relative) => packages.absolute(relative);

  /// [absolutePath] as a project-relative path with forward slashes;
  /// unchanged, apart from the slashes, when it is outside [projectRoot].
  String relative(String absolutePath) {
    final p = absolutePath.replaceAll(r'\', '/');
    return p.startsWith('$projectRoot/')
        ? p.substring(projectRoot.length + 1)
        : p;
  }

  /// Reads the folder. Overlapping calls fold into one more pass.
  ///
  /// What it returns completes once a walk that began after the call has
  /// finished: one asked for while another walk is under way — which may
  /// have passed what just changed — waits for the next walk, so whoever
  /// renamed a file and rescans sees the rename.
  ///
  /// Never throws: a folder that cannot be read — deleted mid-walk, no
  /// permission — is reported and left out, and the index keeps what it
  /// had when the whole walk fails. Nothing happens once [dispose]d.
  Future<void> scan() {
    if (_disposed) return Future<void>.value();
    if (_scanRunning != null) {
      return (_scanAgain ??= Completer<void>()).future;
    }
    final walk = _walk();
    _scanRunning = walk;
    walk.whenComplete(() {
      _scanRunning = null;
      final again = _scanAgain;
      _scanAgain = null;
      if (again == null) return;
      if (_disposed) {
        again.complete();
      } else {
        scan().whenComplete(again.complete);
      }
    });
    return walk;
  }

  Future<void> _walk() async {
    try {
      final found = <AssetEntry>[];
      final root = Directory(absolute(folder));
      if (await root.exists()) {
        final listing = root
            .list(recursive: true, followLinks: false)
            // One folder that cannot be read leaves out what is in it, not
            // the rest of the walk.
            .handleError(
              (Object _) {},
              test: (error) => error is FileSystemException,
            );
        await for (final e in listing) {
          final path = relative(e.path);
          if (e is Directory) {
            found.add(AssetEntry(path: path, isDirectory: true, kinds: kinds));
          } else if (e is File) {
            try {
              final stat = await e.stat();
              found.add(
                AssetEntry(
                  path: path,
                  isDirectory: false,
                  size: stat.size,
                  modified: stat.modified,
                  kinds: kinds,
                ),
              );
            } on FileSystemException {
              // Gone between the listing and the stat: skip it.
            }
          }
        }
      }
      found.addAll(await _scanPackages());
      if (_disposed) return;
      found.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      _entries = List.unmodifiable(found);
      _byPath = {for (final e in found) e.path: e};
      final byParent = <String, List<AssetEntry>>{};
      for (final e in found) {
        (byParent[e.parent] ??= []).add(e);
      }
      _byParent = byParent;
      _fileCount = found.where((e) => !e.isDirectory).length;
      revision.value++;
    } catch (error, stack) {
      // From a timer, nobody would hear it: say it, and keep what was
      // known. The next change on disk, or Refresh, tries again.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'just_editor_core',
          context: ErrorDescription('while listing the project\'s assets'),
        ),
      );
    }
  }

  /// The installed packages' shipped files, under [packagesFolder]: each
  /// package, its asset folders, and the files directly in them (Flutter
  /// ships no deeper).
  Future<List<AssetEntry>> _scanPackages() async {
    // Looked at again now — not read again unless the store's lockfile,
    // pub's package list or a project package's pubspec changed.
    packages.checkForChanges();
    final out = <AssetEntry>[];
    final folders = <String>{};
    void folderAt(String path) {
      var at = path;
      while (at.isNotEmpty && folders.add(at)) {
        out.add(AssetEntry(path: at, isDirectory: true, kinds: kinds));
        final i = at.lastIndexOf('/');
        at = i < 0 ? '' : at.substring(0, i);
      }
    }

    for (final pkg in packages.withAssets) {
      for (final assetFolder in pkg.assetFolders) {
        if (!assetFolder.endsWith('/')) continue;
        final dir = Directory('${pkg.path}/$assetFolder');
        if (!await dir.exists()) continue;
        final key =
            '$packagesFolder/${pkg.name}/'
            '${assetFolder.substring(0, assetFolder.length - 1)}';
        folderAt(key);
        try {
          await for (final f in dir.list(followLinks: false)) {
            if (f is! File) continue;
            final stat = await f.stat();
            out.add(
              AssetEntry(
                path: '$key/${f.uri.pathSegments.last}',
                isDirectory: false,
                size: stat.size,
                modified: stat.modified,
                kinds: kinds,
              ),
            );
          }
        } on FileSystemException {
          // Unreadable: nothing from it.
        }
      }
    }
    return out;
  }

  /// Rescans, shortly, whenever something under the folder changes — a save
  /// from the sprite editor, a file dropped in from outside — or a package
  /// is installed, updated or removed.
  void startWatching() {
    if (_watch != null || _disposed) return;
    final root = Directory(absolute(folder));
    if (!root.existsSync()) return;
    try {
      _watch = root.watch(recursive: _watchesTrees).listen((_) {
        _soon();
      }, onError: (_) {});
      // The store's lockfile and pub's package list say which packages
      // there are.
      for (final (dir, name) in [
        (projectRoot, 'just_store.lock.json'),
        ('$projectRoot/.dart_tool', 'package_config.json'),
      ]) {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        _packageWatches['#$dir'] = d.watch().listen((e) {
          if (e.path.replaceAll(r'\', '/').endsWith('/$name')) _soon();
        }, onError: (_) {});
      }
    } on FileSystemException {
      // Watching is a convenience; Refresh still works.
    }
    _watchFolders();
    _watchPackages();
    revision.addListener(_watchFolders);
    revision.addListener(_watchPackages);
  }

  void _soon() {
    if (_disposed) return;
    _rescan?.cancel();
    _rescan = Timer(const Duration(milliseconds: 250), () => unawaited(scan()));
  }

  /// Where one watch does not see a whole tree, watches every folder under
  /// the indexed one — as each scan finds them, so a folder made later is
  /// heard too — and lets go of the ones gone.
  void _watchFolders() {
    if (_watchesTrees || _watch == null || _disposed) return;
    final wanted = {
      for (final e in _entries)
        if (e.isDirectory && !isPackagePath(e.path)) absolute(e.path),
    };
    for (final path in _folderWatches.keys.toList()) {
      if (!wanted.contains(path)) _folderWatches.remove(path)?.cancel();
    }
    for (final path in wanted) {
      if (_folderWatches.containsKey(path)) continue;
      final dir = Directory(path);
      if (!dir.existsSync()) continue;
      try {
        _folderWatches[path] = dir.watch().listen(
          (_) => _soon(),
          onError: (_) {},
        );
      } on FileSystemException {
        // Refresh still works.
      }
    }
  }

  /// Watches the folders of the packages inside the project (the store's
  /// items), so an edit there shows like one under assets/.
  void _watchPackages() {
    if (_disposed) return;
    final wanted = <String>{
      for (final p in packages.withAssets)
        if (!p.inPubCache)
          // Only the files directly in an asset folder ship; where a watch
          // is not recursive, those folders are the ones to watch.
          if (_watchesTrees)
            p.path
          else
            for (final f in p.assetFolders)
              if (f.endsWith('/')) '${p.path}/${f.substring(0, f.length - 1)}',
    };
    for (final path in _packageWatches.keys.toList()) {
      if (path.startsWith('#') || wanted.contains(path)) continue;
      _packageWatches.remove(path)?.cancel();
    }
    for (final path in wanted) {
      if (_packageWatches.containsKey(path)) continue;
      final dir = Directory(path);
      if (!dir.existsSync()) continue;
      try {
        _packageWatches[path] = dir
            .watch(recursive: _watchesTrees)
            .listen((_) => _soon(), onError: (_) {});
      } on FileSystemException {
        // Refresh still works.
      }
    }
  }

  /// What is directly inside [dir].
  List<AssetEntry> childrenOf(String dir) =>
      List.unmodifiable(_byParent[dir] ?? const <AssetEntry>[]);

  /// Files under [within] matching [query] (in the name) and [kinds] (any,
  /// when empty).
  List<AssetEntry> search(
    String query, {
    Set<AssetKind> kinds = const {},
    String? within,
  }) {
    final q = query.trim().toLowerCase();
    return [
      for (final e in _entries)
        if (!e.isDirectory &&
            (within == null || e.path.startsWith('$within/')) &&
            (kinds.isEmpty || kinds.contains(e.kind)) &&
            (q.isEmpty || e.name.toLowerCase().contains(q)))
          e,
    ];
  }

  /// The file or folder at the project-relative [path], or null when the
  /// last [scan] found none there.
  AssetEntry? entryAt(String path) => _byPath[path];

  // ── Operations ───────────────────────────────────────────────────────────

  /// A name in [dir] that is not taken: `name`, `name 2`, `name 3`…
  String freeName(String dir, String name) {
    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    final ext = dot <= 0 ? '' : name.substring(dot);
    var candidate = name, n = 2;
    while (FileSystemEntity.typeSync(absolute(_join(dir, candidate))) !=
        FileSystemEntityType.notFound) {
      candidate = '$stem $n$ext';
      n++;
    }
    return candidate;
  }

  /// [name] in [dir]; just [name] at the top (an empty [dir]).
  static String _join(String dir, String name) =>
      dir.isEmpty ? name : '$dir/$name';

  /// The folder [path] is in; empty for a path at the top.
  static String _parentOf(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  static void _writable(String path) {
    if (isPackagePath(path)) {
      throw FileSystemException(
        "An installed package's files can't be changed here",
        path,
      );
    }
  }

  /// [_writable], for something that is moved, copied or thrown away: a
  /// file or folder inside the indexed folder, never that folder itself.
  static void _movable(String path) {
    _writable(path);
    if (!path.contains('/')) {
      throw FileSystemException("This folder can't be changed here", path);
    }
  }

  /// Makes a folder called [name] in [dir] — or `name 2`, `name 3`… when
  /// that is taken ([freeName]) — rescans, and returns its path. Throws
  /// [FileSystemException] inside an installed package.
  Future<String> newFolder(String dir, {String name = 'New folder'}) async {
    _writable(dir);
    final path = _join(dir, freeName(dir, name));
    await Directory(absolute(path)).create(recursive: true);
    await scan();
    return path;
  }

  /// Renames [path] to [newName] in the same folder. Throws
  /// [FileSystemException] when the name is taken or not a name.
  ///
  /// A change of letter case only (`hero.png` to `Hero.png`) is a rename
  /// too, also where the file system folds case (Windows, macOS) and the
  /// two names are one file.
  Future<String> rename(String path, String newName) async {
    _movable(path);
    final name = newName.trim();
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains(r'\')) {
      throw FileSystemException('Not a file name', name);
    }
    final target = _join(_parentOf(path), name);
    if (target == path) return path;
    final caseOnly = ProjectFiles.samePath(absolute(target), absolute(path));
    if (!caseOnly &&
        FileSystemEntity.typeSync(absolute(target)) !=
            FileSystemEntityType.notFound) {
      throw FileSystemException('There is already a "$name" here', target);
    }
    await ProjectFiles.rename(absolute(path), absolute(target));
    await scan();
    return target;
  }

  /// Copies the file at [path] beside it as `name copy.ext` — or a free
  /// variant of that ([freeName]) — rescans, and returns the copy's path.
  /// Throws [FileSystemException] for an installed package's file.
  Future<String> duplicate(String path) async {
    _movable(path);
    final parent = _parentOf(path);
    final name = path.substring(path.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    final copyName = dot <= 0
        ? '$name copy'
        : '${name.substring(0, dot)} copy${name.substring(dot)}';
    final target = _join(parent, freeName(parent, copyName));
    await File(absolute(path)).copy(absolute(target));
    await scan();
    return target;
  }

  /// Moves [path] into the project's trash folder rather than deleting it.
  /// The result restores it.
  Future<TrashedAsset> trash(String path) async {
    _movable(path);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final kept = '$trashFolder/$stamp/$path';
    final isDir = FileSystemEntity.isDirectorySync(absolute(path));
    await Directory(absolute(_parentOf(kept))).create(recursive: true);
    isDir
        ? await Directory(absolute(path)).rename(absolute(kept))
        : await File(absolute(path)).rename(absolute(kept));
    await scan();
    return TrashedAsset._(this, path, kept, isDir);
  }

  /// Shows [path] in the system's file manager. Whether one could be
  /// started — false, and nothing thrown, where there is none (a Linux
  /// desktop without `xdg-open`).
  Future<bool> reveal(String path) {
    final target = absolute(path);
    if (Platform.isWindows) {
      return _start('explorer', ['/select,', target.replaceAll('/', r'\')]);
    }
    if (Platform.isMacOS) return _start('open', ['-R', target]);
    return _start('xdg-open', [File(target).parent.path]);
  }

  /// Opens [path] with whatever the system associates with it. Whether a
  /// program could be started — false, and nothing thrown, where none can.
  ///
  /// Never through a shell: on Windows the path goes to Explorer as one
  /// argument, so a file name holding `&`, `|`, `^` or `%NAME%` is a name
  /// and nothing else, never run as a command.
  Future<bool> openExternally(String path) {
    final target = absolute(path);
    if (Platform.isWindows) {
      return _start('explorer.exe', [target.replaceAll('/', r'\')]);
    }
    if (Platform.isMacOS) return _start('open', [target]);
    return _start('xdg-open', [target]);
  }

  static Future<bool> _start(String program, List<String> arguments) async {
    try {
      await Process.run(program, arguments);
      return true;
    } on Exception catch (e) {
      // No such program here (a ProcessException), or it could not start.
      debugPrint('Could not start $program: $e');
      return false;
    }
  }

  /// Stops watching the disk and drops any rescan still to come; [scan]
  /// does nothing afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rescan?.cancel();
    _watch?.cancel();
    for (final w in _folderWatches.values) {
      w.cancel();
    }
    _folderWatches.clear();
    for (final w in _packageWatches.values) {
      w.cancel();
    }
    _packageWatches.clear();
    revision.dispose();
  }
}

/// A file in the trash, able to come back.
class TrashedAsset {
  TrashedAsset._(this._index, this.originalPath, this._keptAt, this._isDir);

  final AssetIndex _index;

  /// Where it was before it went to the trash, project-relative.
  final String originalPath;
  final String _keptAt;
  final bool _isDir;

  /// Puts it back where it was; under a free name if that is taken now.
  Future<String> restore() async {
    final parent = AssetIndex._parentOf(originalPath);
    final name = originalPath.substring(originalPath.lastIndexOf('/') + 1);
    final target = AssetIndex._join(parent, _index.freeName(parent, name));
    await Directory(_index.absolute(parent)).create(recursive: true);
    _isDir
        ? await Directory(
            _index.absolute(_keptAt),
          ).rename(_index.absolute(target))
        : await File(_index.absolute(_keptAt)).rename(_index.absolute(target));
    await _index.scan();
    return target;
  }
}
