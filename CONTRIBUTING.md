# Contributing to Just Editor Core

Thank you for your interest in contributing to **Just Editor Core**, the package every `just_game_engine_editor` module builds on. Bug fixes, features, tests and documentation are all welcome.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs and Suggesting Features](#reporting-bugs-and-suggesting-features)
- [Development Setup](#development-setup)
- [Working Against Unpublished Dependencies](#working-against-unpublished-dependencies)
- [How the Package Fits Together](#how-the-package-fits-together)
- [Running the Tests](#running-the-tests)
- [Coding Guidelines](#coding-guidelines)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Commit Message Convention](#commit-message-convention)
- [License](#license)

---

## Code of Conduct

This project, and `just_game_engine_editor` beside it, follows our [Code of Conduct](CODE_OF_CONDUCT.md). By taking part you agree to its terms. Report unacceptable behaviour privately, as its [Enforcement](CODE_OF_CONDUCT.md#enforcement) section says.

---

## Reporting Bugs and Suggesting Features

Before opening an issue, search the [existing issues](https://github.com/just-unknown-dev/just-editor-core/issues) and check that the problem happens on the latest version.

A bug report should have:

- a clear title;
- steps to reproduce, and what you expected instead of what happened;
- the output of `flutter --version`, and the platform. The editor that runs modules runs on Windows, macOS or Linux; for a build that fails on Android, iOS, the web or wasm, give the target and the build command;
- the versions of `just_editor_core`, `just_game_engine_editor`, `just_game_engine` and each module package involved, from `pubspec.lock`;
- the smallest module that shows the problem: an `EditorModule` with only the members it needs, or better, a test that makes `EditorScope(world: World()..initialize(), modules: [...])` and fails (see [Running the Tests](#running-the-tests));
- for a bug in saving or undo, the scene file (`assets/scenes/<name>.scene.json`), or the smallest one that shows the problem, and whether the scene is 2-D or 3-D;
- the Console's lines from around the problem, which are also in `.editor_logs/editor_runtime.jsonl`. A module that throws while it registers is left out, and the log says why. The Console replays the last session too, so check the times;
- for a keyboard bug, the keyboard layout, and whether you changed the key in Settings → Keyboard;
- for a bug in how the kit looks, a screenshot, the window size, and your Appearance and Accessibility settings.

Some bugs belong elsewhere. If the problem shows with a bare `EditorScope` and no editor, it is most likely here. The editor's windows, docks, overlay and right panel, the Level Designer and Level Map themselves, the timeline, play-testing and the built-in tools belong to [`just_game_engine_editor`](https://github.com/just-unknown-dev/just-game-engine-editor/issues). A module's tools belong to its package: the interface editor to `just_ui_editor`, the Sprite Studio to `just_sprite_editor`, the Input Actions editor to `just_input_editor`, the material add-on to `just_material_editor`, the Asset Store window to `just_asset_store_editor`, and a kit's prefabs and tools to `just_platformer_kit`, `just_third_person_kit` or `just_world_builder_kit`. Components and their definitions belong to `just_game_engine`; the scene format, its migrations and the starter scenes to `just_game_engine_formats`; the colour picker to `just_colours`.

For a feature, open an issue labelled **`enhancement`** that describes the problem it solves and how it should behave. The package's scope is what modules build on: the `EditorModule` contract and its contributions, `EditorScope` and its services, undo and the commands, the scene codec and store, project files, the inspector's rows, the Level Designer's tool and overlay API, views and picking, keys, and the UI kit. A tool the user sees belongs to the editor or a module; this package gains what more than one of them needs. A change to `EditorModule` affects every module, and a change to what `SceneCodec` and `SceneStore` write affects every game's levels, so open the issue first and agree the approach before you write it.

---

## Development Setup

| Tool | Minimum version |
|------|-----------------|
| Dart | 3.11.0 |
| Flutter | 3.47.1 |

The package compiles for every Flutter platform, web and wasm included, and its tests run with a plain `flutter test` on any machine. To see a change in the editor itself you need Windows, macOS or Linux. It is published on pub.dev; module packages take it as a dependency, and `just_game_engine_editor` re-exports it.

Clone it into a folder named after the package, and check out any `just_*` package you work with beside it, under its own package name. The overrides below look for them there.

```bash
git clone https://github.com/just-unknown-dev/just-editor-core.git just_editor_core
cd just_editor_core
flutter pub get
flutter test
```

If you're working from the Just engine monorepo, run every command from `packages/just_editor_core`.

If `flutter pub get` cannot find a version of a `just_*` package, that version is not published yet: see the next section.

To see a change running:

- **In a test.** Most changes can be seen, and should be held, by a test against a bare `EditorScope`. `example/example.dart` is a module (`CoinModule`) whose `main` makes a scope over a bare world and checks what the module adds; it needs neither the editor nor a window.
- **In the editor.** Check out [`just_game_engine_editor`](https://github.com/just-unknown-dev/just-game-engine-editor) beside this repository and point it at your checkout with a `pubspec_overrides.yaml` (`just_editor_core: path: ../just_editor_core`, as below). Then run its example app (`cd example`, `flutter run -d windows`, or `macos`, `linux`), or a game's editor entry point in a debug build; in a project made with `just create`, `just dev link <folder>` points the game at every `just_*` checkout in `<folder>`.
- **In a module.** Point the module's package at your checkout the same way, to see what your change means for it.

The editor writes scenes, backups and logs relative to the working directory. Leave them out of your pull request.

---

## Working Against Unpublished Dependencies

The package's `just_*` dependencies are `just_game_engine`, `just_game_engine_formats`, `just_signals`, `just_di`, `just_debugger`, `just_colours` and `just_storage`. When a change needs an unreleased version of one, check it out next to this repository and point this package at it with a `pubspec_overrides.yaml` in the repository root:

```yaml
# pubspec_overrides.yaml: local only, never commit it.
dependency_overrides:
  just_game_engine:
    path: ../just_game_engine
  just_game_engine_formats:
    path: ../just_game_engine_formats
```

List only what you have checked out. `just_game_engine` has `just_*` dependencies of its own (`just_physics_engine`, `just_graphics_engine`, `just_audio_engine`, `just_inputs`, `just_tiled` and others); if the engine you check out needs unreleased versions of them, override them the same way. Then run `flutter pub get`. Delete the file (or the entries) and run `flutter pub get` again to go back to the published versions. `.gitignore` already leaves the file out.

Do not change `pubspec.yaml` to a path dependency. If your pull request needs a version of a `just_*` package that is not published yet, say so in the pull request: this package can only be released after it.

Ten packages build on this one: the editor, `just_game_engine_editor`, the host that runs the modules; the modules `just_ui_editor`, `just_sprite_editor`, `just_input_editor`, `just_material_editor` and `just_asset_store_editor`; and the kits `just_platformer_kit`, `just_third_person_kit` and `just_world_builder_kit`. A release of this package comes before the releases of theirs that need it. If you change the public API, above all `EditorModule`, point at least the editor at your checkout and run its `flutter analyze` and `flutter test`, and say in the pull request what each of them will need.

---

## How the Package Fits Together

`EditorScope` holds one editor's registries and services in a `just_di` container. `EditorModule`s fill it: the host's built-ins first (`builtIns:`), then the modules a game passes in, and `reload()` builds every registry again from them. The host, `just_game_engine_editor`, makes the scope, wires it to its windows (`EditorScopeHost`, in `host.dart`), and draws its docks, inspector and Level Designer from what the registries hold. The editor's [ARCHITECTURE.md](https://github.com/just-unknown-dev/just-game-engine-editor/blob/main/ARCHITECTURE.md#the-module-contract) explains the module contract member by member.

The libraries:

| Library | For |
|---------|-----|
| `lib/just_editor_core.dart` | What a module imports: everything a module may call, without the host's parts (`EditorScopeHost`, `EditorLogSession` and a few helpers) |
| `lib/host.dart` | Everything, for the editor that hosts modules |
| `lib/kit.dart` | The UI kit alone, with the theme, its sizes and the settings they follow, for a tool that draws like the editor |
| `lib/io.dart` | `dart:io`'s files, folders, platform and processes on native platforms; stand-ins with the same members on the web |

In `lib/src/`:

| Folder | Contents |
|--------|----------|
| `extension/` | `EditorModule` and its contributions (editor, designer and workspace contributions), asset kinds, `AssetIndex` and `AssetReferences`, markers, viewport overlays and handles, prefab variants, Tiled object mappers, level aids |
| `scope/` | `EditorScope`, and `EditorScopeHost`, the host's side of it |
| `model/` | `EditorHistory` and the entity and hierarchy commands, `ComponentEdit`, `CommandRegistry`, `DesignerCommand` and `KeyBinding`, `EditorKeys` and `ModifierKeys`, `EditorSceneState`, `EditorViewState`, `Designer3DState`, `SceneCodec`, `SceneStore`, `UnknownComponents` |
| `designer/` | The Level Designer's API: `DesignerSession`, the tools (`LevelToolHandler`, `PathTool`, `ToolRegistry`), overlays, snapping (`SnapProvider`, `SmartSnap`), grids, prefabs, layers, and in 3-D the working plane, placement and arrays |
| `inspector/` | `DefinitionSection` and `buildComponentSections`, the field rows, `FieldEditorRegistry`, component extras, `CollectionEditor`, `AddComponentPicker`, `LivePreview` |
| `view/` | `EditorView`, `GameCameraEditorView`, `EntityPicker`, `RayEntityPicker` and `RayTriangles`, `HandleDragSession` |
| `project/` | The project's tags, physics layers and colours, and the tag uses in saved files |
| `settings/` | `EditorPrefs` and `SettingPref`, the editor's own store, the overlay and gizmo settings, the chrome's state |
| `services/` | The log (`EditorLogService`), `ProjectFiles`, `PackageAssetPaths` |
| `validation/` | `SceneValidator`, `ValidationContext`, `SceneProblem` |
| `scene_tree/` | `SceneTreeModel` and the row tile |
| `look/` | `EditorTheme`, `EditorThemeData`, `EditorMetrics`, `ThemeController`, `ViewportLook`; `kit/` and `widgets/`, the shared widgets every panel, dock, dialog and module is built from |
| `io/` | The `dart:io` seam behind `package:just_editor_core/io.dart` |

Beside it, `example/example.dart` is a module, what pub.dev shows a module author first, and `test/` holds the tests, with shared helpers in `test/support/`.

A few rules hold the package together. Keep them:

- **It compiles everywhere.** A module, and the editor that imports this package, sit in a game's editor entry point, and the game still builds for Android, iOS, the web and wasm. So `lib/` imports `dart:io` only behind a conditional import: in the seam (`lib/src/io/io_native.dart`) and in the native halves of the log's and the settings' storage (`*_io.dart`). Everything else imports `io.dart`. Tests may import `dart:io`.
- **The core knows no host.** Nothing here imports `just_game_engine_editor` or a module's package: the dependency goes one way. What only the host calls goes in `host.dart` alone, hidden from `just_editor_core.dart`, as `EditorScopeHost` and `EditorLogSession` are; what only the editor's own windows draw stays in the editor.
- **Files are written safely.** Write a project file through `ProjectFiles` (`writeString`, `writeBytes`: whole or not at all; `rename`: safe for a change of case, never over another file), and refuse a path read out of a file that would leave the project (`ProjectFiles.isContained`, `PackageAssetPaths.isWritable`). Compare paths with `ProjectFiles.samePath`, never `==`: Windows and macOS fold case.
- **Every OS's keys.** Bind keys through `KeyBinding` and read modifiers through `ModifierKeys` or `EditorKeys`, never `isControlPressed`: the primary modifier is Cmd on macOS, where Backspace deletes too. Settings store `Ctrl+` on every OS.
- **The game reads what the editor saves.** `SceneCodec` encodes components only through their `ComponentDefinition`, from the registry the game loads with, and the game loads the same file through the engine's `SceneLoader`. The format version (`SceneFormat.current`), the migrations and the starter scenes (`SceneStarters`) live in `just_game_engine_formats`, so a format change starts there. A scene's `editor` section is the editor's alone; a module writes under its id with `saveEditorData`.
- **Nothing saved is lost.** Components no definition can read are kept in `UnknownComponents` and written back unchanged. A scene or project file that is there but cannot be read is an error, never an empty one to be saved over. Anything that previews a change in the live world registers an authored-state guard (`EditorScope.authoredStateGuards`; `LivePreview` does), so no preview reaches a save or a play-test.
- **One undo stack.** Every edit to the scene is an `EditorCommand` on `scope.history` (`EditorHistory`), one step per gesture: a field is a `ComponentFieldCommand`, an edit to a whole component goes through `ComponentEdit.begin` … `commit`, and several changes are one `CompositeCommand`. An undone delete brings an entity back under a new id, so a command finds its entity as it is now (`EditorSceneState.entityRebuilt`), never by the id it first saw.
- **No process-wide registries.** Every registry and service belongs to an `EditorScope`; two scopes share nothing, and `reload()` rebuilds them all from the built-ins and the registered modules, so nothing piles up across hot reloads. The built-ins register exactly as a module does.
- **One module's mistake stays its own.** A module that throws while it registers is left out and said in the log, and the others load; one replaced by another of its id is let go of properly. Anything new that calls into a module must keep that.
- **What is built from code is a getter.** Styles, definitions, markers, `SettingPref`s and shared vectors are getters (or consts), never `static final`, so a hot reload brings them up to date and nobody changes a shared value in place. `EditorModule.onRegister` runs once per module; `onReassemble` runs after each hot reload.
- **Every `EditorModule` member has a default** (an empty list, null, or nothing to do), so a module overrides only what it adds. Give a new member one too. Ids are saved: a module's id keys its `editor` data in scenes, dock ids key the layout in the `editor.docks` preference, and command ids key the user's changed keys in `editor.keys.shortcuts`, so never rename one.
- **`just_game_engine_cli` knows this package by name.** Its release check (`ReleaseRules`) fails a release build that holds `just_editor_core` or the class name `EditorScope`, and `just create` adds `just_editor_core` to a new game at a set version. Rename `EditorScope`, or release a new minor version, and `just_game_engine_cli` must change with it.

---

## Running the Tests

Run every command from the repository root: `test/hygiene_test.dart`, `test/hot_reload_hygiene_test.dart` and `test/editor_dropdown_test.dart` read `lib/` from disk.

```bash
# The whole suite.
flutter test

# One file.
flutter test test/editor_history_test.dart
```

`dart_test.yaml` gives every test twice the default 30 s, for the tests that boot an engine or touch the disk on a busy machine. No test here needs a GPU.

**Tests that hold the rules.**

- `test/hygiene_test.dart` and `test/hot_reload_hygiene_test.dart` fail on a `static final` or top-level `final` that makes a `TextStyle`, `PrefabDefinition`, `WorkspaceDefinition`, `DockDefinition`, `EditorMarker`, `SettingPref`, `Vector2` or `Vector3`, or that reads `EditorTheme`. Make it a getter.
- `test/editor_dropdown_test.dart` fails on a Material `DropdownButton` or `DropdownButtonFormField` in `lib/`. Use `EditorDropdown`.
- `test/scene_starters_parity_test.dart` encodes the engine's live components through `SceneCodec` and compares them with the starter scenes in `just_game_engine_formats`. It fails when a component's saved form changes, here or in `just_game_engine`: update the starters in `just_game_engine_formats` to match.
- `test/example_test.dart` keeps `example/example.dart` compiling, and checks that what it says the module adds is what a scope holds. README.md quotes the example, so change both together.
- `test/kit_test.dart` holds the kit's promises: a target never under 24 px, a toolbar that never spills over its edge, a field that keeps what was typed exactly once.
- `test/editor_scope_test.dart` and `test/module_registry_test.dart` hold the module rules above; `test/editor_keys_test.dart` presses the keys as a Mac does.
- `test/entity_commands_test.dart`, `test/editor_history_failures_test.dart` and `test/history_mark_and_scene_read_test.dart` hold undo and the save rules; `test/scene_store_test.dart`, `test/project_files_test.dart`, `test/project_services_test.dart` and `test/package_asset_paths_test.dart` hold the file rules.

**Writing tests.**

- `EditorScope(world: World()..initialize())` gives a scope over a bare world, with no engine and no editor; pass `modules:` to test a module's contributions. Dispose it at the end of the test. Two tests get two scopes and share nothing.
- `MemorySettingsStore` (`test/support/memory_settings_store.dart`), passed as `settingsStore:`, keeps preferences in memory, so a test touches neither the disk nor `path_provider`.
- Put files in a folder from `Directory.systemTemp.createTempSync`, passed as the scope's `scenesRoot` or a `SceneStore`'s root. Never use a fixed path: `flutter test` runs test files in parallel processes. Remove the folder with `deleteWhenFree` (`test/support/real_io.dart`): on Windows a folder watcher lets go a moment after it is closed.
- Wait for real file I/O by its outcome with `waitUntil` (`test/support/real_io.dart`), never for a fixed time; inside `testWidgets`, run it in `tester.runAsync`.
- Keep pure geometry pure: `test/designer_geometry_test.dart` needs no `World` and no `Engine`, and the code it tests must not either.

---

## Coding Guidelines

- **Formatting.** Code is formatted with `dart format`. Format the files you change, and only those, keeping each file's line endings:

  ```bash
  dart format <the files you changed>
  ```

- **Analysis.** `flutter analyze` reports no issues today. Keep it that way: no errors, warnings or infos. The rules are in `analysis_options.yaml`: `flutter_lints`, with `build/` excluded.
- **State.** Editor state is `just_signals`: a `Signal` on the service that owns it, a `Computed` for what derives from it, read in widgets through `SignalBuilder` or `SignalConsumer` (`ThrottledSignalConsumer` for a panel that follows values changing every frame of a drag), with `batch()` around the writes of one operation. Don't add a `ChangeNotifier` for editor state.
- **The kit.** The editor's kit lives here, so a widget more than one panel or module needs belongs in it (`lib/src/look/kit/` or `lib/src/look/widgets/`), exported through `kit.dart` as well. Take colours from `EditorTheme` and sizes from `EditorMetrics`, so the theme and the accessibility settings reach them, and never make a target smaller than `EditorMetrics.minTarget`. Write font sizes as they read at 100%: `EditorLook` scales the text.
- **Keys.** A command with a key is a `DesignerCommand` in the scope's `CommandRegistry`, bound by a `KeyBinding`, so Settings → Keyboard can change it. A widget that acts on keys itself wraps itself in `EditorKeyClaim(claims: …)` with exactly those keys; otherwise both it and the editor act.
- **Disposal.** A `State.dispose` must not ask the `EditorScope` for anything: its container may already be closed. Hold what you need from the start.
- **Text.** What the user sees is plain English with British spelling ("colour"), as in the rest of the editor.
- **Documentation.** Give every public API you add a `///` doc comment: module authors read this package on pub.dev. Describe user-visible changes in [CHANGELOG.md](CHANGELOG.md). Update [README.md](README.md) when what a module author sees changes, and the editor's [ARCHITECTURE.md](https://github.com/just-unknown-dev/just-game-engine-editor/blob/main/ARCHITECTURE.md) (with a pull request there) when the module contract does.
- **Tests.** Add or update tests for any behaviour you change. A bug fix comes with a test that fails without it.
- **Dependencies.** Do not add a dependency without discussing it in an issue first. The editor and every module inherit it, and it must compile on every platform, web and wasm included.
- **Structure.** Match the existing folders under `lib/src/`. Export what a module needs through `lib/just_editor_core.dart`, and what only the host needs through `lib/host.dart` alone. Modules and the editor import the libraries, never files under `lib/src/`; the package's own tests may.

---

## Submitting a Pull Request

1. Create a topic branch from `main`:
   ```bash
   git checkout -b fix/redo-after-rebuild
   ```
2. Make your change, following the [Coding Guidelines](#coding-guidelines).
3. Check that everything passes:
   ```bash
   dart format --output=none --set-exit-if-changed <the files you changed>
   flutter analyze
   flutter test
   ```
4. For a change to the public API, run `flutter analyze` and `flutter test` in `just_game_engine_editor` (and in the modules it touches) against your checkout. Widget tests miss some of what a real window does (focus, hover, drags between panels): for a change to the kit, try it in the editor, and say in the pull request on which platform.
5. Commit with a [conventional commit message](#commit-message-convention).
6. Push to your fork and open a pull request against `main`. Say what changed and why, with before and after screenshots for a visible change. List any unpublished `just_*` version it needs, and any change it means for the editor, the modules and kits that build on this package, or `just_game_engine_cli`.
7. Answer review feedback.

Small pull requests are easier to review.

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependencies |

Use the area as the scope: `module` (the `EditorModule` contract), `scope`, `history` (undo and the commands), `scenes` (`SceneCodec`, `SceneStore`), `files` (`ProjectFiles`, `PackageAssetPaths`, the asset index), `inspector`, `designer`, `view`, `keys`, `project`, `settings`, `log`, `validation`, `scene-tree`, `kit` or `io`. Mark a change that breaks the public API or what the editor saves with `!` and a `BREAKING CHANGE:` footer.

**Examples:**
```
fix(history): find an entity rebuilt by an undone delete on redo
feat(module): let a module add a section to another's window
docs(contributing): explain the hot reload rule
```

---

## License

By contributing to Just Editor Core you agree that your contributions will be licensed under the terms in [LICENSE](LICENSE).
