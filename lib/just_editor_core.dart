/// What a module builds on: the editor's module contract, its scope and
/// services, the undo history and commands, the inspector's rows and
/// field editors, the Level Designer's tool and overlay API, and the UI
/// kit — everything a kit or an editor plugin needs, and nothing of the
/// editor's own windows.
///
/// The editor itself — `just_game_engine_editor` — hosts modules built on
/// this. What only that host does — rebuilding a scope's registries and
/// wiring it to its windows (`ScopeHost`), running the log's capture
/// session (`EditorLogSession`) — is in `host.dart`.
library;

export 'src/assets/assets.dart' hide AssetReferences;
export 'src/designer/designer.dart';
export 'src/history/history.dart';
export 'src/input/input.dart';
export 'src/inspector/inspector.dart';
export 'src/log/log.dart' hide EditorLogSession, createEditorLogStorage;
export 'src/look/look.dart' hide ViewportLook;
export 'src/modules/modules.dart' hide ScopeHost;
export 'src/project/project.dart';
export 'src/scene/scene.dart' hide SceneModeFilters, UniqueNamer;
export 'src/scene_tree/scene_tree.dart';
export 'src/scope/scope.dart' hide ScopeAuthoredState;
export 'src/settings/settings.dart' hide OverlaySettingsPrefKeys;
export 'src/view/view.dart';
