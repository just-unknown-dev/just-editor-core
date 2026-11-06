import '../scene/scene_validator.dart';
import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:meta/meta.dart';

import '../scope/editor_scope.dart';
import '../scene/editor_scene_state.dart';
import '../view/editor_view.dart';
import '../view/ray_entity_picker.dart';
import '../assets/asset_kind.dart';
import 'level_aids.dart';
import 'editor_marker.dart';
import 'prefab_variant.dart';
import 'viewport_handles.dart';
import 'viewport_overlay.dart';
import 'workspace_contributions.dart';
import '../designer/designer_overlay.dart';
import '../history/editor_history.dart';
import '../designer/layer_preset.dart';
import '../designer/prefab_pictures.dart';
import '../designer/prefab_registry.dart';
import '../inspector/component_extras.dart';
import '../inspector/field_editor.dart';
import '../designer/designer_command.dart';
import '../designer/grid/grid_topology.dart';
import '../designer/designer_session.dart';
import '../designer/snap_provider.dart';
import '../designer/designer_contributions.dart';
import '../look/editor_theme_data.dart';
import 'editor_contributions.dart';
import '../inspector/inspector_contributions.dart';
import 'scope_wiring.dart';
import 'tiled_object_mapper.dart';
import '../designer/tools/level_tool.dart';

/// What a module is handed when it registers.
class EditorModuleContext {
  const EditorModuleContext({required this.scope, required this.isDebug});

  /// The editor this module was registered into.
  final EditorScope scope;

  /// The world being edited.
  jge.World get world => scope.world;

  /// Whether this is a debug build. Always true in practice — the editor
  /// does not start otherwise — but explicit beats assumed.
  final bool isDebug;
}

/// What a tool needs from the designer session it belongs to.
///
/// Tools are built per session rather than once, because anything that edits
/// the scene has to act on *that* session's selection and push onto *that*
/// session's undo history. Neither exists until the designer opens.
class DesignerToolContext {
  const DesignerToolContext({
    required this.scope,
    required this.world,
    required this.sceneState,
    required this.history,
    required this.uniqueName,
  });

  /// The editor the session belongs to; its codec, definitions and log.
  final EditorScope scope;

  /// The world being edited.
  final jge.World world;

  /// Selection and grid state shared with the rest of the editor.
  final EditorSceneState sceneState;

  /// The undo stack. Every edit a tool makes should be one command on it.
  final EditorHistory history;

  /// Returns an entity name not already in use, built from `prefix`.
  final String Function(String prefix) uniqueName;
}

/// Everything a project contributes to the editor, in one place.
///
/// The editor knows how to select, move, align, snap, layer and undo. It knows
/// nothing about platforms, patrol routes or spawn zones, and it should not
/// have to. A module is how a game teaches it: what can be placed, what tools
/// make sense, what to draw on the viewport, and how its own components
/// appear in the inspector.
///
/// Every member has a default, so a module that only adds two prefabs is two
/// overridden getters. Pass modules to the [EditorScope], which they join as
/// it is made ([attach]):
///
/// ```dart
/// EditorScope(engine: engine, modules: [MyGameModule()]);
/// ```
///
/// Contributions are read again after every hot reload, so an edited getter
/// takes effect without a restart: a new prefab, dock, command or key shows
/// once the reload is done. See [onRegister] and [onReassemble] for what runs
/// once and what runs each time.
abstract class EditorModule implements ScopeModule {
  /// Stable identifier. Registering twice with the same id replaces the first.
  String get id;

  /// Joins [scope] as it is made: registers this module with it — ahead of
  /// every other when [builtIn] — and has the scope read every module's
  /// contributions once all of them have joined. The scope's constructor
  /// calls this; a module does not override it.
  @override
  @nonVirtual
  void attach(EditorScope scope, {required bool builtIn}) =>
      ScopeWiring.of(scope).attach(this, builtIn: builtIn);

  /// Display name, shown wherever modules are listed.
  String get name;

  /// Optional icon for that listing.
  IconData? get icon => null;

  /// Inspector editors for this module's own field types, by
  /// [jge.FieldType.id]. Registered over the built-ins, so a module can also
  /// replace one of those.
  Map<String, FieldEditorBuilder> get fieldEditors => const {};

  /// Editor-only additions to how components are inspected: header actions,
  /// a custom section, a replacement editor for one field.
  List<ComponentEditorExtras> get componentExtras => const [];

  /// Palette entries the draw and paint tools can place — while this
  /// module is the Level Designer (see [providesLevelDesigner]).
  List<PrefabDefinition> get prefabs => const [];

  /// Palette entries every Level Designer offers, whichever module is
  /// designing: beside the editor's own shapes, as the Interface module's
  /// Text is. Offering them does not make this module a designer.
  List<PrefabDefinition> get sharedPrefabs => const [];

  /// Viewport tools, built fresh for each designer session. Ids should be
  /// prefixed to avoid colliding with built-ins; reusing a built-in's id
  /// replaces it.
  List<LevelToolHandler> createTools(DesignerToolContext context) => const [];

