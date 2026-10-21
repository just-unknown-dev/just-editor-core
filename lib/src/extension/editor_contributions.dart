import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../settings/editor_prefs.dart';
import '../scope/editor_scope.dart';

/// A page a module adds to the editor's settings dialog, listed under
/// Modules in its sidebar. Read and write your own [SettingPref]s through
/// [EditorPrefs].
class SettingsSection {
  const SettingsSection({
    required this.id,
    required this.title,
    required this.build,
    this.order = 100,
  });

  /// Names the page, unique among the modules' sections; the dialog opens
  /// it as `module:<id>`.
  final String id;

  /// The page's name in the sidebar, which the dialog's search matches.
  final String title;

  /// Lower sorts first among the modules' pages.
  final int order;

  /// Builds the page's content, drawn in a card of its own.
  final Widget Function(BuildContext context, EditorPrefs prefs) build;
}

/// How loudly a dock's badge speaks.
enum DockSeverity {
  /// Drawn in the accent colour.
  none,

  /// Drawn in the accent colour, like [none].
  info,

  /// Drawn in the theme's warning colour.
  warning,

  /// Drawn in the theme's error colour.
  error,
}

/// The small marker on a dock's tab: a count, a dot for "something new".
class DockBadge {
  const DockBadge(this.text, [this.severity = DockSeverity.none]);

  /// Short: `3`, `●`. Empty shows nothing.
  final String text;

  /// Which colour the badge is drawn in.
  final DockSeverity severity;
}

/// A fact a module's dock puts on the status bar: a live value that is
/// always in view — `Waves  3 left` — and a button to its dock, opened with
/// [openArgs].
class DockReadout {
  const DockReadout({
    required this.value,
    this.label,
    this.accent,
    this.openArgs,
  });

  /// What the number is — `FPS` on the Profiler's. The dock's own label
  /// when null.
  final String? label;

  /// Read a few times a second while the editor is open; keep it cheap.
  /// An empty string leaves the segment off the strip for now.
  final String Function(EditorScope scope) value;

  /// The colour of the segment's icon and text; the editor's secondary
  /// text colour when null.
  final Color? accent;

  /// Passed to the dock when the readout opens it — a preset filter, say.
  final Map<String, Object?>? openArgs;
}

/// What a dock remembers between launches: its filters, its view mode,
/// which folders were open. Small JSON-able values by key.
abstract class DockMemory {
  /// The value saved under [key], or null when none is or it is not a `T`.
  T? read<T>(String key);

  /// Saves [value] under [key]; null forgets the key.
  void write(String key, Object? value);
}

/// What a dock's content is built with.
class DockContext {
  const DockContext({
    required this.scope,
    required this.height,
    required this.onResize,
    required this.onClose,
    this.memory,
    this.args = const {},
  });

  /// The editor the dock is shown in: its registries, scene and services.
  final EditorScope scope;

  /// The dock's current height, in logical pixels.
  final double height;

  /// Called with the drag delta when the user resizes the dock.
  final ValueChanged<double> onResize;

  /// Closes the bottom panel; for a dock popped out into a window of its
  /// own, puts it back in the panel.
  final VoidCallback onClose;

  /// This dock's own remembered values; null where nothing persists.
  final DockMemory? memory;

  /// What the dock was opened with ([DockReadout.openArgs], a command).
  final Map<String, Object?> args;
}

