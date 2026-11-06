import 'package:just_game_engine/just_game_engine.dart'
    show SceneMode, Signal, TagDefinition;
import 'package:meta/meta.dart';

import '../assets/scope_assets.dart';
import '../designer/grid/square_grid.dart';
import '../designer/layer_preset.dart';
import '../designer/prefab_pictures.dart';
import '../designer/scope_designer.dart';
import '../inspector/scope_inspector.dart';
import '../project/scope_project.dart';
import '../scene/scene_validator.dart';
import '../scene/scope_scene.dart';
import '../scope/editor_scope.dart';
import '../view/ray_entity_picker.dart';
import 'editor_contributions.dart';
import 'editor_marker.dart';
import 'editor_module.dart';
import 'editor_views.dart';
import 'module_failure_reporter.dart';
import 'module_registry.dart';
import 'prefab_variant.dart';
import 'tiled_object_mapper.dart';
import 'viewport_handles.dart';
import 'viewport_overlay.dart';
import 'workspace_contributions.dart';
import 'workspace_host.dart';
import '../designer/designer_parts.dart';
import '../inspector/inspector_parts.dart';
import '../project/project_state.dart';

/// One kind of thing the modules contribute, as the wiring last read it:
/// cleared and filled again on every rebuild, then put in order when the
/// kind has one.
final class _Contributions<T> {
  _Contributions([this._order]);

  final int Function(T item)? _order;
  final List<T> _items = [];

  /// A copy, read-only.
  List<T> get items => List.unmodifiable(_items);

  /// The list itself, to look through.
  Iterable<T> get live => _items;

  void clear() => _items.clear();

  void addAll(Iterable<T> items) => _items.addAll(items);

  void sort() {
    final order = _order;
    if (order != null) _items.sort((a, b) => order(a).compareTo(order(b)));
  }
}

/// The modules' side of one [EditorScope]: the modules registered with it,
/// what each contributes as last read, and the reading — once all of them
/// have joined, after each hot reload, and when the Level Designer is
/// switched to another module's. `ScopeModules` and `ScopeHost` are its
/// public face.
@internal
final class ScopeWiring {
  ScopeWiring._(this._scope) {
    // The project's tags take what the modules' code declares.
    ProjectState.of(_scope).declaredTags = _declaredTags;
  }

  /// [scope]'s, made when first asked for.
  static ScopeWiring of(EditorScope scope) => scope.service<ScopeWiring>(
    () => ScopeWiring._(scope),
    dispose: (w) => w.dispose(),
  );

  final EditorScope _scope;

  /// How a module's mistake is told: in the scope's log while it lives.
  late final ModuleFailureReporter failures = ModuleFailureReporter(
    log: () => _scope.isDisposed ? null : _scope.log,
  );

  /// The modules registered with the editor.
  late final ModuleRegistry modules = _scope.service<ModuleRegistry>(
    () => ModuleRegistry(failures: failures),
    dispose: (m) => m.disposeAll(),
  );

  /// The modules whose [EditorModule.onRegister] has run: once each, however
  /// many times the registries are rebuilt.
  final Set<EditorModule> _registered = Set.identity();

  bool _readWhenBuilt = false;

  final settingsSections = _Contributions<SettingsSection>((c) => c.order);
  final docks = _Contributions<DockDefinition>((c) => c.order);
  final toolbarButtons = _Contributions<ToolbarButton>((c) => c.order);
  final gettingStartedTips = _Contributions<GettingStartedTip>((c) => c.order);
  final workspaces = _Contributions<WorkspaceDefinition>((c) => c.order);
  final assetActions = _Contributions<AssetAction>((c) => c.order);
  final tiledObjectMappers = _Contributions<TiledObjectMapper>((c) => c.order);
  final validators = _Contributions<SceneValidator>();
  final sceneTreeActions = _Contributions<SceneTreeAction>((c) => c.order);
  final rowDecorations = _Contributions<SceneTreeRowDecoration>((c) => c.order);
  final entityIcons = _Contributions<EntityIcon>((c) => c.order);
  final protectionRules = _Contributions<EntityProtectionRule>();
  final markers = _Contributions<EditorMarker>();
  final pickTests = _Contributions<EntityRayTest>();
  final prefabPictures = _Contributions<PrefabPicture>();
  final viewportOverlays = _Contributions<ViewportOverlay>((c) => c.order);
  final workspaceContributions = _Contributions<WorkspaceContribution>(
    (c) => c.order,
  );
  final viewportHandles = _Contributions<ViewportHandles>();
  final prefabVariants = _Contributions<PrefabVariant>();