  /// The shape of the designer's cells, when this module changes it. The
  /// last module to answer wins; null keeps the square grid.
  GridTopology? get gridTopology => null;

  /// Palette groups this module's prefabs use, with their order.
  List<PrefabCategory> get prefabCategories => const [];

  /// Ways of snapping, built fresh per session. Priority decides where they
  /// sit relative to the built-ins (entities 100, grid 0).
  List<SnapProvider> createSnapProviders(DesignerToolContext context) =>
      const [];

  /// State this module keeps per designer session — a route being edited,
  /// say. Tools reach it with `context.stateOf<T>()`; it survives a reload.
  /// Released through [disposeSessionState].
  Object? createSessionState(DesignerToolContext context) => null;

  /// Releases [state], which [createSessionState] made: its session has
  /// closed, or this module has left it (another designer chosen). For
  /// state that holds signals, listeners or timers. Nothing by default.
  void disposeSessionState(Object state) {}

  /// What this module saves in the scene file's `editor` section, under its
  /// own id. Null saves nothing.
  Map<String, Object?>? saveEditorData(DesignerSession session) => null;

  /// Restores what [saveEditorData] wrote for this scene.
  void restoreEditorData(DesignerSession session, Map<String, Object?> data) {}

  /// Controls added to the designer's status bar.
  List<StatusBarControl> get statusControls => const [];

  /// Sections added to the designer's side panel.
  List<SidePanelSection> get designerPanels => const [];

  /// Things drawn over the level, each with its own visibility toggle.
  List<DesignerOverlay> get overlays => const [];

  /// Named draw-order layers this genre expects.
  List<LayerPreset> get layers => const [];

  /// Whether this module is a level designer of its own: an entry in the
  /// designer's switch beside the built-in one, whose designer
  /// contributions are live only while it is chosen.
  ///
  /// True by default when the module contributes anything the switch
  /// scopes — prefabs, overlays, layers, a grid, palette categories, status
  /// controls or side-panel sections. A designer made only of tools, snap
  /// providers or session state overrides this to return true.
  bool get providesLevelDesigner =>
      prefabs.isNotEmpty ||
      overlays.isNotEmpty ||
      layers.isNotEmpty ||
      gridTopology != null ||
      prefabCategories.isNotEmpty ||
      statusControls.isNotEmpty ||
      designerPanels.isNotEmpty;

  /// The scene modes this module is a level designer for: the switch lists
  /// it only while a scene of one of them is open, as the platformer kit is
  /// listed for 2-D levels and a 3-D kit for 3-D ones.
  ///
  /// Worked out from what it places and draws — a kit whose prefabs and
  /// overlays are all 3-D designs 3-D scenes — and 2-D when they say
  /// nothing (a designer of tools alone). Empty when it is no designer
  /// ([providesLevelDesigner]).
  Set<jge.SceneMode> get designerModes {
    if (!providesLevelDesigner) return const {};
    final modes = <jge.SceneMode>{
      for (final mode in jge.SceneMode.values)
        if (prefabs.any((p) => p.dimensions.allows(mode)) ||
            overlays.any((o) => o.dimensions.allows(mode)))
          mode,
    };
    return modes.isEmpty ? const {jge.SceneMode.twoD} : modes;
  }

  /// Add-Component picker groups this module's definitions use, in the order
  /// they should appear after the built-in groups.
  List<String> get componentGroups => const [];

  /// Commands this module adds, or replaces by reusing a built-in's id.
  List<DesignerCommand> get commands => const [];

  /// Key chords for commands, this module's or anyone's. A chord bound here
  /// takes precedence over a built-in binding of the same chord.
  List<KeyBinding> get keyBindings => const [];

  /// Sections on the settings dialog's Modules tab.
  List<SettingsSection> get settingsSections => const [];

  /// Bottom docks beside the built-in ones.
  List<DockDefinition> get docks => const [];

  /// Full-screen tools that take the viewport: a sprite editor, a dialogue
  /// graph. Opened with `ScopeModules.openWorkspace`.
  List<WorkspaceDefinition> get workspaces => const [];

  /// What it adds to windows — its own or others' (the editor's material
  /// windows: [WorkspaceIds]): tools on their toolbars, sections in their
  /// panels, overlays over their views. Each window builds them from the
  /// [WorkspaceView] it hands them.
  List<WorkspaceContribution> get workspaceContributions => const [];

  /// Checks this module makes of the open scene, listed in the Problems
  /// dock beside the editor's own: a level with no spawn point, say.
  List<SceneValidator> get validators => const [];

  /// What this module can do with a file in the Assets dock.
  List<AssetAction> get assetActions => const [];

  /// Groups of the tool strip this module's tools go under, beside the
  /// editor's own (`ToolGroups.builtIn`).
  List<ToolGroup> get toolGroups => const [];

  /// What objects of an imported Tiled map become: a spawn point, a coin.
  List<TiledObjectMapper> get tiledObjectMappers => const [];

  /// Buttons after the built-in play controls.
  List<ToolbarButton> get toolbarButtons => const [];

