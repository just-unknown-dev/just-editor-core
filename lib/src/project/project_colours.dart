/// The colours the editor's pickers offer, as the editor keeps them.
library;

import 'dart:async';
import 'dart:convert';

import 'package:just_colours/just_colours.dart';
import 'package:just_storage/just_storage.dart';

import '../../io.dart';
import '../services/project_files.dart';

/// The palettes and gradients a project keeps, and the colours this user
/// picked lately — one [ColourLibrary] for every colour picker in the
/// editor.
///
/// Palettes and gradients belong to the game, so they are written to the
/// project's palette file ([defaultPath]) on every change and travel with
/// it. Recent colours are one person's, so they stay in this machine's
/// storage. Until a palette or gradient is saved there is no file.
class ProjectColours {
  /// The palettes kept in the file at [path], and the recent colours in
  /// what `storage` opens — kept nowhere when null, as in a test.
  /// `onProblem` is told, in words, of each read or write of the file that
  /// fails. Nothing is read until [load].
  ProjectColours({
    required this.path,
    Future<JustStandardStorage> Function()? storage,
    void Function(String problem)? onProblem,
  }) : _storage = storage,
       _onProblem = onProblem;

  /// Where in a project its palette file is.
  static const String defaultPath = 'assets/project/palettes.json';

  /// The palette file of the project the editor runs in — or, for a store
  /// rooted elsewhere (a test's temporary directory), `palettes.json` there.
  static String pathFor({String? scenesRoot}) => scenesRoot == null
      ? '${Directory.current.path}/$defaultPath'
      : '$scenesRoot/palettes.json';

  static const String _recentsKey = 'editor.colour_picker.recents';

  /// Where the palette file is.
  final String path;

  final Future<JustStandardStorage> Function()? _storage;

  /// The store, opened once when first needed. A store that cannot be
  /// reached — no platform to ask where, in a test — fails quietly.
  late final Future<JustStandardStorage>? _store = () {
    final open = _storage;
    if (open == null) return null;
    try {
      return open()..ignore();
    } catch (_) {
      return null;
    }
  }();

  /// What the pickers read and change.
  final ColourLibrary library = ColourLibrary();

  /// What went wrong reading or writing the palette file, or null.
  String? get error => _error;
  String? _error;

  /// Whether the palette file is there but could not be read — broken JSON,
  /// not palettes at all, unreadable — so it is left as it is: nothing is
  /// written over it, and a change to the palettes is taken back, until it
  /// reads ([load]).
  bool get isUnreadable => _unreadable;
  bool _unreadable = false;

  final void Function(String problem)? _onProblem;

  /// The palettes as the file last held them: what a change that could not
  /// be saved goes back to.
  Map<String, dynamic> _saved = const {};

  bool _loading = false;
  bool _following = false;

  /// Reads the palette file and this user's recent colours, then follows
  /// every change.
  ///
  /// A file that is there but cannot be read is left as it is: the pickers
  /// offer no palettes, [error] says why, and a change to them is taken
  /// back ([isUnreadable]) until the file is fixed and read again.
  void load() {
    _loading = true;
    _error = null;
    _unreadable = false;
    final file = File(path);
    try {
      if (file.existsSync()) {
        final json = jsonDecode(file.readAsStringSync());
        if (json is! Map<String, dynamic>) {
          throw const FormatException('it does not hold a JSON object');
        }
        library.loadCollections(json);
        _saved = library.collectionsToJson();
      }
    } on Object catch (e) {
      _unreadable = true;
      _saved = const {};
      // What was read before it failed is not offered: it is not the file.
      try {
        library.loadCollections(const {});
      } on Object {
        // An empty library always loads.
      }
      final why = switch (e) {
        FormatException(:final message) =>
          'The palette file is not valid: $message',
        FileSystemException(:final message) => 'Could not read $path: $message',
        _ => 'The palette file is not valid: $e',
      };
      _error =
          '$why It is left as it is: fix it and read it again to change '
          'palettes.';
      _onProblem?.call(_error!);
    } finally {
      _loading = false;
    }
    if (_following) return;
    _following = true;
    library.collectionsChanged.addListener(_writeCollections);
    library.recentsChanged.addListener(_writeRecents);
    unawaited(_readRecents());
  }

  void _writeCollections() {
    if (_loading) return;
    if (_unreadable) {
      _takeBack(_error!);
      return;
    }
    final json = library.collectionsToJson();
    final text = const JsonEncoder.withIndent('  ').convert(json);
    try {
      ProjectFiles.writeStringSync(path, '$text\n');
    } on Object catch (e) {
      _takeBack(
        'Could not write $path: ${e is FileSystemException ? e.message : e}',
      );
      return;
    }
    _error = null;
    _saved = json;
  }

  /// A change that could not be saved, taken back — so what the pickers
  /// show is what the file holds — and [problem] said.
  void _takeBack(String problem) {
    _error = problem;
    _loading = true;
    try {
      library.loadCollections(_saved);
    } finally {
      _loading = false;
    }
    _onProblem?.call(problem);
  }

  Future<void> _readRecents() async {
    final store = _store;
    if (store == null) return;
    try {
      final raw = await (await store).read(_recentsKey);
      if (raw == null) return;
      final json = jsonDecode(raw.toString());
      // Colours picked before the store answered come first.
      final picked = library.recentColours;
      if (json is Map<String, dynamic>) library.loadRecents(json);
      if (picked.isNotEmpty) library.addRecentColours(picked);
    } catch (_) {
      // Recent colours are a convenience: without the store there are none
      // from before, and that is all.
    }
  }

  void _writeRecents() {
    final store = _store;
    if (store == null) return;
    final text = jsonEncode(library.recentsToJson());
    unawaited(() async {
      try {
        await (await store).write(_recentsKey, text);
      } catch (_) {
        // As for reading: no store, no recent colours kept.
      }
    }());
  }

  /// Stops following [library]'s changes and disposes it; the scope that
  /// made this calls it.
  void dispose() {
    library.collectionsChanged.removeListener(_writeCollections);
    library.recentsChanged.removeListener(_writeRecents);
    library.dispose();
  }
}
