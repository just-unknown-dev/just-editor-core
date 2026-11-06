import 'package:flutter/foundation.dart';
import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;

import '../log/editor_log_service.dart';
import 'editor_module.dart';

/// How a module's mistake is told — one way for every one, whether it
/// threw from a contribution, from `onRegister` or from a lifecycle call —
/// before the editor goes on without it there: in the editor's log (source
/// `editor`, category `modules`) when there is one to write to, else as a
/// Flutter error.
final class ModuleFailureReporter {
  /// A reporter writing to the log [log] returns; one that reports Flutter
  /// errors when [log] is null or returns null — its editor already gone.
  const ModuleFailureReporter({EditorLogService? Function()? log}) : _log = log;

  final EditorLogService? Function()? _log;

  /// Tells that [module] threw [error] while the editor was [doing]
  /// something with it: `onRegister`, `updating`, `opening scene "x"`.
  void report(
    EditorModule module,
    String doing,
    Object error,
    StackTrace stack,
  ) {
    final name = nameOf(module);
    final log = _log?.call();
    if (log != null) {
      log.log(
        'The module "$name" failed ($doing), so the editor goes on without '
        'it there: $error',
        source: 'editor',
        category: 'modules',
        level: DebuggerLogLevel.error,
        details: '$stack',
      );
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'just_editor_core',
        context: ErrorDescription('The module "$name" failed ($doing)'),
      ),
    );
  }

  /// [module]'s id, or — when reading even that throws — its type.
  static String nameOf(EditorModule module) {
    try {
      return module.id;
    } on Object {
      return '${module.runtimeType}';
    }
  }
}