/// A dock in the bottom panel: a tab beside the built-in ones (Console,
/// Assets, Timeline, Profiler, World…).
class DockDefinition {
  const DockDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.build,
    this.order = 100,
    this.defaultHeight = 280,
    this.tabBadge,
    this.readout,
    this.headerActions,
    this.keepAlive = false,
    this.pinnedByDefault = true,
  });

  /// Names the dock, unique among docks: [EditorScope.openDock] takes it,
  /// and its height, tab place and memory are saved under it.
  final String id;

  /// The tab's text, also used in the `+` menu and as the status-bar label
  /// when [readout] has none.
  final String label;

  /// Drawn on the tab and beside the dock's [readout].
  final IconData icon;

  /// Lower sorts first; the built-ins occupy 0–99.
  final int order;

  /// The panel's height while this dock is open, in logical pixels, until
  /// the user resizes it.
  final double defaultHeight;

  /// The marker on the tab itself.
  final DockBadge? Function(EditorScope scope)? tabBadge;

  /// This dock's segment of the status strip.
  final DockReadout? readout;

  /// Buttons for the panel's header while this dock is the active one.
  final List<Widget> Function(BuildContext context, DockContext dock)?
  headerActions;

  /// Keep the dock built while another tab is showing, so it loses nothing:
  /// a scroll position, a capture in progress. Costs what the dock costs.
  final bool keepAlive;

  /// Whether the dock starts as a tab; otherwise it waits in the `+` menu.
  final bool pinnedByDefault;

  /// Builds the dock's content, below the panel's tabs.
  final Widget Function(BuildContext context, DockContext dock) build;
}

/// What a workspace's content is built with.
class WorkspaceContext {
  const WorkspaceContext({
    required this.scope,
    required this.onClose,
    this.path,
    this.reloadAssets,
    this.fullScreen,
    this.onToggleFullScreen,
    this.setCloseGuard,
  });

  /// The editor the workspace opened in: its registries, scene and
  /// services.
  final EditorScope scope;

  /// Registers what to ask before the workspace goes — "save your
  /// changes?" — when another is opened over it; null clears it. A
  /// workspace with unsaved work sets one, and asks the same itself before
  /// calling [onClose].
  final void Function(Future<bool> Function()? guard)? setCloseGuard;

  /// Whether the workspace fills the editor right now, for a button that
  /// shows which way it will go. Null where the host has no such choice.
  final ValueListenable<bool>? fullScreen;

  /// Switches between the dialog and filling the editor. A workspace puts
  /// this on a button beside its close button.
  final VoidCallback? onToggleFullScreen;

  /// Closes the workspace and gives the viewport back to the level.
  final VoidCallback onClose;

  /// The project-relative file the workspace was opened on, if any.
  final String? path;

  /// Tells the editor a file the workspace wrote has changed, so the level
  /// shows the new version. Null where there is no running editor.
  final void Function(String path)? reloadAssets;
}

/// How an open workspace sits in the editor.
enum WorkspacePresentation {
  /// A large dialog over the editor, which stays visible, dimmed, around it.
  /// On a window too small to spare the margin it fills instead.
  dialog,

  /// Fills the editor.
  fullScreen,
}

/// A large tool a module adds — a sprite editor, a dialogue graph — opened
/// over the editor while the scene stays loaded underneath. One is open at a
/// time. While one is, the level's tools, keys and play controls stand down.
class WorkspaceDefinition {
  const WorkspaceDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.build,
    this.fileExtensions = const [],
    this.order = 100,
    this.presentation = WorkspacePresentation.dialog,
  });

  /// Names the workspace, unique among workspaces: what
  /// [EditorScope.openWorkspace] takes.
  final String id;

  /// The workspace's name, as the editor's messages give it:
  /// `<file> is open in <label>`.
  final String label;

  /// An icon that stands for the workspace, for buttons and menus that
  /// open it.
  final IconData icon;

  /// Lower sorts first; of two workspaces that fit a file equally well,
  /// the first opens it.
  final int order;

  /// How it sits in the editor when it opens. A
  /// [WorkspacePresentation.dialog] one can still be switched to fill the
  /// editor ([WorkspaceContext.onToggleFullScreen]).
  final WorkspacePresentation presentation;

  /// File endings this workspace opens, lower case, without the dot —
  /// `png`, `animator.json`. The longest match wins, so `animator.json`
  /// beats `json`.
  final List<String> fileExtensions;

  /// Builds the workspace's content, inside the frame the editor puts it
  /// in.
  final Widget Function(BuildContext context, WorkspaceContext workspace) build;

  /// How well this workspace fits [path]: the length of the ending it
  /// matched, 0 for none.
  int matchOf(String path) {
    final lower = path.toLowerCase();
    var best = 0;
    for (final ext in fileExtensions) {
      if (lower.endsWith('.$ext') && ext.length > best) best = ext.length;
    }
    return best;
  }
}

