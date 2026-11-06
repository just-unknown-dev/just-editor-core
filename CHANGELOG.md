# Changelog

## 0.1.0

The first release that isn't a dev release: from here its API follows semantic versioning (in 0.x, a breaking change moves the minor version). Made for just_game_engine 2.0.x and just_game_engine_editor 0.1.x.

The package is laid out by feature, in layers, with a test that keeps it so, and `EditorScope` is a kernel each feature adds to. Requires just_game_engine ^2.0.0, just_game_engine_formats ^0.3.0, just_colours ^0.2.0, just_debugger ^0.1.0 and meta ^1.9.0.

### Breaking

- **Files moved.** `lib/src/` has one folder per feature, in eight layers (CONTRIBUTING.md, "How the Package Fits Together"): `model/`, `services/`, `extension/` and `validation/` are gone, into `input/`, `log/`, `assets/`, `scene/`, `history/`, `designer/`, `inspector/` and `modules/`. The four libraries keep their names; import them, never `src/`.
- **`EditorScope` is the kernel.** It keeps the engine, world and context, the container, `prefs`, `theme`, `chrome`, `log`, the authored-state checks, `viewportCaptureKey` and `isPlayTesting`. Every other member is an extension of the feature that owns it, exported by the libraries, so `scope.history` and the rest still read the same:
  - `ScopeScene`: `definitions`, `definitionForInspector`, `codec`, `scenes`, `sceneState`, `view`;
  - `ScopeHistory`: `history`;
  - `ScopeProject`: `tags`, `physicsLayers`, `colors` (was `colours`), `tagReferences`, `highlightedLayer`, `highlightedTag`, `spawners`;
  - `ScopeAssets`: `assetKinds`, `assetIndex` (new);
  - `ScopeDesigner`: `config`, `handleLayout`, `commands`, `prefabs`, `layers`, `designer3D`, `grid`, `prefabCategories`, `prefabCategoryOrder`, `statusControls`, `designerPanels`;
  - `ScopeInspector`: `fieldEditors`, `extras`, `inspectorSections`, `fieldAccessories`;
  - `ScopeModules`: `modules` and everything the modules contribute, the views (`editorView`, `sceneView`, `mainCamera`, `cameraBrain`, `hiddenOverlays`), the workspaces (`activeWorkspace`, `openWorkspace`, …), the designer chosen (`activeDesigner`, `selectDesigner`, …) and protection (`isProtected`, `deletable`, `protectedIn`).
