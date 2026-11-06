import '../scope/editor_scope.dart';
import 'editor_history.dart';

/// Undo on an [EditorScope].
extension ScopeHistory on EditorScope {
  /// Undo for everything the editor does: the scene tree, the inspector,
  /// the UI mode and the Level Designer. How many steps it keeps follows
  /// the settings.
  ///
  /// One stack per editor, not per designer session. Undo that only worked
  /// while a particular panel happened to be open was undo nobody could
  /// rely on, and two stacks meant Ctrl+Z reversed whichever of them the
  /// key happened to reach.
  EditorHistory get history => service<EditorHistory>(() {
    final history = EditorHistory();
    followSettings((s) => history.capacity = s.undoLimit);
    return history;
  }, dispose: (h) => h.dispose());
}
