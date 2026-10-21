import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_debugger/just_debugger.dart';
import 'package:just_signals/just_signals.dart';

import '../look/editor_constants.dart';
import 'editor_log_entry.dart';
import 'editor_log_storage.dart';

typedef _PlatformErrorHandler = bool Function(Object error, StackTrace stack);

/// The editor's log: what the Console dock lists.
///
/// Holds the lines the editor and its modules [log] and, while a session
/// runs ([EditorLogSession.startSession]), every print, Flutter error and
/// uncaught error. Keeps the newest [maxEntries], and saves each line to an
/// [EditorLogStorage], whose lines the next session reads back.
class EditorLogService {
  /// A log service over the platform's default storage. One per editor
  /// scope; there is no process-wide instance.
  EditorLogService({EditorLogStorage? storage})
    : _storage = storage ?? createEditorLogStorage();

  final EditorLogStorage _storage;
  final List<EditorLogEntry> _entries = <EditorLogEntry>[];

  JustDebuggerController? _controller;
  DebugPrintCallback? _previousDebugPrint;
  FlutterExceptionHandler? _previousFlutterError;
  _PlatformErrorHandler? _previousPlatformError;
  String? _activeConsoleCategory;
  bool _sessionActive = false;
  bool _globalCaptureInstalled = false;
  bool _zoneCaptureInstalled = false;
  bool _keepGlobalCaptureInstalled = false;
  bool _loadedPersistedEntries = false;
  // Set on the first storage write failure (e.g. read-only/full disk) so we
  // stop retrying for the rest of the session. Without this, a failing
  // appendEntry() would otherwise get reported right back through log() ->
  // appendEntry() on every call, spiralling into an ever-growing chain of
  // "failed to persist log" entries that themselves fail to persist.
  bool _storageWriteFailed = false;

  // Deferred notification state — prevents "Build scheduled during frame" when
  // log() is called during Flutter's transient/persistent callback phases
  // (e.g. from an ECS system running on the vsync Ticker).
  bool _flushScheduled = false;
  final List<VoidCallback> _pendingNotifies = [];

  // Whether the deferred flush publishes [entries]: once for every line
  // logged during the frame, not once per line — each publish copies the
  // whole log, up to its many thousand lines.
  bool _publishPending = false;

  bool _disposed = false;

  // What this service put in place of the global hooks, to tell whether
  // they are still its own when it goes.
  DebugPrintCallback? _ownDebugPrint;
  FlutterExceptionHandler? _ownFlutterError;
  _PlatformErrorHandler? _ownPlatformError;

  /// Every entry, oldest first: a new list on every change, so a dock
  /// can watch it.
  final Signal<List<EditorLogEntry>> entries = Signal(
    const [],
    debugLabel: 'logEntries',
  );

  void _publish() {
    if (_disposed) return;
    entries.value = List<EditorLogEntry>.unmodifiable(_entries);
  }

  // ── Frame-safe notification ────────────────────────────────────────────────

