/// Limits of the editor's log: the lines it keeps and the file it writes.
abstract final class EditorLogConstants {
  /// Lines the log keeps until the Console's Lines kept setting is applied;
  /// the oldest go first.
  static const int maxEntries = 1000;

  /// Maximum file size in bytes before the log is rotated (~5 MB).
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Number of backup files to keep alongside the primary log.
  static const int maxBackupFiles = 2;
}
