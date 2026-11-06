import 'package:flutter/widgets.dart';
import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;
import 'package:just_game_engine/just_game_engine.dart';

import '../designer/prefab_registry.dart';
import '../scene/scene_validator.dart';
import '../scene/scope_scene.dart';
import '../scope/editor_scope.dart';
import '../view/editor_view.dart';
import '../view/ray_entity_picker.dart';
import 'editor_contributions.dart';
import 'editor_marker.dart';
import 'editor_module.dart';
import 'editor_views.dart';
import 'level_aids.dart';
import 'module_registry.dart';
import 'prefab_variant.dart';
import 'scope_wiring.dart';
import 'tiled_object_mapper.dart';
import 'viewport_handles.dart';
import 'viewport_overlay.dart';
import 'workspace_contributions.dart';
import 'workspace_host.dart';
import 'open_workspace.dart';

/// What the modules make of an [EditorScope]: the modules themselves and
/// everything they contribute — docks, workspaces, toolbar buttons, the
/// views and what is drawn over them, checks, asset actions — the Level
/// Designer chosen, the workspace open, and which entities they protect.
extension ScopeModules on EditorScope {
  /// The modules registered with this editor.
  ModuleRegistry get modules => ScopeWiring.of(this).modules;

  // ── Level aids ────────────────────────────────────────────────────────

  /// What the modules know about how levels are played: each one's
  /// [LevelAids].
  List<LevelAids> get levelAids => [
    for (final module in modules.withBuiltIns) ?module.levelAids,
  ];

  /// How the player moves, by the first module that knows; null when none
  /// does.
  MovementProfile? get movement {
    for (final aids in levelAids) {
      final profile = aids.movementOf(world);
      if (profile != null) return profile;
    }
    return null;
  }

  /// The kill height, by the first module that knows; null for none.
  double? get killHeight {
    for (final aids in levelAids) {
      final height = aids.killHeight(world);
      if (height != null) return height;
    }
    return null;
  }

  // ── The viewport ──────────────────────────────────────────────────────

  /// [prefab]'s picture for the palette, [size] pixels square: the first
  /// module's that draws one; null for its icon.
  Widget? prefabPictureOf(PrefabDefinition prefab, double size) {
    for (final picture in ScopeWiring.of(this).prefabPictures.live) {
      final drawn = picture(prefab, size);
      if (drawn != null) return drawn;
    }
    return null;
  }

  /// The icons the viewport draws at entities of a kind: the editor's own,
  /// then each module's.
  List<EditorMarker> get markers => ScopeWiring.of(this).markers.items;

  /// What knows the real shape of some entities, for picking in 3-D.
  List<EntityRayTest> get pickTests => ScopeWiring.of(this).pickTests.items;

  /// The endings of the JSON files the modules declared as theirs
  /// ([EditorModule.dataFileSuffixes]), lower case: never sprite atlases.
  Set<String> get dataFileSuffixes => ScopeWiring.of(this).dataFileSuffixes;

  /// What the modules add to the window [workspaceId] of kind [T] — its
  /// toolbar's tools, its panel's sections, its view's overlays — in
  /// order.
  List<T> workspaceContributionsFor<T extends WorkspaceContribution>(
    String workspaceId,
  ) => [
    for (final c in ScopeWiring.of(this).workspaceContributions.live)
      if (c is T && c.workspaceId == workspaceId) c,
  ];

  /// What lets the author drag points of the selection in the viewport.
  List<ViewportHandles> get viewportHandles =>
      ScopeWiring.of(this).viewportHandles.items;

  /// The other ways the prefabs offered in space are offered too.
  List<PrefabVariant> get prefabVariants =>
      ScopeWiring.of(this).prefabVariants.items;

  /// What the modules draw over the viewport, back to front.
  List<ViewportOverlay> get viewportOverlays =>
      ScopeWiring.of(this).viewportOverlays.items;

  /// The ids of the [viewportOverlays] turned off.
  ValueNotifier<Set<String>> get hiddenOverlays =>
      EditorViews.of(this).hiddenOverlays;

  /// Turns the viewport overlay [id] on or off.
  void toggleOverlay(String id) {
    final hidden = {...hiddenOverlays.value};
    if (!hidden.remove(id)) hidden.add(id);
    hiddenOverlays.value = hidden;
  }

  /// The camera the view is seen through; a bare one before the engine
  /// has a viewport.
  OutputCamera get mainCamera => EditorViews.of(this).mainCamera();

