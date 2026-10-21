# Just Editor Core

What a [`just_game_engine_editor`](https://pub.dev/packages/just_game_engine_editor) module builds on: the module contract, the editor's scope and services, undo and the entity commands, the inspector's rows and field-editor API, the Level Designer's tool and overlay API, and the UI kit.

A kit, a tool or a game's own editor module — `just_platformer_kit`, `just_ui_editor`, the sprite studio — depends on this package, not on the editor. The editor is the host: it runs the modules, and brings its windows, docks, the Level Designer itself, the timeline and its own tools. A game's editor entry point depends on the editor, which re-exports this package's library.

## Install

A package of editor tools depends on it:

```bash
flutter pub add just_editor_core
```

```yaml
dependencies:
  just_editor_core: ^0.1.0-dev.1
```

A game that keeps its module beside its editor entry point needs nothing more than `just_game_engine_editor` (a dev dependency), which re-exports this library.

## Where it runs

The package compiles on every Flutter platform: Android, iOS, the web (JavaScript and WebAssembly), Windows, macOS and Linux. Its file and process calls go through `package:just_editor_core/io.dart`, which is `dart:io` on native platforms and stand-ins on the web; a module that touches files imports it instead of `dart:io`, so a game that imports the editor still builds for the web.

The editor that runs modules edits the project's files on disk, so it runs in a debug build on a desktop — Windows, macOS or Linux — started from the project folder (`flutter run -d windows|macos|linux`). It saves under the working directory: scenes in `assets/scenes/`, backups in `.editor_backups/`, deleted files in `.editor_trash/`. On macOS its shortcuts use Cmd (`EditorKeys`), and Backspace deletes.

On macOS the debug app must not be sandboxed: a sandboxed app may write only inside its own container. Set `com.apple.security.app-sandbox` to `false` in `macos/Runner/DebugProfile.entitlements` (the release entitlements are not touched; release builds never include the editor). The editor checks at start that it can write the project and says so in its log when it cannot (`SceneStore.writeAccessProblem`).

## A module

A coin the Level Designer places, and an inspector editor for the coin's own field type, from [`example/example.dart`](https://github.com/just-unknown-dev/just-editor-core/blob/main/example/example.dart) (which also has the game's `CoinComponent`, its `CoinValueFieldType` and its definition):

```dart
import 'package:flutter/material.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

class CoinModule extends EditorModule {
  @override
  String get id => 'coins';

  @override
  String get name => 'Coins';

  // In every Level Designer, beside the editor's own shapes.
  @override
  List<PrefabDefinition> get sharedPrefabs => [
    PrefabDefinition(
      id: 'coins.coin',
      name: 'Coin',
      category: 'Pickups',
      icon: Icons.monetization_on,
      color: const Color(0xFFFFC107),
      placement: PrefabPlacement.point,
      defaultSize: const Size(16, 16),
      description: 'A coin worth 1 point.',
      // New components every time: two coins must not share one.
      build: (position, size) => [
        TransformComponent(position: Vector3(position.dx, position.dy, 0)),
        CoinComponent(),
      ],
    ),
  ];

  // The inspector's control for the coin's own field type, by its id.
  @override
  Map<String, FieldEditorBuilder> get fieldEditors => {
    'coins.value': (field) => DropdownEditorRow(
      label: field.label,
      value: '${field.value}',
      options: const ['1', '5', '10'],
      onChanged: (picked) => field.onChanged(int.parse(picked)),
    ),
  };
}
```

Pass it to the editor in the game's editor entry point: `JustGameEditorPlugin.register(engine: engine, modules: [CoinModule()])`. Every member of `EditorModule` has a default, so a module overrides only what it adds. Prefabs in `sharedPrefabs` are in every Level Designer; prefabs in `prefabs` make the module a Level Designer of its own, picked in the designer switch. Write what is built from code as a getter, as above, so a hot reload updates it. See the editor's [ARCHITECTURE.md](https://github.com/just-unknown-dev/just-game-engine-editor/blob/main/ARCHITECTURE.md#the-module-contract) for every member.

## What is in it

| Area | What |
|------|------|
| The contract | `EditorModule` and its contributions: prefabs, tools, overlays, snap providers, docks, workspaces, toolbar buttons, settings sections, inspector sections, field editors and accessories, scene-tree actions, asset kinds and actions, markers, views, checks; tools, sections and overlays added to another's window (`workspaceContributions`, by `WorkspaceIds`) |
| The scope | `EditorScope`: one editor's registries and services in a `just_di` container — the scene state, undo, the codec and scene store, preferences, the log, the project's tags, physics layers and colours |
| Undo | `EditorHistory`, `EditorCommand`, the entity and hierarchy commands, `ComponentEdit` |
| Project files | `ProjectFiles` (whole-or-nothing writes, safe renames, paths kept inside the project), `PackageAssetPaths`, `AssetIndex` |
| The inspector | `buildComponentSections`, the field rows, `FieldEditorBuilder`, `ComponentEditorExtras`, `CollectionEditor`, `AddComponentPicker` |
| The Level Designer | `DesignerSession`, `LevelToolHandler`, `PathTool`, `DesignerOverlay`, `SnapProvider`, `SmartSnap`, `GridTopology`, `PrefabDefinition` |
| The viewport | `EditorView`, `EntityPicker`, `RayEntityPicker`, `ViewportOverlay`, `ViewportHandles`, `EditorMarker` |
| Keys | `CommandRegistry`, `DesignerCommand`, `KeyBinding`, `EditorKeys` (Cmd on macOS, Ctrl elsewhere), `EditorKeyClaim` |
| The kit | buttons, fields, controls, dialogs, the workspace frame, `EditorDropdown`, `showEditorMenu`, `EditorScrollbar`, `ScrubbableNumberField`, the snackbar, `EditorTheme`, `EditorMetrics` |

## Libraries

- `just_editor_core.dart`: what a module imports.
- `kit.dart`: the UI kit alone (the dropdown, menus, scroll bars, number fields and the snackbar among it), for a tool that draws like the editor.
- `io.dart`: `dart:io`'s files, folders, platform and processes, or stand-ins with the same members on the web, which throw if called.
- `host.dart`: everything, for the editor that hosts modules — the parts a module never calls included: `EditorScopeHost` (rebuilding the scope's registries, adding the built-ins, connecting its docks, asset reloads and split views) and `EditorLogSession` (the log's capture session).

## Testing a module

`EditorScope(world: World()..initialize(), modules: [CoinModule()])` gives a scope over a bare world with no editor: a module's contributions, its prefabs and its commands can be tested against it (`example/example.dart`'s `main` does this). A test that needs the editor's own tools or a running plugin — a Level Designer session, the 3-D view — takes `just_game_engine_editor` as a dev dependency and makes the scope with `builtIns: const [BuiltInEditorModule.new]`.

## Links

- Source and issues: [github.com/just-unknown-dev/just-editor-core](https://github.com/just-unknown-dev/just-editor-core)
- The editor: [`just_game_engine_editor`](https://pub.dev/packages/just_game_engine_editor), its [Quick Start Guide](https://github.com/just-unknown-dev/just-game-engine-editor/blob/main/QUICKSTART.md) and [Architecture](https://github.com/just-unknown-dev/just-game-engine-editor/blob/main/ARCHITECTURE.md)
- Contributing and conduct: [CONTRIBUTING.md](https://github.com/just-unknown-dev/just-editor-core/blob/main/CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](https://github.com/just-unknown-dev/just-editor-core/blob/main/CODE_OF_CONDUCT.md)