/// Something a module offers to do with a file in the Assets dock.
class AssetAction {
  const AssetAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.appliesTo,
    required this.run,
    this.order = 100,
  });

  /// Names the action, prefixed by its module: `tiles.create_tileset`.
  final String id;

  /// The action's text in menus, and the tooltip of its button.
  final String label;

  /// Drawn beside [label] in menus, and on the action's icon button.
  final IconData icon;

  /// Lower sorts first among the modules' actions.
  final int order;

  /// Whether to offer this for `path` (project-relative, forward slashes):
  /// in a file's or folder's menu, beside a folder in the folder tree and
  /// under a file's preview. `isDirectory` lets an action be a folder's
  /// "New …".
  final bool Function(String path, {required bool isDirectory}) appliesTo;

  /// Does the action on the project-relative `path` it was offered for.
  final void Function(EditorScope scope, String path) run;
}

/// Where a [ToolbarButton] stands over the viewport.
enum ToolbarSlot {
  /// On the play toolbar at the top left, in the modules' frame after the
  /// built-in Play, Pause, Stop and Level Designer buttons.
  playToolbar,

  /// In the column down the right, in a frame of its own under the
  /// transform tools (Q, W, E, R): a feature of the editor itself rather
  /// than a module's tool, such as the Asset Store. Not on the small bar a
  /// play-test shows with the editor stepped aside.
  toolColumn,
}

/// A button a module adds over the viewport: on the play toolbar after the
/// built-in Play, Pause, Stop and Level Designer buttons, or in the column
/// down the right (see [slot]).
class ToolbarButton {
  const ToolbarButton({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.order = 100,
    this.slot = ToolbarSlot.playToolbar,
    this.isEnabled,
    this.isActive,
  });

  /// Names the button, prefixed by its module.
  final String id;

  /// The button's face.
  final IconData icon;

  /// Shown when the pointer rests on the button: what it does.
  final String tooltip;

  /// Lower sorts first among the modules' buttons in the same [slot].
  final int order;

  /// Where it stands: with the modules' tools on the play toolbar, or in
  /// the column down the right under the transform tools.
  final ToolbarSlot slot;

  /// Whether the button can be pressed, asked each time the toolbar is
  /// built; null for always.
  final bool Function(EditorScope scope)? isEnabled;

  /// Whether the button is drawn lit, as a tool in use or a workspace that
  /// is open; asked each time the toolbar is built, null for never.
  final bool Function(EditorScope scope)? isActive;

  /// Called when the button is pressed while enabled.
  final void Function(EditorScope scope) onPressed;
}

/// A line a module adds to the start card, the guide shown over the
/// viewport while no scene is open: how to work with what the module
/// brings. One sentence, or two short ones.
class GettingStartedTip {
  const GettingStartedTip({
    required this.id,
    required this.text,
    this.icon,
    this.order = 100,
  });

  /// Names the tip, prefixed by its module.
  final String id;

  /// The tip itself, as shown under Tips on the start card.
  final String text;

  /// Drawn before the text; a light bulb when null.
  final IconData? icon;

  /// Lower sorts first among the tips.
  final int order;
}

/// An entry a module adds to an entity's context menu in the scene tree,
/// offered too in the viewport's menu for an entity under the pointer.
class SceneTreeAction {
  const SceneTreeAction({
    required this.id,
    required this.label,
    required this.run,
    this.icon,
    this.order = 100,
    this.isEnabled,
  });