  /// How the editor sees the scene — what everything that draws over the
  /// viewport, picks or pans goes through: the view for the scene's mode
  /// (a module's — the editor's own 3-D view among them — see
  /// [EditorModule.viewFactories], else the 2-D view on [mainCamera]). One
  /// per mode, kept; switching mode hands the camera to the other.
  EditorView get editorView => EditorViews.of(this).editorView;

  /// The view of the open scene's mode, whatever stands in for it (a pane
  /// of a split viewport, while it is drawn or handled).
  EditorView get sceneView => EditorViews.of(this).sceneView;

  /// The running game's camera brain, or null for a scope over a bare world
  /// or an engine that has not started. Camera gizmos, the LIVE badge and
  /// Solo read it.
  CameraBrain? get cameraBrain => EditorViews.of(this).cameraBrain;

  // ── What the modules add to the editor's windows ──────────────────────

  /// Module sections in the settings dialog, by order.
  List<SettingsSection> get settingsSections =>
      ScopeWiring.of(this).settingsSections.items;

  /// Module docks appended after the built-in ones, by order.
  List<DockDefinition> get docks => ScopeWiring.of(this).docks.items;

  /// The workspaces the modules add — the hosting editor's own among
  /// them — by order.
  List<WorkspaceDefinition> get workspaces =>
      ScopeWiring.of(this).workspaces.items;

  /// Scene checks modules add to the editor's own.
  List<SceneValidator> get validators => ScopeWiring.of(this).validators.items;

  /// What modules offer to do with files in the Assets dock, by order.
  List<AssetAction> get assetActions => ScopeWiring.of(this).assetActions.items;

  /// What modules make of the objects in an imported Tiled map, by order.
  List<TiledObjectMapper> get tiledObjectMappers =>
      ScopeWiring.of(this).tiledObjectMappers.items;

  /// Module buttons over the viewport, by order: after the built-in play
  /// toolbar, or in the tool column ([ToolbarButton.slot]).
  List<ToolbarButton> get toolbarButtons =>
      ScopeWiring.of(this).toolbarButtons.items;

  /// What modules say on the start card, shown while no scene is open, by
  /// order.
  List<GettingStartedTip> get gettingStartedTips =>
      ScopeWiring.of(this).gettingStartedTips.items;

  /// Module entries in the scene tree's context menu, by order.
  List<SceneTreeAction> get sceneTreeActions =>
      ScopeWiring.of(this).sceneTreeActions.items;

  /// Module widgets drawn on every scene tree row, by order.
  List<SceneTreeRowDecoration> get rowDecorations =>
      ScopeWiring.of(this).rowDecorations.items;

  /// What the modules say the entities of their game look like.
  List<EntityIcon> get entityIcons => ScopeWiring.of(this).entityIcons.items;

  /// The icon for [entity]: a module's, if one claims it.
  IconData? iconFor(Entity entity) {
    for (final icon in ScopeWiring.of(this).entityIcons.live) {
      final found = icon.of(entity);
      if (found != null) return found;
    }
    return null;
  }

  /// Reloads what the editor shows from [paths] — project files or
  /// `packages/<name>/…` keys — after a tool or a module wrote them, each
  /// kind once. The editor connects this; before it does, nothing happens.
  void reloadAssets(Iterable<String> paths) =>
      ScopeWiring.of(this).assetReloader?.call(paths);

  /// Opens the dock called [id] — `'assets'`, `'logs'` — where the editor
  /// shows docks. Until the editor connects it, nothing happens.
  void openDock(String id) => ScopeWiring.of(this).dockOpener?.call(id);

  // ── Workspaces ────────────────────────────────────────────────────────

  /// The workspace that has the viewport, with the file it was opened on;
  /// null while the level has it.
  Signal<OpenWorkspace?> get activeWorkspace =>
      WorkspaceHost.of(this).activeWorkspace;

  /// Whether an open workspace fills the editor instead of sitting in it as
  /// a dialog. The author's choice, kept while the editor runs.
  Signal<bool> get workspaceFullScreen =>
      WorkspaceHost.of(this).workspaceFullScreen;

  /// Switches [workspaceFullScreen]: an open workspace goes from a dialog
  /// to filling the editor, or back.
  void toggleWorkspaceFullScreen() =>
      workspaceFullScreen.value = !workspaceFullScreen.value;

  /// Opens the workspace called [id], on [path] if given. False when no
  /// module provides it.
  ///
  /// Over an open workspace with unsaved work, the open one is asked first
  /// (see [setWorkspaceCloseGuard]); it opens only if that one agrees. True
  /// then says only that it was asked: watch [activeWorkspace] for whether
  /// it opened.
  bool openWorkspace(String id, {String? path}) =>
      WorkspaceHost.of(this).openWorkspace(id, path: path);

