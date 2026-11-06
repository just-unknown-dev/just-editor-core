import 'package:just_game_engine/just_game_engine.dart';

import '../scope/editor_scope.dart';
import 'editor_scene_state.dart';
import 'editor_view_state.dart';
import 'scene_codec.dart';
import 'scene_store.dart';

/// The open scene on an [EditorScope]: what its components are, how it is
/// read and written, its selection and what is hidden or locked in it.
extension ScopeScene on EditorScope {
  /// Component definitions: what can be saved, sized and drawn —
  /// [EditorScope.context]'s.
  ComponentDefinitionRegistry get definitions =>
      get<ComponentDefinitionRegistry>();

  /// What the inspector shows [component] through, or null when it has no
  /// definition and so cannot be saved either.
  ComponentDefinition? definitionForInspector(Component component) =>
      definitions.definitionFor(component);

  /// Encodes and decodes components through [definitions].
  SceneCodec get codec => service<SceneCodec>(
    () => SceneCodec(
      definitions,
      // The prefab files the edited engine has read, as it reads them.
      prefabs: (path) => context.prefabLibrary.loaded(path),
    ),
  );

  /// Scene files on disk: in [EditorScope.scenesRoot] when the scope was
  /// given one, else in the project's `assets/scenes`.
  SceneStore get scenes => service<SceneStore>(
    () => SceneStore(
      root:
          scenesRoot ??
          (hasProjectRoot ? '$projectRoot/${SceneAssets.directory}' : null),
      codec: codec,
    ),
  );

  /// Selection, scene graph and grid state.
  ///
  /// The steps snapping moves, scales and turns in follow the settings.
  EditorSceneState get sceneState => service<EditorSceneState>(() {
    final state = EditorSceneState()
      ..setGridSnapping(enabled: true, gridSize: 32);
    followSettings(
      (s) => state
        ..moveStep = s.moveStep
        ..moveStep3D = s.moveStep3D
        ..scaleStep = s.scaleStep
        ..rotationStep = s.rotationStepRadians,
    );
    return state;
  }, dispose: (s) => s.dispose());

  /// What is hidden and what is locked against picking — editor-only, and
  /// there whether or not the Level Designer is open.
  EditorViewState get view => service<EditorViewState>(
    EditorViewState.new,
    dispose: (v) => v.dispose(),
  );
}