  /// True when the Dart scheduler is in a build/layout/paint or transient
  /// callback phase — i.e. when calling [setState] would throw
  /// "Build scheduled during frame".
  bool get _isInsideFrame {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      return phase != SchedulerPhase.idle &&
          phase != SchedulerPhase.postFrameCallbacks;
    } catch (_) {
      return false;
    }
  }

  /// Runs [work] immediately when safe, or defers it to a single post-frame
  /// callback when called during a Flutter frame (e.g. from an ECS system
  /// running on the vsync Ticker).  Multiple in-frame calls are batched into
  /// one post-frame flush so only a single rebuild is scheduled.
  ///
  /// With [publish], [entries] is published after [work] — in a frame, once
  /// at the flush however many calls asked.
  void _scheduleNotify(VoidCallback work, {bool publish = false}) {
    if (!_isInsideFrame) {
      work();
      if (publish) _publish();
      return;
    }
    _pendingNotifies.add(work);
    if (publish) _publishPending = true;
    if (!_flushScheduled) {
      _flushScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _flushScheduled = false;
        final pending = List<VoidCallback>.from(_pendingNotifies);
        _pendingNotifies.clear();
        for (final fn in pending) {
          fn();
        }
        if (_publishPending) {
          _publishPending = false;
          _publish();
        }
      });
    }
  }

  /// Runs [action] with every print, Flutter error and uncaught error in
  /// it captured into the log, whether or not a session is running.
  @visibleForTesting
  Future<T> runWithCapture<T>(Future<T> Function() action) async {
    _keepGlobalCaptureInstalled = true;
    _installGlobalCapture();

    if (_zoneCaptureInstalled) {
      return action();
    }

    _zoneCaptureInstalled = true;
    final completer = Completer<T>();

    await runZonedGuarded(
      () async {
        final result = await action();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      },
      (Object error, StackTrace stack) {
        _recordUnhandledError(error, stack, source: 'dart', category: 'zone');
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          parent.print(zone, line);
          _recordConsoleLine(line, category: _activeConsoleCategory ?? 'print');
        },
      ),
    );

    return completer.future;
  }

  Future<void> _startSession({
    required JustDebuggerController controller,
  }) async {
    _controller = controller;

    if (!_loadedPersistedEntries) {
      _loadedPersistedEntries = true;
      final restored = await _storage.loadEntries();
      _entries
        ..clear()
        ..addAll(_mergeEntries(restored, _entries));
      _publish();
    }

    if (_sessionActive) {
      return;
    }
    _sessionActive = true;
    _installGlobalCapture();
    log(
      'Editor log capture session started.',
      source: 'session',
      category: 'lifecycle',
      mirrorToDebugger: false,
    );
  }

  void _stopSession() {
    if (!_sessionActive) {
      _controller = null;
      return;
    }
    _sessionActive = false;
    if (!_keepGlobalCaptureInstalled) {
      _restoreGlobalCapture();
    }
    _controller = null;
  }

  /// Adds a line to the log: [message], trimmed (an empty one is dropped),
  /// from [source], in [category], at [level], with [details] such as a
  /// stack trace (see [EditorLogEntry]).
  ///
  /// The line is saved to the storage and, with [mirrorToDebugger], shown
  /// in the debugger's console while a session runs. An error also goes to
  /// the [onError] listeners. Safe to call during a frame: watchers of
  /// [entries] hear of it after the frame.
  void log(
    String message, {
    String source = 'editor',
    String category = 'general',
    DebuggerLogLevel level = DebuggerLogLevel.info,
    String? details,
    bool mirrorToDebugger = true,
  }) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    final entry = EditorLogEntry(
      message: normalized,
      source: source,
      category: category,
      level: level,
      timestamp: DateTime.now(),
      details: details,
    );

    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    if (level == DebuggerLogLevel.error) {
      for (final listener in List.of(_errorListeners)) {
        listener(entry);
      }
    }

    if (!_storageWriteFailed) {
      unawaited(
        _storage.appendEntry(entry).catchError((Object error, StackTrace _) {
          // Flip the flag before logging the notice below — its own log()
          // call must see _storageWriteFailed already true so it doesn't
          // attempt (and fail) another appendEntry itself.
          _storageWriteFailed = true;
          debugPrint(
            '[EditorLogService] Disabling log persistence after a write '
            'failure: $error',
          );
        }),
      );
    }

    _scheduleNotify(() {
      if (mirrorToDebugger) {
        _controller?.log(normalized, category: source, level: level);
      }
    }, publish: true);
  }

  /// Forgets every line, here and in the debugger's console, and empties
  /// the storage.
  Future<void> clear() async {
    _entries.clear();
    _scheduleNotify(() {
      _controller?.clearLogs();
      _publish();
    });
    await _storage.clear();
  }

  /// Back to a new service's state, for tests: no lines, no session, the
  /// saved lines to be read again, and the global hooks put back.
  @visibleForTesting
  void resetForTesting() {
    _controller = null;
    _activeConsoleCategory = null;
    _sessionActive = false;
    _keepGlobalCaptureInstalled = false;
    _zoneCaptureInstalled = false;
    _loadedPersistedEntries = false;
    _entries.clear();
    _publish();
    _restoreGlobalCapture();
  }

  void _installGlobalCapture() {
    if (_globalCaptureInstalled) {
      return;
    }
    _globalCaptureInstalled = true;

    _previousDebugPrint = debugPrint;
    debugPrint = _ownDebugPrint = (String? message, {int? wrapWidth}) {
      final normalized = message?.trim();
      if (_disposed || normalized == null || normalized.isEmpty) {
        _previousDebugPrint?.call(message, wrapWidth: wrapWidth);
        return;
      }

      final previousCategory = _activeConsoleCategory;
      _activeConsoleCategory = 'debugPrint';
      try {
        _previousDebugPrint?.call(message, wrapWidth: wrapWidth);
      } finally {
        _activeConsoleCategory = previousCategory;
      }

      if (!_zoneCaptureInstalled) {
        _recordConsoleLine(normalized, category: 'debugPrint');
      }
    };

    _previousFlutterError = FlutterError.onError;
    FlutterError.onError = _ownFlutterError = (FlutterErrorDetails details) {
      _previousFlutterError?.call(details);
      if (_disposed) return;
      _recordUnhandledError(
        details.exception,
        details.stack,
        source: 'flutter',
        category: 'framework',
        fallbackMessage: details.exceptionAsString(),
        details: _flutterReport(details),
      );
    };

    _previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = _ownPlatformError =
        (Object error, StackTrace stack) {
          final handled = _previousPlatformError?.call(error, stack) ?? false;
          if (!_disposed) {
            _recordUnhandledError(
              error,
              stack,
              source: 'dart',
              category: 'uncaught',
            );
          }
          return handled;
        };
  }

  void _restoreGlobalCapture() {
    if (!_globalCaptureInstalled) {
      return;
    }
    _globalCaptureInstalled = false;

    // Each hook goes back only while it is still this service's: one
    // installed over it since (another editor's log) stays, and passes
    // through this one's, which then only passes on to what it replaced.
    if (identical(debugPrint, _ownDebugPrint)) {
      debugPrint = _previousDebugPrint!;
      _previousDebugPrint = null;
      _ownDebugPrint = null;
    }
    if (identical(FlutterError.onError, _ownFlutterError)) {
      FlutterError.onError = _previousFlutterError;
      _previousFlutterError = null;
      _ownFlutterError = null;
    }
    if (identical(PlatformDispatcher.instance.onError, _ownPlatformError)) {
      PlatformDispatcher.instance.onError = _previousPlatformError;
      _previousPlatformError = null;
      _ownPlatformError = null;
    }
  }

  void _recordConsoleLine(String line, {required String category}) {
    final normalized = line.trim();
    if (normalized.isEmpty) {
      return;
    }

    log(
      normalized,
      source: 'console',
      category: category,
      mirrorToDebugger: true,
    );
  }

  void _recordUnhandledError(
    Object error,
    StackTrace? stack, {
    required String source,
    required String category,
    String? fallbackMessage,
    String? details,
  }) {
    log(
      fallbackMessage ?? error.toString(),
      source: source,
      category: category,
      level: DebuggerLogLevel.error,
      details: details ?? stack?.toString(),
    );
  }

  /// What Flutter prints for [details] — the widget at fault and the line
  /// that made it, the hints, the stack — in place of the bare stack.
  ///
  /// An overflow has no stack at all, so its first line was all the log
  /// kept: "A RenderFlex overflowed by 740 pixels", and never which one.
  static String? _flutterReport(FlutterErrorDetails details) {
    try {
      final report = TextTreeRenderer(
        wrapWidthProperties: FlutterError.wrapWidth,
        maxDescendentsTruncatableNode: 5,
      ).render(details.toDiagnosticsNode(style: DiagnosticsTreeStyle.error));
      final trimmed = report.trimRight();
      return trimmed.length <= _maxReportLength
          ? trimmed
          : '${trimmed.substring(0, _maxReportLength)}\n…';
    } on Object {
      return details.stack?.toString();
    }
  }

  /// Enough for any report worth reading; an error thrown every frame with
  /// a whole tree in it should not fill the log file.
  static const int _maxReportLength = 16000;

  List<EditorLogEntry> _mergeEntries(
    List<EditorLogEntry> restored,
    List<EditorLogEntry> inMemory,
  ) {
    final merged = <EditorLogEntry>[];
    final seen = <String>{};

    for (final entry in <EditorLogEntry>[...restored, ...inMemory]) {
      if (seen.add(_entryFingerprint(entry))) {
        merged.add(entry);
      }
    }

    if (merged.length <= _maxEntries) {
      return merged;
    }

    return merged.sublist(merged.length - _maxEntries);
  }

  String _entryFingerprint(EditorLogEntry entry) {
    return '${entry.timestamp.toIso8601String()}|${entry.level.name}|${entry.source}|${entry.category}|${entry.message}|${entry.details ?? ''}';
  }

  /// Lines kept; the oldest go first. Made smaller, they go at once.
  int get maxEntries => _maxEntries;
  int _maxEntries = EditorLogConstants.maxEntries;
  set maxEntries(int value) {
    final next = value < 1 ? 1 : value;
    if (next == _maxEntries) return;
    _maxEntries = next;
    if (_entries.length > next) {
      _entries.removeRange(0, _entries.length - next);
      _scheduleNotify(_publish);
    }
  }

  final List<void Function(EditorLogEntry entry)> _errorListeners = [];

  /// Calls [listener] with each error as it is logged — from the game, a
  /// caught exception, the editor itself. Returns what stops it.
  VoidCallback onError(void Function(EditorLogEntry entry) listener) {
    _errorListeners.add(listener);
    return () => _errorListeners.remove(listener);
  }

  /// Lets go of everything: the global hooks it put in place (whether or
  /// not [EditorLogSession.stopSession] ran), its error listeners, and [entries].
  void dispose() {
    _restoreGlobalCapture();
    _disposed = true;
    _errorListeners.clear();
    _pendingNotifies.clear();
    _controller = null;
    entries.dispose();
  }
}

/// What only the editor that hosts the log does with it: start capturing
/// for a session and stop. Exported by `host.dart`; a module only logs.
extension EditorLogSession on EditorLogService {
  /// Starts capturing prints, Flutter errors and uncaught errors into the
  /// log, mirrored to [controller]; the lines of earlier sessions are read
  /// back first, once.
  Future<void> startSession({required JustDebuggerController controller}) =>
      _startSession(controller: controller);

  /// Stops capturing and lets go of the debugger.
  void stopSession() => _stopSession();
}
