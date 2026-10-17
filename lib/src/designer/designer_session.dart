import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../scope/editor_scope.dart';
import '../model/editor_scene_state.dart';
import '../view/editor_view.dart';
import '../model/editor_history.dart';
import 'level_designer_controller.dart';

/// The Level Designer while it is open, as a module sees it: what its
/// status-bar controls, side-panel sections and saved designer data are
/// handed, and what a command run from the designer gets.
///
/// The editor's own session implements it; a module never makes one.
abstract interface class DesignerSession {
  /// The editor the session belongs to.
  EditorScope get scope;

  /// The world being edited.
  jge.World get world;

  /// Selection, scene graph and grid state.
  EditorSceneState get sceneState;

  /// The undo stack every edit the designer makes goes on.
  EditorHistory get history;

  /// The designer's state: the tool in hand, snapping, what is hidden and
  /// locked.
  LevelDesignerController get controller;

  /// How the designer sees the level.
  EditorView get camera;

  /// An entity name not already in use, built from [prefix].
  String uniqueName(String prefix);

  /// Puts the tool called [toolId] in hand.
  void setTool(String toolId);

  /// The session state a module made ([EditorModule.createSessionState]),
  /// by type; null when none did.
  T? stateOf<T extends Object>();
}
