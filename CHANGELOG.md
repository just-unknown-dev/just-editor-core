# Changelog

## 0.1.0-dev.1

First release: the part of `just_game_engine_editor` a module builds on, in a package of its own, so a kit or an editor plugin no longer depends on the whole editor.

- **Designers per scene mode**: `EditorModule.designerModes` and `EditorScope.designersFor`; the tool registry keeps a tool per mode.
- **Gizmos per mode**: `GizmoMode`, `GizmoKind`, `GizmoModeSettings`, `GizmoSettings` (`OverlayUiSettings.gizmos`, saved one short string per mode); `DesignerOverlay.gizmoKind` and `ViewportOverlay.gizmoKind` (null on a designer overlay: not a gizmo, always drawn); `OverlayPaintContext.showsGizmo`; `LevelDesignerController.showsGizmosOf` and `OverlayPaintContext.showsGizmosOf` (what a gizmo may be drawn for: off the Level Map too).
- `ToolbarButton.slot` (`ToolbarSlot`): a button stands with the modules' tools on the play toolbar, or in the column down the right under the transform tools, for a feature of the editor itself such as the Asset Store.
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
- **`EditorDropdown`**: its list opens as wide as its entries' names and details need (up to `maxMenuWidth`), not only as wide as the field; a detail too long for it is cut short, never squeezing the name out (`maxLabelWidth`).
- **`EditorSlider`** shows the value dragged to while a drag lasts, whatever its `value`, and tells each step once: a live preview need not build what holds the slider again at every step.
- **`FieldAccessory`**: a widget beside a component's fields, told of every edit made through them (`EditorModule.fieldAccessories`).
- **Adding to another's window**: `EditorModule.workspaceContributions` — a tool on a window's toolbar (`WorkspaceTool`), a section in its panel (`WorkspaceSection`) or an overlay over its preview (`WorkspaceOverlay`), by the window's id (`EditorScope.workspaceContributionsFor`). Each is handed the window's `WorkspaceView`; the material windows' are typed (`WorkspaceIds.material`, `WorkspaceIds.material2D`; `Material3DWorkspaceView`, `Material2DWorkspaceView`: the material, what is shown, `change` as one undo step, `preview` and `endPreview`). A window puts them in place with `WorkspaceToolButtons`, `WorkspaceSections` and `workspaceOverlays`. The material files those views hand on come from `just_game_engine_formats`, a dependency now.
- **`CameraSyncingView`**: a view that puts its own framing on the camera when shown.
- **`PrefabColours`**: the colours the editor's own prefabs come in.
- **`AudioDrop`**: what an audio file dropped on the viewport becomes.
- Undo and the entity commands, the inspector's rows and field editors, the Level Designer's tool, overlay, snapping and grid API, the viewport's views and pickers, scene validation, the project's tags, physics layers and colours, preferences, the log, and the UI kit.

Three libraries: `just_editor_core.dart` for modules, `kit.dart` for the UI kit alone, `host.dart` for the editor that hosts them.