  late final List<_Contributions<Object?>> _all = [
    settingsSections,
    docks,
    toolbarButtons,
    gettingStartedTips,
    workspaces,
    assetActions,
    tiledObjectMappers,
    validators,
    sceneTreeActions,
    rowDecorations,
    entityIcons,
    protectionRules,
    markers,
    pickTests,
    prefabPictures,
    viewportOverlays,
    workspaceContributions,
    viewportHandles,
    prefabVariants,
  ];

  /// The endings of the JSON files the modules declared as theirs
  /// ([EditorModule.dataFileSuffixes]), lower case.
  Set<String> dataFileSuffixes = const {};

  /// What `ScopeModules.reloadAssets` calls: set by the editor while it runs.
  void Function(Iterable<String> paths)? assetReloader;

  /// What `ScopeModules.openDock` calls: set by the editor.
  void Function(String id)? dockOpener;

  // ── Joining ───────────────────────────────────────────────────────────

  /// [module] joins as the scope is made: registered, and every module's
  /// contributions read once the last has joined.
  void attach(EditorModule module, {required bool builtIn}) {
    if (builtIn) {
      modules.registerBuiltIn(module);
    } else {
      modules.register(module);
    }
    if (_readWhenBuilt) return;
    _readWhenBuilt = true;
    _scope.whenBuilt(reload);
  }

  /// See `ScopeHost.addBuiltIn`.
  void addBuiltIn(EditorModule Function(EditorScope scope) make) {
    final module = make(_scope);
    final there = modules.byId(module.id);
    if (there != null) {
      // One of its id is there already: this one goes unused, and so does
      // whatever it opened as it was made.
      if (!identical(there, module)) {
        try {
          module.dispose();
        } catch (error, stack) {
          failures.report(module, 'disposing it', error, stack);
        }
      }
      return;
    }
    modules.registerBuiltIn(module);
    reload();
  }

  // ── The Level Designer chosen ─────────────────────────────────────────

  /// See `ScopeModules.activeDesigner`.
  final Signal<String?> activeDesigner = Signal(
    null,
    debugLabel: 'activeDesigner',
  );

  /// See `ScopeModules.designersFor`.
  List<EditorModule> designersFor(SceneMode mode) => [
    for (final module in modules.all)
      if (module.designerModes.contains(mode)) module,
  ];

  /// See `ScopeModules.designerModules`.
  List<EditorModule> get designerModules {
    final module = _designerFor(activeDesigner.value);
    return module == null ? const [] : [module];
  }

  /// [id]'s module when it designs the open scene's mode.
  EditorModule? _designerFor(String? id) {
    final module = id == null ? null : modules.byId(id);
    return module != null &&
            module.designerModes.contains(_scope.sceneState.editingMode)
        ? module
        : null;
  }

  /// See `ScopeModules.selectDesigner`.
  void selectDesigner(String? id) {
    final next = _designerFor(id) == null ? null : id;
    if (activeDesigner.value == next) return;
    // Rebuilt before anyone hears about it, so a listener sees the new
    // palette and grid rather than the old ones.
    activeDesigner.setSilent(next);
    _rebuildDesigner();
    activeDesigner.dispatchNotifications();
  }

  // ── Reading the modules ───────────────────────────────────────────────

  List<TagDefinition> _declaredTags() => [
    for (final module in modules.withBuiltIns)
      ...?_fromModule(module, 'tags', () => module.tags),
  ];

  /// See `ScopeHost.reassemble`.
  void reassemble() {
    _scope.theme.resetPresets();
    final context = EditorModuleContext(scope: _scope, isDebug: _scope.isDebug);
    for (final module in modules.withBuiltIns) {
      if (!_registered.contains(module)) continue;
      _fromModule(module, 'onReassemble', () => module.onReassemble(context));
    }
    reload();
    _scope.theme.refreshCurrent();
  }