  /// Names the action, unique among scene-tree actions: the menu tells
  /// which one was chosen by it.
  final String id;

  /// The entry's text in the menu.
  final String label;

  /// Drawn before [label]; none when null.
  final IconData? icon;

  /// Lower sorts first among the modules' entries.
  final int order;

  /// Whether the entry can be chosen for `entity`, asked as the menu
  /// opens; null for always.
  final bool Function(jge.Entity entity, EditorScope scope)? isEnabled;

  /// Does the action on the `entity` the menu was opened for.
  final void Function(jge.Entity entity, EditorScope scope) run;
}

/// Something drawn at the end of an entity's row in the scene tree: a
/// badge, a toggle.
class SceneTreeRowDecoration {
  const SceneTreeRowDecoration({
    required this.id,
    required this.build,
    this.order = 100,
  });

  /// Names the decoration, prefixed by its module.
  final String id;

  /// Lower draws first, further left, among the row's decorations.
  final int order;

  /// The widget for `entity`'s row, or null to draw nothing on it.
  final Widget? Function(BuildContext context, jge.Entity entity) build;
}

/// An icon for an entity in the scene tree and the inspector's header,
/// when a module knows better than the generic one.
///
/// The editor knows about interface and about parents and children; what
/// a *coin* or a *hazard* looks like is a game's own business, which is
/// why this is a hook and not a switch in here. The first one to answer
/// wins, lowest [order] asked first.
class EntityIcon {
  const EntityIcon({required this.id, required this.of, this.order = 100});

  /// Names the icon rule, prefixed by its module.
  final String id;

  /// Lower is asked first.
  final int order;

  /// The icon for `entity`, or null to leave it to the next one.
  final IconData? Function(jge.Entity entity) of;
}

/// A module's say on which entities must not be deleted:
/// [EditorScope.isProtected] is true for an entity any rule protects.
class EntityProtectionRule {
  const EntityProtectionRule({required this.id, required this.isProtected});

  /// Names the rule, prefixed by its module.
  final String id;

  /// Whether `entity` is protected by this rule.
  final bool Function(jge.Entity entity) isProtected;
}

/// A section a module adds to the inspector, after the component sections.
class InspectorSection {
  const InspectorSection({
    required this.id,
    required this.build,
    this.order = 100,
    this.appliesTo,
  });

  /// Names the section, prefixed by its module.
  final String id;

  /// Lower sorts first among the modules' sections.
  final int order;

  /// Null shows the section for every entity.
  final bool Function(jge.Entity entity)? appliesTo;

  /// Builds the section for the selected `entity`.
  final Widget Function(
    BuildContext context,
    jge.Entity entity,
    EditorScope scope,
  )
  build;
}

/// Something the inspector puts beside a component's fields, and tells of
/// each edit made through them — the timeline's key button, which records
/// what is changed while a timeline is open.
class FieldAccessory {
  const FieldAccessory({required this.id, this.build, this.onEdited});

  /// Names the accessory, prefixed by its module: `timeline.key`.
  final String id;

  /// The widget after the row showing [FieldAccessoryContext.fields], or
  /// null for none there.
  final Widget? Function(FieldAccessoryContext context)? build;

  /// Called after an edit through the inspector to the scene being edited,
  /// before what it changed is drawn again.
  final void Function(EditorScope scope)? onEdited;
}

/// One row of a component's fields, as a [FieldAccessory] is shown it.
class FieldAccessoryContext {
  const FieldAccessoryContext({
    required this.scope,
    required this.entity,
    required this.component,
    required this.definition,
    required this.fields,
  });

  /// The editor the inspector belongs to.
  final EditorScope scope;

  /// The entity whose component the row shows.
  final jge.Entity entity;

  /// The component the [fields] belong to.
  final jge.Component component;

  /// How [component] is saved and inspected: its schema.
  final jge.ComponentDefinition definition;

  /// The fields the row shows.
  final List<jge.SchemaField> fields;
}
