import 'dart:async';

import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;
import 'package:just_game_engine/just_game_engine.dart' show Signal;
import 'package:meta/meta.dart';

import '../scope/editor_scope.dart';
import 'editor_contributions.dart';
import 'open_workspace.dart';
import 'scope_wiring.dart';

/// The workspace that has one [EditorScope]'s viewport: which is open,
/// whether it fills the editor, and what it wants asked before it goes.
/// `ScopeModules` is its public face.
@internal
final class WorkspaceHost {
  WorkspaceHost._(this._scope);

  /// [scope]'s, made when first asked for.
  static WorkspaceHost of(EditorScope scope) => scope.service<WorkspaceHost>(
    () => WorkspaceHost._(scope),
    dispose: (h) => h.dispose(),
  );

  final EditorScope _scope;

  /// See `ScopeModules.activeWorkspace`.
  final Signal<OpenWorkspace?> activeWorkspace = Signal<OpenWorkspace?>(
    null,
    debugLabel: 'activeWorkspace',
  );

  /// See `ScopeModules.workspaceFullScreen`.
  final Signal<bool> workspaceFullScreen = Signal<bool>(
    false,
    debugLabel: 'workspaceFullScreen',
  );

  /// See `ScopeModules.openWorkspace`.
  bool openWorkspace(String id, {String? path}) {
    for (final w in ScopeWiring.of(_scope).workspaces.items) {
      if (w.id != id) continue;
      final open = activeWorkspace.value;
      final guard = _closeGuard;
      final replacing =
          open != null && (open.definition.id != id || open.path != path);
      if (guard != null && replacing) {
        unawaited(() async {
          if (!await _ask(guard)) return;
          // Closed, or another opened in its place, while it asked.
          if (_scope.isDisposed || !identical(activeWorkspace.value, open)) {
            return;
          }
          _clearCloseGuard();
          activeWorkspace.value = OpenWorkspace(w, path);
        }());
        return true;
      }
      if (replacing) _clearCloseGuard();
      activeWorkspace.value = OpenWorkspace(w, path);
      return true;
    }
    return false;
  }

  Future<bool> Function()? _closeGuard;
  OpenWorkspace? _closeGuardOf;

  /// See `ScopeModules.setWorkspaceCloseGuard`.
  void setWorkspaceCloseGuard(
    Future<bool> Function()? guard, {
    OpenWorkspace? of,
  }) {
    final owner = of ?? activeWorkspace.value;
    if (guard == null && !identical(owner, _closeGuardOf)) return;
    if (guard != null && !identical(owner, activeWorkspace.value)) return;
    _closeGuard = guard;
    _closeGuardOf = guard == null ? null : owner;
  }

  /// See `ScopeModules.requestCloseWorkspace`.
  Future<bool> requestCloseWorkspace() async {
    final guard = _closeGuard;
    final open = activeWorkspace.value;
    if (guard != null && !await _ask(guard)) return false;
    // Closed, or another opened in its place, while it asked.
    if (_scope.isDisposed || !identical(activeWorkspace.value, open)) {
      return false;
    }
    closeWorkspace();
    return true;
  }

  /// [guard]'s answer; no — the workspace stays — when it throws, which
  /// the log then says.
  Future<bool> _ask(Future<bool> Function() guard) async {
    try {
      return await guard();
    } on Object catch (error, stack) {
      if (!_scope.isDisposed) {
        _scope.log.log(
          'The open window could not ask about its unsaved work, so it '
          'stays open: $error',
          source: 'editor',
          category: 'workspace',
          level: DebuggerLogLevel.error,
          details: '$stack',
        );
      }
      return false;
    }
  }

  /// See `ScopeModules.openInWorkspace`.
  bool openInWorkspace(String path) {
    WorkspaceDefinition? best;
    var bestMatch = 0;
    // The editor's own workspaces open files too, not only the modules'.
    for (final w in ScopeWiring.of(_scope).workspaces.items) {
      final match = w.matchOf(path);
      if (match > bestMatch) {
        best = w;
        bestMatch = match;
      }
    }
    if (best == null) return false;
    return openWorkspace(best.id, path: path);
  }

  /// See `ScopeModules.closeWorkspace`.
  void closeWorkspace() {
    _clearCloseGuard();
    activeWorkspace.value = null;
  }

  void _clearCloseGuard() {
    _closeGuard = null;
    _closeGuardOf = null;
  }

  /// Disposes the signals; the scope does, when it is disposed.
  void dispose() {
    activeWorkspace.dispose();
    workspaceFullScreen.dispose();
  }
}