  /// What [module] says through [read]; [fallback] — and the failure
  /// reported — when it throws. A module with a bug must not stop the
  /// editor from starting, or leave a rebuild half done.
  T? _fromModule<T>(
    EditorModule module,
    String what,
    T Function() read, [
    T? fallback,
  ]) {
    try {
      return read();
    } on Object catch (error, stack) {
      failures.report(module, what, error, stack);
      return fallback;
    }
  }

  /// Everything [module] adds to the editor's registries, read before any
  /// of it is added — a module whose getter throws adds nothing, rather
  /// than half of what it brings — and returned as what adds it.
  void Function() _contributionsOf(EditorModule module) {
    final fieldEditors = module.fieldEditors;
    final inheritedColors = module.inheritedColors;
    final componentExtras = module.componentExtras;
    final commands = module.commands;
    final keyBindings = module.keyBindings;
    final settingsSections = module.settingsSections;
    final docks = module.docks;
    final toolbarButtons = module.toolbarButtons;
    final gettingStartedTips = module.gettingStartedTips;
    final workspaces = module.workspaces;
    final assetActions = module.assetActions;
    final tiledObjectMappers = module.tiledObjectMappers;
    final validators = module.validators;
    final sceneTreeActions = module.sceneTreeActions;
    final rowDecorations = module.rowDecorations;
    final entityIcons = module.entityIcons;
    final protectionRule = module.protectionRule;
    final inspectorSections = module.inspectorSections;
    final fieldAccessories = module.fieldAccessories;
    final viewFactories = module.viewFactories;
    final markers = module.markers;
    final pickTests = module.pickTests;
    final prefabPictures = module.prefabPictures;
    final assetKinds = module.assetKinds;
    final viewportOverlays = module.viewportOverlays;
    final workspaceContributions = module.workspaceContributions;
    final viewportHandles = module.viewportHandles;
    final prefabVariants = module.prefabVariants;
    final themePresets = module.themePresets;
    return () {
      final scope = _scope;
      final inspector = InspectorParts.of(scope);
      scope.fieldEditors.registerAll(fieldEditors, override: true);
      scope.fieldEditors.inheritedColors.addAll(inheritedColors);
      scope.extras.registerAll(componentExtras);
      scope.commands.registerAll(commands, override: true);
      scope.commands.bindAll(keyBindings);
      this.settingsSections.addAll(settingsSections);
      this.docks.addAll(docks);
      this.toolbarButtons.addAll(toolbarButtons);
      this.gettingStartedTips.addAll(gettingStartedTips);
      this.workspaces.addAll(workspaces);
      this.assetActions.addAll(assetActions);
      this.tiledObjectMappers.addAll(tiledObjectMappers);
      this.validators.addAll(validators);
      this.sceneTreeActions.addAll(sceneTreeActions);
      this.rowDecorations.addAll(rowDecorations);
      this.entityIcons.addAll(entityIcons);
      if (protectionRule != null) protectionRules.addAll([protectionRule]);
      inspector.sections.addAll(inspectorSections);
      inspector.accessories.addAll(fieldAccessories);
      EditorViews.of(scope).factories.addAll(viewFactories);
      this.markers.addAll(markers);
      this.pickTests.addAll(pickTests);
      this.prefabPictures.addAll(prefabPictures);
      assetKinds.forEach(scope.assetKinds.add);
      this.viewportOverlays.addAll(viewportOverlays);
      this.workspaceContributions.addAll(workspaceContributions);
      this.viewportHandles.addAll(viewportHandles);
      this.prefabVariants.addAll(prefabVariants);
      themePresets.forEach(scope.theme.register);
    };
  }

