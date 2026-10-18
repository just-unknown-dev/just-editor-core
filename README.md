# Just Editor Core

What a [`just_game_engine_editor`](../just_game_engine_editor/) module builds on: the module contract, the editor's scope and services, undo and the entity commands, the inspector's rows and field-editor API, the Level Designer's tool and overlay API, and the UI kit.

A kit or an editor plugin — `just_platformer_kit`, `just_ui_editor`, the sprite studio — depends on this package and not on the editor. The editor is the host: it runs the modules, and brings its windows, docks, the Level Designer itself, the timeline and its own tools. A game's editor entry point depends on the editor, which re-exports this package's library.

## Install

```yaml
dependencies:
  just_editor_core: ^0.1.0-dev.1
```

## A module

```dart
import 'package:just_editor_core/just_editor_core.dart';

class MyGameModule extends EditorModule {
  @override
  String get id => 'my_game';

  @override
  String get name => 'My Game';

  @override
  List<PrefabDefinition> get prefabs => [/* what the Level Designer places */];
}
```

Pass it to the editor with `JustGameEditorPlugin.register(modules: [MyGameModule()])`. Every member of `EditorModule` has a default; see the editor's [ARCHITECTURE.md](../just_game_engine_editor/ARCHITECTURE.md#the-module-contract) for all of them.

## What is in it

| Area | What |
|------|------|
| The contract | `EditorModule` and its contributions: prefabs, tools, overlays, snap providers, docks, workspaces, toolbar buttons, settings sections, inspector sections, field editors and accessories, scene-tree actions, asset kinds and actions, markers, views, checks; tools, sections and overlays added to another's window (`workspaceContributions`, by `WorkspaceIds`) |
| The scope | `EditorScope`: one editor's registries and services in a `just_di` container — the scene state, undo, the codec and scene store, preferences, the log, the project's tags, physics layers and colours |
| Undo | `EditorHistory`, `EditorCommand`, the entity and hierarchy commands, `ComponentEdit` |
| The inspector | `buildComponentSections`, the field rows, `FieldEditorBuilder`, `ComponentEditorExtras`, `CollectionEditor`, `AddComponentPicker` |
| The Level Designer | `DesignerSession`, `LevelToolHandler`, `PathTool`, `DesignerOverlay`, `SnapProvider`, `SmartSnap`, `GridTopology`, `PrefabDefinition` |
| The viewport | `EditorView`, `EntityPicker`, `RayEntityPicker`, `ViewportOverlay`, `ViewportHandles`, `EditorMarker` |
| The kit | buttons, fields, controls, dialogs, the workspace frame, `EditorTheme`, `EditorMetrics`, the snackbar, `EditorDropdown` |

## Libraries

- `just_editor_core.dart`: what a module imports.
- `kit.dart`: the UI kit alone, for a tool that draws like the editor.
- `host.dart`: everything, for the editor that hosts modules — the parts a module never touches (the settings store, how the scope's registries are filled) included.

## Testing a module

`EditorScope(world: World()..initialize(), modules: [MyGameModule()])` gives a scope over a bare world with no editor: a module's contributions, its prefabs and its commands can be tested against it. A test that needs the editor's own tools or a running plugin — a Level Designer session, the 3-D view — takes `just_game_engine_editor` as a dev dependency and makes the scope with `builtIns: const [BuiltInEditorModule.new]`.
