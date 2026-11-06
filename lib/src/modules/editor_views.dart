import 'package:flutter/foundation.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../scene/scope_scene.dart';
import '../scope/editor_scope.dart';
import '../view/editor_view.dart';

/// How one [EditorScope] sees the scene: a view per scene mode — a
/// module's, or the 2-D view on the main camera — the pane standing in for
/// it, and the viewport overlays turned off. `ScopeModules` is its public
/// face.
@internal
final class EditorViews {
  EditorViews._(this._scope);

  /// [scope]'s, made when first asked for.
  static EditorViews of(EditorScope scope) => scope.service<EditorViews>(
    () => EditorViews._(scope),
    dispose: (v) => v.dispose(),
  );

  final EditorScope _scope;

  /// The views the modules offer, by scene mode ([EditorModule]'s
  /// `viewFactories`); the module wiring fills it.
  final Map<SceneMode, EditorView Function(EditorScope scope)> factories = {};

  final Map<SceneMode, EditorView> _views = {};
  SceneMode? _viewMode;

  /// See `ScopeHost.viewOverride`.
  EditorView? viewOverride;

  /// See `ScopeModules.hiddenOverlays`.
  final ValueNotifier<Set<String>> hiddenOverlays = ValueNotifier(const {});

  /// See `ScopeModules.editorView`.
  EditorView get editorView => viewOverride ?? sceneView;

  /// See `ScopeModules.sceneView`.
  EditorView get sceneView {
    final mode = _scope.sceneState.editingMode;
    final view = _views[mode] ??= (factories[mode] ?? _flatView)(_scope);
    if (_viewMode != mode) {
      _viewMode = mode;
      _takeCamera(view);
    }
    return view;
  }

  EditorView _flatView(EditorScope scope) => GameCameraEditorView(mainCamera);

  /// [view] becomes what the camera shows: a 3-D view puts its orbit on
  /// it; the 2-D view takes it back to a flat camera.
  void _takeCamera(EditorView view) {
    if (view is CameraSyncingView) {
      view.sync();
      return;
    }
    final camera = mainCamera();
    if (camera.isPlanar) return;
    camera
      ..inSpace = false
      ..lens = const CameraLens()
      ..pitch = 0
      ..yaw = 0
      ..z = 0;
  }

  /// The camera new entities are placed in front of; a bare one before the
  /// engine has a viewport, which is all a HUD's entities need.
  OutputCamera mainCamera() {
    final e = _scope.engine;
    if (e == null || !e.isInitialized || !e.camera.isInitialized) {
      // One kept, so a view on it stays where it was put.
      return _bareCamera;
    }
    return e.camera.mainCamera;
  }

  late final OutputCamera _bareCamera = OutputCamera();

  /// See `ScopeModules.cameraBrain`.
  CameraBrain? get cameraBrain {
    final e = _scope.engine;
    if (e == null || !e.isInitialized || !e.camera.isInitialized) {
      return null;
    }
    return e.camera.brain;
  }

  /// Disposes [hiddenOverlays]; the scope does, when it is disposed.
  void dispose() => hiddenOverlays.dispose();
}
