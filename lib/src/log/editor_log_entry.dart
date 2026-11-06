import 'package:flutter/foundation.dart';
import 'package:just_debugger/just_debugger.dart';

/// One line of the editor log: what the Console dock lists, and one JSON
/// line of the saved log file.
@immutable
class EditorLogEntry {
  const EditorLogEntry({
    required this.message,
    required this.source,
    required this.category,
    required this.level,
    required this.timestamp,
    this.details,
  });

  /// The line itself, trimmed.
  final String message;

  /// Where it came from: `editor` (the default), `console` for prints,
  /// `flutter` and `dart` for errors, or the part that logged it
  /// (`profiler`, `assets`, a module's own name).
  final String source;

  /// What kind of line it is within [source]: `general`, `print`,
  /// `debugPrint`, `framework`, `uncaught` and so on.
  final String category;

  /// How serious it is; errors also reach `EditorLogService.onError`.
  final DebuggerLogLevel level;

  /// When it was logged, in local time.
  final DateTime timestamp;

  /// More to read under the line, such as a stack trace or Flutter's
  /// error report; null for none.
  final String? details;

  /// The time of day of [timestamp], `HH:mm:ss`.
  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// The entry as one line of the log file stores it; [level] by name and
  /// [timestamp] as ISO 8601.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'message': message,
    'source': source,
    'category': category,
    'level': level.name,
    'timestamp': timestamp.toIso8601String(),
    'details': details,
  };

  /// Reads back what [toJson] wrote. Missing fields fall back rather than
  /// throw: an empty message, `general` source and category, the info
  /// level, and the epoch for a timestamp that does not parse.
  factory EditorLogEntry.fromJson(Map<String, dynamic> json) {
    return EditorLogEntry(
      message: json['message'] as String? ?? '',
      source: json['source'] as String? ?? 'general',
      category: json['category'] as String? ?? 'general',
      level: _parseLevel(json['level'] as String?),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      details: json['details'] as String?,
    );
  }

  static DebuggerLogLevel _parseLevel(String? raw) {
    return DebuggerLogLevel.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => DebuggerLogLevel.info,
    );
  }
}
