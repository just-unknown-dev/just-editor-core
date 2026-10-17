# Changelog

## 0.1.0-dev.1

First release: the part of `just_game_engine_editor` a module builds on, in a package of its own, so a kit or an editor plugin no longer depends on the whole editor.

- **Designers per scene mode**: `EditorModule.designerModes` and `EditorScope.designersFor`; the tool registry keeps a tool per mode.
- **Tools in 3-D**: `ToolContext.space` (`SpaceContext`: the pointer's ray, the working plane, the surface under it, snapping), `WorkingPlane`, `Designer3DState` (working plane, snapping, pivot, view mode, outline, slice, placement, arrays, the material in hand), `Placement3D`, `Array3DSpec`, `LevelToolHandler.onScroll`.
- **Picking surfaces**: `RayTriangles`, `EntitySurfaceTest`, `EntityVertexSource`, `RayEntityPicker.placementAlong` and `localBoundsOf`.
- **Editing**: `ComponentEdit` is public, with `beginAll` and `include`; `ViewportHandle.alsoEdits`.
- **Level aids**: `LevelAids` and `MovementProfile` (`EditorModule.levelAids`; `EditorScope.movement`, `killHeight`).
- **Prefabs**: `SceneCodec(prefabs:)` folds instances back into their files' terms as a scene is saved (`encodeForSave`, `markPrefabs`, `collapseMarked`); `EditorModule.prefabPictures`, `PrefabFavourites`; `AssetDrop.surface`.
- Hide and lock are hierarchical (`EditorViewState.isHiddenIn`, `isLockedIn`); `EditorScope.viewOverride` for split views.
- `EditorModule.onSceneSaving`: a module writes the files a scene refers to as it is saved (`ModuleRegistry.notifySceneSaving`).
- `SidePanelSection.groups`: a module's side-panel section opens with its own tools, and is shut for the rest until opened.
- **The module contract**: `EditorModule` and every contribution type, `EditorModuleContext`, `DesignerToolContext`, `ModuleRegistry` — with built-in modules (`builtIns`, `withBuiltIns`): what the host brings itself, registered ahead of the rest.
- **The scope**: `EditorScope` and its services. It holds no built-ins of its own: the host passes them as modules (`EditorScope(builtIns: …)`, `addBuiltIn`). `openDock(id)` opens one of the host's docks.
- **`DesignerSession`**: the Level Designer as a module sees it, handed to `saveEditorData`, `restoreEditorData`, status controls and side-panel sections. `CommandContext` carries it as `session`, and `host` for what dispatched the command.
- **`FieldAccessory`**: a widget beside a component's fields, told of every edit made through them (`EditorModule.fieldAccessories`).
- **`CameraSyncingView`**: a view that puts its own framing on the camera when shown.
- **`PrefabColours`**: the colours the editor's own prefabs come in.
- **`AudioDrop`**: what an audio file dropped on the viewport becomes.
- Undo and the entity commands, the inspector's rows and field editors, the Level Designer's tool, overlay, snapping and grid API, the viewport's views and pickers, scene validation, the project's tags, physics layers and colours, preferences, the log, and the UI kit.

Three libraries: `just_editor_core.dart` for modules, `kit.dart` for the UI kit alone, `host.dart` for the editor that hosts them.