  /// What the start card — shown over the viewport while no scene is open —
  /// says about this module: where the player starts, the key that draws a
  /// path.
  List<GettingStartedTip> get gettingStartedTips => const [];

  /// Entries in an entity's scene-tree context menu.
  List<SceneTreeAction> get sceneTreeActions => const [];

  /// Things drawn at the end of scene-tree rows.
  List<SceneTreeRowDecoration> get rowDecorations => const [];

  /// Icons for the kinds of entity this module's game is made of — a
  /// coin, a hazard, a checkpoint. Asked in [EntityIcon.order], and the
  /// first non-null answer is the one drawn.
  List<EntityIcon> get entityIcons => const [];

  /// Which entities this module says must not be deleted; see
  /// `ScopeModules.isProtected`.
  EntityProtectionRule? get protectionRule => null;

  /// Palettes offered in the settings dialog beside the built-in accents.
  List<ThemePreset> get themePresets => const [];

  /// Inspector sections after the component sections.
  List<InspectorSection> get inspectorSections => const [];

  /// The views this module offers, by scene mode: what the viewport looks
  /// through while a scene of that mode is edited. A later module's wins;
  /// with none, the editor's own (`GameCameraEditorView` in 2-D,
  /// `OrbitFlyEditorView` in 3-D).
  Map<jge.SceneMode, EditorView Function(EditorScope scope)>
  get viewFactories => const {};

  /// Icons the viewport draws at every entity of a kind, so things with
  /// nothing to draw can be found (see [EditorMarker]).
  List<EditorMarker> get markers => const [];

  /// What knows the real shape of some entities, so a 3-D pick lands on
  /// what is drawn rather than its box (a model's triangles).
  List<EntityRayTest> get pickTests => const [];

  /// What this game kit knows about how its levels are played — its
  /// player's jump and slopes, its kill height, starting play from a
  /// point — for the Level Designer's aids. Asked of every module.
  LevelAids? get levelAids => null;

  /// Pictures for prefabs in the palette (see [PrefabPicture]): asked in
  /// turn, the first that draws one wins; a prefab without one shows its
  /// icon.
  List<PrefabPicture> get prefabPictures => const [];

  /// Kinds of file it knows: how the asset browser shows them and what
  /// dropping one on the viewport makes (see [AssetKind]).
  List<AssetKind> get assetKinds => const [];

  /// What it draws over the viewport while authoring, with the Level
  /// Designer open or not (see [ViewportOverlay]).
  List<ViewportOverlay> get viewportOverlays => const [];

  /// Points it lets the author drag to edit the selected entity: a
  /// polygon's corners (see [ViewportHandles]).
  List<ViewportHandles> get viewportHandles => const [];

  /// Other ways to offer the prefabs any module offers in space: a physics
  /// module's Solid and Trigger of every shape (see [PrefabVariant]).
  List<PrefabVariant> get prefabVariants => const [];

  /// What an unset colour field falls back to, for the components this
  /// module knows — so the inspector can show it rather than a blank.
  List<InheritedColor> get inheritedColors => const [];

  /// What the inspector puts beside component fields, and tells of the
  /// edits made through them (see [FieldAccessory]).
  List<FieldAccessory> get fieldAccessories => const [];

  /// Tags this module's game code looks for by name — `enemy`, say. The
  /// project's tag list shows them as built in: they cannot be renamed or
  /// deleted there, since code would go on looking for the old name.
  List<jge.TagDefinition> get tags => const [];

  /// Endings of the JSON files this module owns (`.ui.json`), so the editor
  /// never takes one for a sprite atlas — which is what it assumes of any
  /// `.json` it does not recognise.
  List<String> get dataFileSuffixes => const [];

  /// Called once, when this module joins an editor, after the built-ins are
  /// in place. One-time setup belongs here: loading files, installing into
  /// the engine, recovering from a crash. A hot reload does not call it
  /// again — see [onReassemble].
  void onRegister(EditorModuleContext context) {}

  /// Called after each hot reload, before the editor reads this module's
  /// contributions again. For anything [onRegister] set up from code that
  /// may have changed — a loader it handed out, say — and must be done
  /// again. Must not undo what a play-test in progress relies on.
  void onReassemble(EditorModuleContext context) {}

  /// Called when a scene finishes loading.
  void onSceneOpened(String sceneName) {}

  /// Called as scene [sceneName] is saved, before its file is written: for
  /// files of this module's own that the scene refers to — a terrain's
  /// heights — to be written with it. A throw is reported, and the scene
  /// is saved all the same.
  Future<void> onSceneSaving(String sceneName) async {}

  /// Called every editor tick, [deltaTime] seconds after the last.
  void onUpdate(double deltaTime) {}

  /// A file in the project changed — saved by a tool, dropped in from
  /// outside. Whatever this module shows from it should show the new one.
  void onAssetChanged(String path) {}

  /// A play-test started (true) or stopped (false).
  void onPlayStateChanged(bool playing) {}

  /// Called when the owning editor is disposed.
  void dispose() {}
}
