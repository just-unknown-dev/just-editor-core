import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:just_di/just_di.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_storage/just_storage.dart';
import 'package:meta/meta.dart';

import '../io/io.dart';
import '../log/editor_log_service.dart';
import '../look/theme_controller.dart';
import '../settings/editor_chrome_state.dart';
import '../settings/editor_prefs.dart';
import '../settings/editor_storage.dart';
import '../settings/overlay_settings_store.dart';
import '../settings/overlay_ui_settings.dart';

/// What an [EditorScope] is built with that joins it as it is made: the
/// hosting editor's built-ins and the modules. `EditorModule` is the kind
/// modules are written as; this is all the scope itself knows of one.
abstract interface class ScopeModule {
  /// Joins [scope] — as one of the hosting editor's own when [builtIn] —
  /// while it is made. The scope's constructor calls this once for each,
  /// the built-ins first, in the order given.
  void attach(EditorScope scope, {required bool builtIn});
}

/// Everything one editor owns: its services and state, in a `just_di`
/// container that is disposed with it.
///
/// The scope itself knows the edited engine, the settings, the theme, the
/// chrome's state and the log. Every feature adds what it owns on top, as
/// an extension made the first time it is asked for ([service]) —
/// `ScopeScene` (`scope.sceneState`, `scope.codec`), `ScopeHistory`
/// (`scope.history`), `ScopeProject`, `ScopeAssets`, `ScopeDesigner`,
/// `ScopeInspector` — and `ScopeModules` adds what the modules contribute:
/// docks, workspaces, the editor's view. Importing `just_editor_core.dart`
/// brings them all.
///
/// Its services are its own: two scopes in one process — two tests, or
/// two editors side by side — have their own modules, commands, docks,
/// history and settings. A few things are the process's, because the
/// widgets that read them have no scope to ask: the look (`EditorTheme`,
/// `EditorMetrics`), the fields being typed in (`PendingFieldEdits`) and
/// the resolved package paths (`PackageAssetPaths.of`, one per project
/// folder). Component definitions come from the edited engine's [context]
/// (a bare world's own context in a test), which the *game* fills at boot
/// through its extensions; the scope reads them from there, so the editor
/// and the game cannot disagree.
///
/// ```dart
/// final scope = EditorScope(engine: engine, modules: [PlatformerModule()]);
/// ```
///
/// A test that needs no engine passes a bare [world] instead.
///
/// The scope brings no tools of its own. The editor that hosts it passes
/// its own as modules — `builtIns`, registered ahead of every other — and
/// a scope without them is the modules' alone: what a module's tests
/// make.
class EditorScope {
  /// A scope over `engine`, or over a bare `world` when there is none; one
  /// of the two is required.
  ///
  /// `builtIns` make the hosting editor's own modules, which join ahead of
  /// `modules` ([ScopeModule.attach]). `parent` is the container
  /// [container] falls back to. `log` and `settingsStore` replace the log
  /// service and the settings' store; a scope given its own store also
  /// keeps the colour palettes' recents off this machine's storage.
  /// `scenesRoot` is the scenes folder (the project's `assets/scenes` when
  /// null); given one, a test's, the tag, collision-layer and palette files
  /// are kept in it too. `projectRoot` is the project's folder
  /// ([projectRoot]); the working folder when null. `isDebug` is what
  /// modules are told ([isDebug]); the build's debug flag when null.
  EditorScope({
    Engine? engine,
    World? world,
    List<ScopeModule> modules = const [],
    List<ScopeModule Function(EditorScope scope)> builtIns = const [],
    DiContainer? parent,
    EditorLogService? log,
    this.scenesRoot,
    String? projectRoot,
    OverlaySettingsStore? settingsStore,
    bool? isDebug,
  }) : assert(engine != null || world != null, 'Pass an engine or a world'),
       engine = engine,
       _world = world,
       _projectRoot = projectRoot,
       _usesMachineStorage = settingsStore == null,
       container = DiContainer(parent: parent),
       isDebug = isDebug ?? kDebugMode {
    // The editor reads and writes the engine's scenes: it knows the
    // engine's own components, whatever context it was given.
    context.install(BuiltInComponents.extension);
    if (engine != null) container.registerSingleton<Engine>(engine);
    container
      ..registerSingleton<ComponentDefinitionRegistry>(context.definitions)
      ..registerLazySingleton<EditorPrefs>(
        () => EditorPrefs(
          store: settingsStore ?? OverlaySettingsStore(_editorStorage()),
        ),
        dispose: (p) => p.dispose(),
      )
      ..registerLazySingleton<ThemeController>(
        ThemeController.new,
        dispose: (t) => t.dispose(),
      )
      ..registerLazySingleton<EditorChromeState>(
        EditorChromeState.new,
        dispose: (c) => c.dispose(),
      )
      ..registerLazySingleton<EditorLogService>(() {
        final service = log ?? EditorLogService();
        followSettings((s) => service.maxEntries = s.consoleMaxEntries);
        return service;
      }, dispose: (l) => l.dispose());
    for (final make in builtIns) {
      make(this).attach(this, builtIn: true);
    }
    for (final module in modules) {
      module.attach(this, builtIn: false);
    }
    final built = _whenBuilt!;
    _whenBuilt = null;
    for (final callback in built) {
      callback();
    }
  }