  /// See `ScopeHost.reload`.
  void reload() {
    final scope = _scope;
    final inspector = InspectorParts.of(scope);
    scope.fieldEditors.clear();
    scope.extras.clear();
    scope.commands.clear();
    for (final kind in _all) {
      kind.clear();
    }
    inspector
      ..sections.clear()
      ..accessories.clear();
    EditorViews.of(scope).factories.clear();
    // What a file is, for the browser and drops: the editor's kinds and the
    // modules'.
    scope.assetKinds.replaceAll(const []);
    final context = EditorModuleContext(scope: scope, isDebug: scope.isDebug);
    for (final module in modules.withBuiltIns) {
      final add = _fromModule(
        module,
        'what it adds to the editor',
        () => _contributionsOf(module),
      );
      if (add != null) _fromModule(module, 'adding what it brings', add);
      // Once per module: setup that loads files or installs into the engine
      // must not run again on each rebuild — see [reassemble].
      if (_registered.add(module)) {
        _fromModule(module, 'onRegister', () => module.onRegister(context));
      }
    }
    _registered.retainWhere(modules.withBuiltIns.contains);
    // The modules' own JSON files, never taken for sprite atlases.
    dataFileSuffixes = {
      for (final module in modules.withBuiltIns)
        for (final suffix
            in _fromModule(
                  module,
                  'dataFileSuffixes',
                  () => module.dataFileSuffixes,
                ) ??
                const <String>[])
          suffix.toLowerCase(),
    };
    // Made when first asked for — reading it scans the scenes — and kept
    // in step with the modules from then on.
    if (ProjectState.of(scope).tagsMade) {
      scope.tags.setDeclared(_declaredTags());
    }
    // The bindings are as built: the keys changed in the settings go over
    // them, on this and every later rebuild.
    scope.commands.markBuilt();
    if (scope.isFollowingSettings) {
      scope.commands.applyShortcuts(scope.prefs.settings.value.shortcuts);
    }
    for (final kind in _all) {
      kind.sort();
    }
    inspector.sections.sort((a, b) => a.order.compareTo(b.order));
    // A workspace whose module went away gives the viewport back. The
    // editor's own never go away: a reload must not shut one that is open.
    final host = WorkspaceHost.of(scope);
    final open = host.activeWorkspace.value;
    if (open != null &&
        !workspaces.live.any((w) => w.id == open.definition.id)) {
      host.activeWorkspace.value = null;
    }
    // A designer whose module went away, or no longer designs this kind of
    // scene, falls back to the built-in one.
    final active = activeDesigner.value;
    if (active != null && _designerFor(active) == null) {
      activeDesigner.setSilent(null);
    }
    _rebuildDesigner();
    if (active != activeDesigner.value) activeDesigner.dispatchNotifications();
  }

  /// Rebuilds what the Level Designer shows from the built-ins and the
  /// chosen designer's module; the other designers wait to be chosen.
  void _rebuildDesigner() {
    final scope = _scope;
    final parts = DesignerParts.of(scope)
      ..categories.clear()
      ..controls.clear()
      ..panels.clear()
      ..grid = const SquareGrid();
    final prefabs = scope.prefabs..clear();
    // The editor's own prefabs, whichever designer is chosen; then what
    // every module shares; then the chosen designer's.
    // Each module's part read whole, or — when it throws — left out.
    final builtIns = modules.builtIns;
    for (final module in builtIns) {
      prefabs.registerAll(
        _fromModule(module, 'prefabs', () => module.prefabs) ?? const [],
      );
    }
    for (final module in modules.withBuiltIns) {
      prefabs.registerAll(
        _fromModule(module, 'sharedPrefabs', () => module.sharedPrefabs) ??
            const [],
      );
    }
    final layers = scope.layers
      ..clear()
      ..registerAll(LayerPresetRegistry.builtIn);
    final chosen = designerModules;
    for (final module in [...builtIns, ...chosen]) {
      final part = _fromModule(
        module,
        'its Level Designer',
        () => (
          categories: module.prefabCategories,
          controls: module.statusControls,
          panels: module.designerPanels,
          grid: module.gridTopology,
          layers: module.layers,
        ),
      );
      if (part == null) continue;
      parts.categories.addAll(part.categories);
      parts.controls.addAll(part.controls);
      parts.panels.addAll(part.panels);
      parts.grid = part.grid ?? parts.grid;
      layers.registerAll(part.layers);
    }
    for (final module in chosen) {
      prefabs.registerAll(
        _fromModule(module, 'prefabs', () => module.prefabs) ?? const [],
      );
    }
    parts.controls.sort((a, b) => a.order.compareTo(b.order));
    parts.panels.sort((a, b) => a.order.compareTo(b.order));
  }

  /// Disposes [activeDesigner]; the scope does, when it is disposed.
  void dispose() => activeDesigner.dispose();
}
