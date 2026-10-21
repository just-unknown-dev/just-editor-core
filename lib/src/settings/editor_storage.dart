/// Where the editor keeps what it remembers for the person using it — not
/// exported.
///
/// The folder of the editor's file is found by a plugin that needs the VM's
/// file system. It is reached only through `editor_storage_io.dart`, behind
/// the conditional import below (on `dart.library.io`), so a web build never
/// imports it.
library;

import 'package:just_storage/just_storage.dart';

import 'editor_storage_web.dart'
    if (dart.library.io) 'editor_storage_io.dart'
    as platform;

/// Opens the editor's own key-value store: its settings, the recent
/// colours, and what each module keeps in the editor's preferences.
///
/// On desktop it is a file of its own,
/// `<application support>/just_game_editor/just_storage.json` — beside the
/// `just_storage.json` a game opens with `JustStorage.standard()`, not in
/// it. `just_storage` rewrites a whole file from the copy one instance
/// loaded, so two instances on one file drop each other's keys: the
/// editor's settings and the game's saves must not share one. What an
/// editor kept in that shared file before is moved out of it the first
/// time ([moveEditorKeys]).
///
/// A scope opens it once and hands the same store to everything that keeps
/// something in it, for the same reason.
Future<JustStandardStorage> openEditorStorage() => platform.openEditorStorage();

/// What the keys the editor writes start with: its own settings and the
/// built-in modules' (`editor.overlay.textScale`, `editor.store.sources`).
const String editorKeyPrefix = 'editor.';

/// The key in the editor's own store that says the move out of the shared
/// store is done.
const String movedOutKey = 'editor.storage.movedOut';

/// Moves the editor's keys ([editorKeyPrefix]) out of the store it shared
/// with the game before — opened by [shared] — into [own], and removes them
/// from the shared one: once, after which [own] remembers it was done and
/// the shared store is never opened again.
///
/// A key [own] already has keeps its value there (it is the newer); the
/// shared copy is removed all the same. Every other key — the game's — is
/// left as it is. A step that fails leaves the mark unset, so the whole move
/// is tried again next time; it is safe to repeat.
Future<void> moveEditorKeys({
  required Future<JustStandardStorage> Function() shared,
  required JustStandardStorage own,
}) async {
  try {
    if (await own.read(movedOutKey) != null) return;
    final from = await shared();
    if (!identical(from, own)) {
      final entries = await from.readAll();
      for (final MapEntry(:key, :value) in entries.entries) {
        if (!key.startsWith(editorKeyPrefix)) continue;
        if (!await own.containsKey(key)) await own.write(key, value);
        await from.delete(key);
      }
    }
    await own.write(movedOutKey, '1');
  } on Object {
    // Tried again next time: until then the editor starts from its own
    // store, and the old settings wait where they were.
  }
}
