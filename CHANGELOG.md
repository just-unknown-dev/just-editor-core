# Changelog

## 0.1.0-dev.1

First release: what a `just_game_engine_editor` module builds on — a kit, a tool or a game's own editor module depends on this package, not on the editor. Needs `just_game_engine` ^2.0.0-dev.2, Flutter 3.47.1 and Dart 3.11; compiles on every Flutter platform, web and wasm included.

Four libraries: `just_editor_core.dart` for modules, `kit.dart` for the UI kit alone, `host.dart` for the editor that hosts modules, and `io.dart`, the `dart:io` seam (stand-ins on the web).

### The module contract

- `EditorModule`: every member has a default, so a module overrides only what it adds — field editors and accessories, component extras, prefabs (its own designer's, or shared with every designer), tools and tool groups, overlays, snap providers, layers, a grid topology, docks, workspaces, toolbar buttons, settings sections, theme presets, scene-tree actions, row decorations and icons, inspector sections, commands and key bindings, checks, asset kinds and actions, Tiled object mappers, tags, getting-started tips, level aids, and for 3-D views, markers, pick tests, viewport overlays, handles and prefab variants.
- An asset kind's drop is for the scenes it says (`AssetKind.dropsIn`, `dropsInto`): a model's in 3-D ones; the host turns it away from the others.
- Lifecycle: `onRegister` once, `onReassemble` after each hot reload, `onSceneOpened`, `onSceneSaving`, `onUpdate`, `onAssetChanged`, `onPlayStateChanged`, `dispose`.
- Designers per scene mode (`EditorModule.designerModes`, `EditorScope.designersFor`), and `DesignerSession`, the open Level Designer as a module sees it.
- Adding to another's window: `EditorModule.workspaceContributions` — a tool on its toolbar (`WorkspaceTool`), a section in its panel (`WorkspaceSection`) or an overlay over its preview (`WorkspaceOverlay`), by the window's id (`WorkspaceIds`); the material windows hand them a typed view (`Material3DWorkspaceView`, `Material2DWorkspaceView`).

### The scope and its services

- `EditorScope`: one editor's registries and services in a `just_di` container — the scene state and the selection, undo, the scene codec and store, preferences, the theme, the log, hide and lock, the project's tags, physics layers and colours, the editor's view and camera brain. Two scopes share nothing; `reload()` rebuilds every registry from the modules.
- Built-in modules (`builtIns:`; `addBuiltIn` in `host.dart`): what the host brings itself, registered ahead of the rest.
- Project files: `ProjectFiles` (whole-or-nothing writes, safe renames, paths kept inside the project), `PackageAssetPaths`, `AssetIndex`, and `AssetReferences` (in `host.dart`).
- `EditorLogService`, `EditorPrefs` and `SettingPref`, `OverlayUiSettings`, `GizmoSettings`.

### Undo and the model

- `EditorHistory` and `EditorCommand`; the entity commands (`TransformCommand`, `CreateEntitiesCommand`, `DeleteEntitiesCommand`, `ComponentFieldCommand`, `EntityStateCommand`, `CompositeCommand` and the rest) and the hierarchy commands (`ReparentCommand`, `ReorderCommand`, `RenameCommand`, `GroupCommand`, `UngroupCommand`); `ComponentEdit` for an edit to a whole component.
- `SceneCodec` and `SceneStore`, with prefab instances folded back into their files' terms on save; `UnknownComponents` keeps what no definition reads.
- `CommandRegistry`, `DesignerCommand` and `KeyBinding`; `EditorKeys` and `ModifierKeys` (Cmd as the primary modifier on macOS, Backspace deletes).

### The inspector

- `buildComponentSections` and `DefinitionSection`, built from each component's `ComponentDefinition`; the field rows, `FieldEditorRegistry` and `FieldEditorContext`, `ComponentExtrasRegistry`, `CollectionEditor`, `AddComponentPicker`, component reordering, `LivePreview`.

### The Level Designer and the viewport

- The tool API: `LevelToolHandler`, `ToolContext` (with `SpaceContext` in 3-D), `ToolRegistry`, `PathTool`; `DesignerOverlay`, `SnapProvider`, `SmartSnap`, `GridTopology` and `SquareGrid`, `PrefabDefinition` and `PrefabRegistry`, `LayerPreset`.
- 3-D: `WorkingPlane`, `Designer3DState`, `Placement3D`, `Array3DSpec`, `LevelAids` and `MovementProfile`.
- Views and picking: `EditorView`, `GameCameraEditorView`, `CameraSyncingView`, `EntityPicker`, `RayEntityPicker` and `RayTriangles`; `EditorMarker`, `ViewportOverlay`, `ViewportHandles` and `HandleDragSession`, `PrefabVariant`.
- Scene checks: `SceneValidator`, `ValidationContext`, `SceneProblem`, `ProblemFix`.

### The UI kit

- Buttons, fields, controls, dialogs, focus and `EditorKeyClaim`, the workspace frame, `EditorDropdown`, `showEditorMenu`, `EditorScrollbar`, `ScrubbableNumberField` and the snackbar, drawn with `EditorTheme` and `EditorMetrics` so they follow the editor's theme and accessibility settings.