  /// What the open workspace wants asked before it goes — "save your
  /// changes?" — or null to go without asking. Closing or replacing the
  /// workspace clears it.
  ///
  /// [of] is the workspace asking; the open one when null. Clearing is
  /// only ever for its own: a workspace let go after another has opened
  /// in its place does not take the new one's question with it.
  ///
  /// A question from a workspace that is no longer the open one — an
  /// async save in it that finished after the switch — is not taken: the
  /// open one would be asked a question its window cannot show.
  void setWorkspaceCloseGuard(
    Future<bool> Function()? guard, {
    OpenWorkspace? of,
  }) => WorkspaceHost.of(this).setWorkspaceCloseGuard(guard, of: of);

  /// Closes the open workspace once its guard agrees. True when it closed.
  Future<bool> requestCloseWorkspace() =>
      WorkspaceHost.of(this).requestCloseWorkspace();

  /// Opens whichever workspace best fits [path]'s ending. False when none
  /// does.
  bool openInWorkspace(String path) =>
      WorkspaceHost.of(this).openInWorkspace(path);

  /// Closes the open workspace at once. A workspace calls this itself once
  /// it has asked about its own unsaved work; anything else closing one
  /// goes through [requestCloseWorkspace].
  void closeWorkspace() => WorkspaceHost.of(this).closeWorkspace();

  // ── The Level Designer chosen ─────────────────────────────────────────

  /// The level designer in use: a module id, or null for the built-in
  /// one. Changed through [selectDesigner].
  Signal<String?> get activeDesigner => ScopeWiring.of(this).activeDesigner;

  /// The modules that bring a level designer of their own for the open
  /// scene's mode, in registration order: what the designer's switch lists
  /// after the built-in one.
  List<EditorModule> get designers =>
      ScopeWiring.of(this).designersFor(sceneState.editingMode);

  /// The modules that are a level designer for [mode]
  /// ([EditorModule.designerModes]).
  List<EditorModule> designersFor(SceneMode mode) =>
      ScopeWiring.of(this).designersFor(mode);

  /// The modules whose designer contributions are live: the chosen
  /// designer's while the open scene is of a mode it designs, or none for
  /// the built-in one.
  List<EditorModule> get designerModules =>
      ScopeWiring.of(this).designerModules;

  /// Switches the Level Designer to [id]'s module, or to the built-in one
  /// for null, an unknown id or a module that does not design the open
  /// scene's mode. Prefabs, layers, grid, palette categories, status
  /// controls and side-panel sections follow at once; an open session
  /// reloads its tools, overlays and module state.
  void selectDesigner(String? id) => ScopeWiring.of(this).selectDesigner(id);

  // ── Protected entities ────────────────────────────────────────────────

  /// The modules' rules for which entities must not be deleted; see
  /// [isProtected].
  List<EntityProtectionRule> get protectionRules =>
      ScopeWiring.of(this).protectionRules.items;

  /// Whether any module protects [entity].
  bool isProtected(Entity entity) => ScopeWiring.of(
    this,
  ).protectionRules.live.any((r) => r.isProtected(entity));

  /// [entities] less any a module protects ([isProtected]), or that has a
  /// protected entity under it — deleting a parent deletes what is under it.
  /// Each one kept is said in the log, so a delete that leaves something
  /// behind says why. Every delete the editor makes asks this first.
  List<Entity> deletable(Iterable<Entity> entities) {
    if (ScopeWiring.of(this).protectionRules.live.isEmpty) {
      return entities.toList();
    }
    final out = <Entity>[];
    for (final entity in entities) {
      final guard = protectedIn(entity);
      if (guard == null) {
        out.add(entity);
        continue;
      }
      final what = guard.name ?? 'Entity ${guard.id}';
      log.log(
        identical(guard, entity)
            ? '$what is protected by a module, so it was not deleted.'
            : '$what is protected by a module, so '
                  '${entity.name ?? 'what holds it'} was not deleted.',
        source: 'editor',
        category: 'scene',
        level: DebuggerLogLevel.warning,
      );
    }
    return out;
  }

  /// [entity] itself when a module protects it, else the first protected
  /// entity under it; null when none is.
  Entity? protectedIn(Entity entity) {
    if (isProtected(entity)) return entity;
    for (final id
        in entity.getComponent<ChildrenComponent>()?.childIds ??
            const <EntityId>[]) {
      final child = world.getEntity(id);
      if (child == null) continue;
      final found = protectedIn(child);
      if (found != null) return found;
    }
    return null;
  }
}
