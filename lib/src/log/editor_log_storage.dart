import 'editor_log_storage_stub.dart'
    if (dart.library.io) 'editor_log_storage_io.dart';

import 'editor_log_entry.dart';

/// Where the editor log's lines are kept between runs.
///
/// With `dart:io`, a JSON-lines file, one [EditorLogEntry] per line:
/// `.editor_logs/editor_runtime.jsonl` in the working directory on a
/// desktop, in the app's support folder on Android and iOS, rotated into
/// `.1.bak` files when it grows large. On the web nothing is kept.
abstract interface class EditorLogStorage {
  /// The log file's path; null on the web, and until the first load or
  /// append has found the file.
  String? get filePath;

  /// Every saved entry, oldest first. A missing file gives none, and lines
  /// that do not parse are skipped.
  Future<List<EditorLogEntry>> loadEntries();

  /// Saves [entry] after every line before it. Completes once it, and
  /// whatever queued behind it, is written.
  Future<void> appendEntry(EditorLogEntry entry);

  /// Removes every saved entry, and the file's backups.
  Future<void> clear();
}

/// The storage for this platform: the log file with `dart:io`, nothing on
/// the web.
EditorLogStorage createEditorLogStorage() => createEditorLogStorageImpl();