- A feature's services are made the first time they are asked for: `scope.get<EditorHistory>()` finds the history only once `scope.history` has made it. One registered in `scope.container` ahead of that is used instead.
- `EditorScope(modules:)` takes `List<ScopeModule>` and `builtIns:` `List<ScopeModule Function(EditorScope)>`; every `EditorModule` is a `ScopeModule`, so calls read as before. `config:` and `handles:` are gone: register a `DesignerConfig` or `SelectionHandleLayout` in `scope.container` before it is first read for other ones.
- `EditorScopeHost` → `ScopeHost` (host-only, as before); its `authoredStateGuards` and `authoredStateHeld` are on `ScopeAuthoredState`, host-only too.
- Renamed (old → new):
  - color, not colour: `ProjectColours` → `ProjectColors` (file `project_colors.dart`), `PrefabColours` → `PrefabColors`, `showEditorColourPicker` → `showEditorColorPicker` (file `color_picking.dart`), `EditorScope.colours` → `colors`; on `OverlayUiSettings` `gridColour` → `gridColor`, `selectionColour` → `selectionColor`, `colourBlindSafe` → `colorBlindSafe` (and `EditorThemeData.colourBlindSafe()` → `colorBlindSafe()`), `defaultGridColour` → `defaultGridColor`, `copyWith(clearSelectionColour:)` → `clearSelectionColor:`; `OverlaySettingsPrefKeys.prefColourBlindSafe` / `prefGridColour` / `prefSelectionColour` → `prefColorBlindSafe` / `prefGridColor` / `prefSelectionColor`. The keys they hold, as saved, are unchanged (`editor.a11y.colourBlindSafe`, `editor.viewport.gridColour`, `editor.viewport.selectionColour`, and the colour picker's `editor.colour_picker.recents`): settings saved before read as they were;
  - the 3-D tag after the subject: `ArrayMode3D` → `Array3DMode`, `ArrayStep3D` → `Array3DStep` (file `array_3d_spec.dart`), `ViewMode3D` → `View3DMode`, `PivotMode3D` → `Pivot3DMode`. None is saved. `WorkspaceIds.material` → `material3D`, beside `material2D`; the id it holds is unchanged (`materials.material`);
  - one kind word for the inspector's rows, `…FieldRow`: `ColorEditorRow` → `ColorFieldRow`, `BoolEditorRow` → `BoolFieldRow`, `TextEditorRow` → `TextFieldRow`, `DropdownEditorRow` → `DropdownFieldRow`, `OffsetListEditorRow` → `OffsetListFieldRow`, `AssetRefEditorRow` → `AssetRefFieldRow`, `EdgeInsetsEditorRow` → `EdgeInsetsFieldRow`, `ReadonlyRow` → `ReadonlyFieldRow`. `field_rows.dart` is `inspector/rows/` (a file per kind) and `inspector/shape_paint_selection.dart`;
  - `UnknownComponentsCard` → `UnknownTypesCard`;
  - `CommandScope` → `CommandAvailability`, `DesignerCommand.scope` → `availability`, `CommandRegistry.dispatch(scopes:)` → `availabilities:`: a command's availability is not an editor's scope.
- `OverlayDensityX` and `EditorSnackBarTypeX` are gone: `label`, `compactness`, `accentColor` and `iconData` are members of `OverlayDensity` and `EditorSnackBarType`. Calls read as before.
- Gone from this package, as they are the editor's own: `GizmoConstants` and `OverlayLayout`. The two numbers the chrome's state keeps are `EditorChromeState.rightPanelDefaultWidth` and `EditorChromeState.perfHistoryCapacity`. `kComponentGroups` is private to `AddComponentPicker`, its only reader.
- `ViewportLook.apply` is gone: `ViewportLook` reads the settings `EditorMetrics.apply` was given, so one call drives the panels and the viewport.
- `AssetDrop` takes `mode:`, the mode of the scene it landed in; `AudioDrop.place` reads it rather than the scope.
- No longer exported, and `@internal`: `component_reorder.dart` (`ComponentDrag`, `ComponentPlacement`, `ComponentDragGrip`, `ComponentDropZone`, `ComponentPlaceMenu`, `placeComponent`, `reorderedTypes`, `isPinnedComponent`), `ComponentEntry` and `componentEntries` (was `getComponentRegistryEntries`; file `component_entry.dart`), `parseTypedNumber`, and the storage halves (`openEditorStorage`, `moveEditorKeys`, `createEditorLogStorageImpl`, …).
- `asset_index.dart` no longer re-exports `AssetKind` and `AssetKinds`; `AssetReferences` has its own file. Both are in the libraries as before.
- just_colours 0.2.0: `showEditorColorPicker` takes a `ColorPickerMode mode` (was `ColourDialogView view`) and returns a `ColorSelection` (was `ColourSelection`); `shapePaintStyleToSelection` and `selectionToShapePaintStyle` take and give `ColorSelection`; `ProjectColors.library` is a `ColorLibrary`.
- Rays are just_dart 0.3.0's `Ray3D` (was `Ray3`), through the engine: `EditorView.screenToRay`, `RayEntityPicker` (`distanceTo`, `surfaceHit`, `placementAlong`), `RayTriangles`, `WorkingPlane.intersect`, `SpaceContext.ray` and `HandleDrag.ray`.
- The module API follows the engine's renames: `FieldEditorContext.field`, `FieldAccessoryContext.fields` and `FieldEditorRegistry.forField` / `canEdit` take a `FieldDefinition` (was `SchemaField`), and `Material3DWorkspaceView` works on a `Material3DFile` (was `MaterialFile`). `EditorScope.mainCamera` and `GameCameraEditorView` (`of`, `camera`) are the engine's `OutputCamera` (was `Camera`).
- `UnknownComponents` is `UnknownTypesComponent` (file `unknown_types_component.dart`), as every component's name now ends in `Component`.
- `ComponentFieldCommand` takes a required `field:`: the name of the field it writes (`FieldDefinition.name`), or another key that is the same for every edit of that one value. Two edits merge into one undo step only when they write the same field.
- `CommandRegistry.applyShortcuts` returns the chords it could not read, by command id (was `void`).
- `LevelDesignerController.resetForScene` is gone. It cleared the editor-wide undo history and the scope's hidden and locked sets, which are not the designer's; opening a scene clears the history already.

### Added

- `EditorScope.service<T>(make, {dispose})`: a per-editor service, made on first ask and disposed with the scope, for features, modules and the host alike.
- `EditorScope.projectRoot` (and `projectRoot:`): the project's folder, the working folder when not given. Given one, the scenes, the tag, collision-layer and palette files (`pathFor(projectRoot:)`) and the asset index are under it.
- `ScopeAssets.assetIndex`: one `AssetIndex` per editor, scanned on first ask and following the disk.
- `showEditorPrompt`: a text prompt in the kit's look, checked as it is typed.
- `OrbitFlyEditorView` and `View3DPose` (the editor's `ViewPose3D`), `HexGrid` and `HexGridModule`: from just_game_engine_editor, so a kit can use them on this package alone.
- `ScopeModule`, the hook a scope's modules join it by; `ModuleFailureReporter`, how a module's mistake is told; `EditorScope.isDisposed`, `isDebug` and `scenesRoot`.
- `test/library_layout_test.dart`: the layout's rules, the layers and the two of this package's own — `kit.dart` imports no engine, and only the `dart:io` seam and its native halves import `dart:io`.
- `ComponentFieldCommand.field` (see Breaking).
- `SceneCodec.parentNames`, the names a file links each parent by, and `SceneCodec.nameUnnamedParents`, which mends a file's entries as an earlier editor saved a child of an unnamed parent. The editor calls it on a scene's entries before it builds them.
- `HierarchySlot.ofAll` and `EditorSceneState.rootIndices`: the places of many entities, worked out in one look; `EntitySpec.of(siblingIndex:)` for a place worked out already.
- `SceneStore.readRawInBackground`: a scene read and decoded off the UI thread.
- `ProjectTags.seedLater` and `ProjectTags.seeded`: tags found in the background join the stand-in list once read.
- `OverlaySettingsStore.loadAll`: the settings and every raw value, from one read of the store.
- Tests for what only the editor's suite covered, or nothing did: `ComponentEdit` and `CompositeCommand`, `PathTool`, `ReorderCommand`, `ReorderComponentsCommand`, `RemoveComponentCommand`, `ModuleRegistry.notifySceneSaving`, `EditorHistory.jumpTo`, the selection (`toggleMultiSelect`, `selectRange`, `setSelectable`), `EditorPrefs` and `LivePreview`; and a regression test for each fix below.

### Changed

- A module's mistake is told one way: in the editor's log, source `editor`, category `modules`, whether it threw from a contribution, `onRegister`, or a call such as `onSceneOpened`, `onUpdate` or `dispose`; a registry with no log, or a scope gone, reports a Flutter error. The Console's "modules" filter now finds all of them.
- The default theme comes from one place: `ThemeController.builtIn`'s first entry is built from `OverlayUiSettings.defaultThemeId` and `defaultAccent`, which a fresh settings store also reads.
- Each service follows the settings from when it is made — undo's size, the log's lines, the snapping steps, the changed keys — rather than all of them being made when the settings are first read.
- The scope's services are disposed in the reverse order of their first use; the log outlives the modules, so a module's `dispose` can still log.
- `EditorModule.onUpdate` and `ModuleRegistry.notifyUpdate` name their parameter `deltaTime`.
- An `EditorScope` installs the engine's built-in components (`BuiltInComponents.extension`) into its context, so it reads and writes scenes whatever world it was given.
- Collapsing prefab instances for a save goes through just_game_engine_formats' `PrefabCollapse.collapseScene` (was `PrefabExpander.collapseScene`).
- Space is saved in the settings by its name: `KeyBinding.nameOf` gives `Space` for a key whose label is blank, so a chord saves as `Ctrl+Space` (was `Ctrl+ `). A file saved before still reads: a blank key is read as Space.
- An inspector edit's undo step names its row or group where another field of the component has the same label: "Change Dead zone Height", "Change Translation Min".
- Grouping places the group where the first of what it holds was: under the parent they share, or the nearest one they are all under, and at the top level only when they have none in common. Under a Level Map the group goes on the map layer of the first of them, and what goes into it leaves its own, as anything moved off a map does; ungrouping there puts the children on the group's layer. An entity under another one grouped is left out, as a move leaves it. (The group was always the last root.)
- `UniqueNamer` reads the names in use once per run of the code asking, not once per name; a name given in that run other than through it is seen from the next.
- Without a tag file, the tags the open world carries stand in at once, and those the project's other scenes carry join once they are read, in the background (`ProjectTags.seeded`). Every scene was decoded on the UI thread the first time the tags were asked for.
- The Scenes list reads a scene's mode and entity count without decoding the file.
- `EditorLogService.entries` hands out read-only windows onto its lines rather than a copy of them all, so a line logged costs the same however long the log is; a list handed out still never changes.
- The scene checks keep the files they read on the scope, up to 128 files and 16 million characters of them, and a decoded file's text is not kept beside it (they were kept for the whole process, 128 files of any size).

### Fixed

- A module whose `id` throws is reported by its type when it fails, rather than throwing again from the report.
- Two fields with the same label — a framing camera's dead and soft zone heights, a six-degrees-of-freedom joint's two Mins — edited one after the other with Tab were merged into one undo step: undo put back one of them, and redo wrote the other's value into it.
- A child of an unnamed entity lost its parent when the scene was saved and opened again: its record named the parent `entity_<id>`, and the parent's own record had no name. The parent's record now carries the name, made unique against the names in the scene.
- Grouping took the selection out of its parent — a UI canvas, a Level Map — and kept the map-layer ids of what it took off a map (see Changed).
- A shortcut set to Space was saved as a blank and could not be read back, and the command was left with no key at all. A command none of whose saved chords can be read now keeps the keys it was built with, and the chords are told in the log (category `shortcuts`).
- `ModuleRegistry.notifySceneSaving` walked the live list of modules across its `await`s, so a module registered or removed while one was saving (a hot reload) broke the save. It goes over the modules there when the save began, and skips one gone since.
- `EditorHistory.push` left a command that threw half-done with the history as it was. Now the redo steps go, the document reads dirty, the stack is published, and the error goes on to the caller.
- The path tool recorded a "Move waypoint" step, and marked the scene unsaved, when a waypoint was clicked and let go where it was.
- A module preference set while the preferences were still being read was put back to the older stored value. The store is also read once to load, not twice.
- `ScopeHost.addBuiltIn` disposes the module it made when one with that id is there already.
- Commands on large selections looked through each entity's siblings, and every pair of entities, once per entity: the places are worked out in one look, and a move checks each entity's ancestors against the selection.
- `EditorSceneState` kept every entity destroyed on the way to its latest rebuild, and a lookup walked them all. It keeps ids and the latest entity, and a lookup is one step.
- `SceneStore.unsavedBackupOf` offered a backup for recovery that differed from its scene only in line endings: a scene checked out by git on Windows is CRLF, and a backup is written with LF.

### Removed

- `look/kit/kit.dart`, a sub-folder barrel: the look's barrel, `look/look.dart`, exports the kit; `kit.dart` exports the whole look.
- `LevelDesignerController.resetForScene` (see Breaking).

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