  /// The container behind the typed accessors, for anything a module wants
  /// to register alongside.
  final DiContainer container;

  /// Whether this is a debug build, as the modules are told
  /// (`EditorModuleContext.isDebug`).
  final bool isDebug;

  /// The engine being edited, or null for a scope over a bare [world].
  final Engine? engine;

  final World? _world;

  /// The world being edited.
  ///
  /// Read lazily: an engine's world does not exist until it initialises, and
  /// the plugin is built before that.
  World get world => _world ?? engine!.world;

  /// What the edited engine knows — its component definitions, loaders and
  /// hooks — or, for a scope over a bare [world], that world's context.
  ///
  /// Available before the engine initialises: an engine makes its context
  /// when it is constructed.
  EngineContext get context => engine?.context ?? _world!.context;

  /// The scenes folder this scope was given — a test's — or null for the
  /// project's `assets/scenes`.
  final String? scenesRoot;

  final String? _projectRoot;

  /// The project's folder, with forward slashes: the one the scope was
  /// given, else the process's working folder — the project's, when the
  /// editor runs (`flutter run` starts there). Where the services that work
  /// on the project's files — the asset index, the scenes, a module's
  /// own — find them.
  String get projectRoot =>
      (_projectRoot ?? Directory.current.path).replaceAll(r'\', '/');

  /// Whether the scope was given its [projectRoot], rather than taking the
  /// working folder's.
  @internal
  bool get hasProjectRoot => _projectRoot != null;

  // ── Services ──────────────────────────────────────────────────────────

  final Set<Type> _services = {};

  /// Resolves a service by type. Prefer the typed accessors on hot paths.
  T get<T extends Object>() => container.get<T>();

  /// The scope's [T]: made by [make] the first time it is asked for, then
  /// the same one for the scope's life, and released through [dispose]
  /// with the scope. How a feature, a module or the host keeps something
  /// per editor without a field here.
  ///
  /// One registered in [container] ahead of that — a test's stand-in — is
  /// used instead, and [make] is never called.
  T service<T extends Object>(
    T Function() make, {
    void Function(T service)? dispose,
  }) {
    if (!_disposed && _services.add(T)) {
      try {
        container.registerLazySingleton<T>(make, dispose: dispose);
      } on DuplicateRegistrationException {
        // Registered ahead of the scope's own: that one is used.
      }
    }
    return container.get<T>();
  }

  /// Opens a child container for per-session services (a designer session's
  /// history, tools, snap providers). Closed by the caller.
  DiScope openSession({String? debugLabel}) =>
      container.createScope(debugLabel: debugLabel);

  List<void Function()>? _whenBuilt = [];

  /// Runs [callback] once the constructor is done — after every module has
  /// joined — or at once when it is done already. How the module wiring
  /// reads the modules' contributions once all of them are in.
  @internal
  void whenBuilt(void Function() callback) {
    final waiting = _whenBuilt;
    if (waiting == null) {
      callback();
    } else {
      waiting.add(callback);
    }
  }

  // ── The editor's own store ────────────────────────────────────────────

  final bool _usesMachineStorage;
  Future<JustStandardStorage>? _storage;

  // The editor's own store, opened once and shared by everything that
  // keeps something in it: two stores on one file drop each other's keys.
  // A store that cannot be reached — no platform to ask where, in a test —
  // is reported where it is read, not as an error no one handled the moment
  // it is opened.
  Future<JustStandardStorage> _editorStorage() =>
      _storage ??= (openEditorStorage()..ignore());

  /// Opens the editor's own store on this machine, shared by everything
  /// that keeps something in it — the settings, the colour picker's
  /// recents. Null for a scope given its own settings store: a test's,
  /// which keeps its hands off this machine's storage.
  @internal
  Future<JustStandardStorage> Function()? get machineStorage =>
      _usesMachineStorage ? _editorStorage : null;

  // ── Settings, look, chrome and log ────────────────────────────────────

  final List<void Function(OverlayUiSettings settings)> _followers = [];
  VoidCallback? _stopFollowingSettings;
  bool _following = false;

  /// Persisted overlay settings, built-in and module-declared.
  ///
  /// Made when first asked for — reading the store is the platform's
  /// business — and from then on the services follow them
  /// ([followSettings]).
  EditorPrefs get prefs {
    final prefs = container.get<EditorPrefs>();
    if (!_following) {
      _following = true;
      _stopFollowingSettings = prefs.settings.watch(_follow);
      _follow();
    }
    return prefs;
  }

  void _follow() {
    final settings = prefs.settings.value;
    for (final apply in List.of(_followers)) {
      apply(settings);
    }
  }

  /// Whether the services follow the settings yet: [prefs] has been made.
  @internal
  bool get isFollowingSettings => _following;

  /// Has [apply] take what a service follows from the settings — how much
  /// undo is kept, the steps snapping moves in, the keys that were changed
  /// — now when [prefs] is made already, else once it is, and again on
  /// every change.
  @internal
  void followSettings(void Function(OverlayUiSettings settings) apply) {
    _followers.add(apply);
    if (_following) apply(prefs.settings.value);
  }

  /// Transient overlay chrome state: panel widths, open dialogs.
  EditorChromeState get chrome => container.get<EditorChromeState>();

  /// The current theme and the presets to pick from.
  ThemeController get theme => container.get<ThemeController>();

  /// Editor log.
  EditorLogService get log => container.get<EditorLogService>();

  // ── The scene as authored ─────────────────────────────────────────────

  final List<void Function()> _authoredStateGuards = [];
  final List<bool Function()> _authoredStateHeld = [];

  /// Whether the world is, right now, something other than the scene as
  /// authored — a timeline preview showing a moment of it, a value
  /// previewed live. An autosave waits rather than end it.
  bool get isAuthoredStateHeld => _authoredStateHeld.any((held) => held());

  /// Called by whoever is about to read the scene as authored: a save, the
  /// snapshot a play-test starts from. Ends every preview.
  void restoreAuthoredState() {
    for (final restore in List.of(_authoredStateGuards)) {
      restore();
    }
  }

  /// Whether a play-test is on, paused or not — what an inspector showing
  /// live values follows. The plugin keeps it.
  final Signal<bool> isPlayTesting = Signal(false, debugLabel: 'playTesting');

  /// Around the game as the viewport shows it, so the colour picker's
  /// eyedropper can read a pixel of it. Set on the viewport by the overlay.
  final GlobalKey viewportCaptureKey = GlobalKey(debugLabel: 'viewport');

  // ── Disposal ──────────────────────────────────────────────────────────

  bool _disposed = false;

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  /// Disposes every service this scope owns, in reverse registration order.
  void dispose() {
    _disposed = true;
    _stopFollowingSettings?.call();
    isPlayTesting.dispose();
    container.close();
  }
}

/// What only the editor that hosts a scope touches of the scene as
/// authored: the ways of putting the world back to it. Exported by
/// `host.dart`; a module never needs it.
extension ScopeAuthoredState on EditorScope {
  /// Ways of putting the world back to the scene as authored
  /// ([EditorScope.restoreAuthoredState]), for whatever shows something
  /// else in it for a while — a timeline being previewed.
  List<void Function()> get authoredStateGuards => _authoredStateGuards;

  /// Tests of whether the world is held away from the scene as authored
  /// ([EditorScope.isAuthoredStateHeld]); whoever adds a guard can add one.
  List<bool Function()> get authoredStateHeld => _authoredStateHeld;
}
