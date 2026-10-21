import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'editor_metrics.dart';
import 'editor_theme_data.dart';
import 'theme_controller.dart';

// Editor-wide names for shared values: the colours of the palette in force
// (read from [EditorThemeData], which holds them), the keys settings are
// stored under, and the sizes a few painters share. The palettes themselves
// are in editor_theme_data.dart and the sizes in editor_metrics.dart; to
// retheme or resize the editor, change those.

// ── Theme ────────────────────────────────────────────────────────────────────

/// The editor's colours by name, each read from the palette the overlay
/// last applied ([current]).
///
/// The overlay rebuilds what it draws when the palette changes, so a widget
/// can read `EditorTheme.panelBg` in its build. [of] reads the palette
/// through an [EditorThemeScope] instead, for a widget that has to rebuild
/// by itself when the theme changes.
abstract final class EditorTheme {
  /// The palette in force at [context], read through it so a widget under
  /// an [EditorThemeScope] is built again when the theme changes: the
  /// scope's theme as the editor shows it — [current], high-contrast or
  /// colour-blind-safe colours included, once [apply] was given it — or,
  /// outside any scope (a dialog on the app's own navigator), [current].
  static EditorThemeData of(BuildContext context) {
    final theme = context
        .dependOnInheritedWidgetOfExactType<EditorThemeScope>()
        ?.notifier
        ?.value;
    if (theme == null || identical(theme, _appliedFrom)) return _current;
    return theme;
  }

  /// The palette every colour below reads: [EditorThemeData.classic] until
  /// the overlay applies the accent the user picked, or a module's preset.
  static EditorThemeData get current => _current;
  static EditorThemeData _current = EditorThemeData.classic;

  /// Makes [data] the palette. The overlay does this when the theme changes,
  /// and rebuilds everything it draws so what reads a colour here sees the
  /// new one; anything else built after this reads it too.
  ///
  /// [from] is the theme [data] was made from — the preset picked, before
  /// the accessibility settings adjusted it — so that [of] hands out [data]
  /// wherever a scope holds that theme.
  static void apply(EditorThemeData data, {EditorThemeData? from}) {
    _current = data;
    _appliedFrom = from ?? data;
  }

  static EditorThemeData? _appliedFrom;

  /// The accent: what is picked, switched on, or wants to be seen.
  static Color get accent => _current.primary;

  // ── Accent ─────────────────────────────────────────────────────────────────

  /// The accent: [EditorThemeData.primary].
  static Color get primary => _current.primary;

  /// The accent brighter: a secondary button's label, a highlight.
  static Color get primaryBright => _current.primaryBright;

  /// The accent darker: a primary button's fill, a focused field's outline.
  static Color get primaryActive => _current.primaryActive;

  /// A quiet shade of the accent, for marks that should not stand out.
  static Color get primaryMuted => _current.primaryMuted;

  /// A quiet shade of the accent, lighter than [primaryMuted].
  static Color get primaryMutedLight => _current.primaryMutedLight;

  // ── Selection / hover backgrounds ──────────────────────────────────────────

  /// Behind the row or item that is selected.
  static Color get selectionBg => _current.selectionBg;

  /// Behind the row something dragged would drop onto.
  static Color get dragOverBg => _current.dragOverBg;

  /// Behind the rows of a selection of more than one, beside the main one.
  static Color get multiSelectBg => _current.multiSelectBg;

  /// Behind what is under the pointer.
  static Color get hoverBg => _current.hoverBg;

  // ── Surfaces ───────────────────────────────────────────────────────────────

  /// Behind the panels and workspaces: the darkest of the main surfaces.
  static Color get panelBg => _current.panelBg;

  /// Cards and bars that sit on a panel, a message's card.
  static Color get surfaceBg => _current.surfaceBg;

  /// Dialogs and the inspector's cards.
  static Color get dialogBg => _current.dialogBg;

  /// Inside a text or number field.
  static Color get inputBg => _current.inputBg;

  /// Menus and drop-down lists.
  static Color get menuBg => _current.menuBg;

  /// Something raised over a panel: a tooltip, a row being dragged.
  static Color get panelRaised => _current.panelRaised;

  /// Darker than [panelBg]: what sits sunk into a panel, a minimap's
  /// backing.
  static Color get surfaceDark => _current.surfaceDark;

  /// Darker than [surfaceDark]: the kit's field fill, a dock's strip.
  static Color get surfaceDarker => _current.surfaceDarker;

  /// The darkest surface: behind the start card and the scene loader.
  static Color get surfaceDarkest => _current.surfaceDarkest;

  // ── Borders / dividers ─────────────────────────────────────────────────────

  /// The faint line between regions.
  static Color get border => _current.border;

  /// A line that has to be seen: round a field, a dialog's panels.
  static Color get borderStrong => _current.borderStrong;

  // ── Button / badge backgrounds ─────────────────────────────────────────────

  /// A secondary button's fill.
  static Color get buttonBg => _current.buttonBg;

  /// A floating bar's or badge's fill over the level: the toolbars.
  static Color get statusBadgeBg => _current.statusBadgeBg;

  // ── Text ───────────────────────────────────────────────────────────────────

  /// Main text: names, values, titles.
  static Color get textPrimary => _current.textPrimary;

  /// Text that is read second: a message, a label beside a value.
  static Color get textSecondary => _current.textSecondary;

  /// Hints, placeholders, captions: text that stays in the background.
  static Color get textMuted => _current.textMuted;

  /// Text on the accent: a primary button's label, a selected row's name.
  static Color get textBright => _current.textBright;

  // ── Semantic ───────────────────────────────────────────────────────────────

  /// What went wrong: errors, a danger button.
  static Color get error => _current.error;

  /// A lighter [error], for error text on a dark surface.
  static Color get errorLight => _current.errorLight;

  /// What may go wrong: warnings.
  static Color get warning => _current.warning;

  /// What went right: a task done, a check passed.
  static Color get success => _current.success;

  /// What is merely said: information messages.
  static Color get info => _current.info;
}

// ── Overlay layout ───────────────────────────────────────────────────────────

/// Sizes of the overlay's frame, in logical pixels.
abstract final class OverlayLayout {
  /// The status bar: one line of text.
  static double get compactDockPanelHeight =>
      EditorMetrics.settings.largeTargets ? 34 : 26;

  /// The right panel's width before it is dragged, and its saved default.
  static const double rightPanelDefaultWidth = 360;

  /// The narrowest the right panel can be dragged.
  static const double rightPanelMinWidth = 280;

  /// The widest the right panel can be dragged.
  static const double rightPanelMaxWidth = 640;

  /// Performance samples the editor keeps for the docks' charts; the oldest
  /// go first.
  static const int perfHistoryCapacity = 180;
}

// ── Gizmo painting / hit-testing ──────────────────────────────────────────────

/// The sizes and colours of the move, scale and rotate gizmos, shared by
/// the editor's drawing (`GizmoPainter`, `TransformGizmo`) and hit-testing
/// (`GizmoHitTester`) so what takes a press lines up with what is drawn.
///
/// Sizes are in screen pixels, before the Handle size setting scales them.
abstract final class GizmoConstants {
  // Shared with hit-testing — keep in sync with what's drawn.

  /// From the centre to the tip of the X and Y arrows, and to the scale
  /// gizmo's axis handles.
  static const double arrowLength = 52.0;

  /// The rotate ring's radius, and the all-in-one gizmo's rotate arc's.
  static const double rotRadius = 60.0;

  /// Half the side of a corner scale handle.
  static const double scaleHandle = 7.0;

  /// How far round the all-in-one gizmo's rotate arc runs, in radians: its
  /// dot sits at the arc's end.
  static const double rotSweep = math.pi * 0.75;

  /// From the centre to the all-in-one gizmo's per-axis scale squares, along
  /// each arrow's shaft.
  static const double axisSquareOffset = 30.0;

  // Painter-only.

  /// An arrowhead's length, along the shaft.
  static const double arrowHeadLength = 12.0;

  /// An arrowhead's width at its base.
  static const double arrowHeadWidth = 7.0;

  /// The radius of the rotate knob and the rotate arc's dot.
  static const double dotRadius = 5.0;

  /// Half the side of the move gizmo's centre square, and the radius of the
  /// all-in-one gizmo's centre handle.
  static const double moveHandleRadius = 8.0;

  /// Half the side of an axis scale square.
  static const double axisSquareHalf = 5.0;

  /// The closest grid lines should be drawn on the screen, for a painter of
  /// a module's own. The built-in grids keep their own minimum and do not
  /// read it.
  static const double minGridScreenSpacing = 14.0;

  // Hit-tester-only.

  /// How near an arrow's tip a press has to be to take it.
  static const double arrowTipRadius = 14.0;

  /// How near the rotate arc's dot a press has to be to take it.
  static const double rotDotRadius = 10.0;

  /// How near an axis scale square a press has to be to take it.
  static const double axisSquareHitRadius = 9.0;

  /// How near the centre a press has to be to take the handle that moves on
  /// both axes.
  static const double moveHandleHitRadius = 11.0;

  /// How near an arrow's shaft a press has to be to take it.
  static const double axisHitWidth = 6.0;

  /// How near the rotate ring a press has to be to take it.
  static const double ringHitWidth = 8.0;

  // Colours.

  /// The X axis: its arrow and its scale handles.
  static const Color colX = Color(0xFFE54B4B);

  /// The Y axis: its arrow and its scale handles.
  static const Color colY = Color(0xFF4BCC73);

  /// The rotate ring, arc and knob.
  static const Color colRot = Color(0xFFFFD660);

  /// The corner scale handles.
  static const Color colScale = Color(0xFFCCCCCC);

  /// Selected keys and ranges in the Timeline. The viewport's selection
  /// outline takes the Selection colour setting, this colour until it is
  /// set.
  static const Color colSel = Color(0xFF40E0D0);

  /// The dot on the selected entity's origin.
  static const Color colOrigin = Color(0xFFFFFFFF);

  /// The centre handle that moves on both axes.
  static const Color colMove = Color(0xFF40E0D0);

  /// The selection frame's size, in world units, for an entity none of
  /// whose components says how big it is.
  static const Size defaultSelectionSize = Size(32, 32);
}

// ── Persisted overlay settings keys ───────────────────────────────────────────

/// The keys the editor's own settings are kept under in its key-value
/// store, one for each field of `OverlayUiSettings`, and the keys of what
/// it keeps of the last session.
///
/// `OverlaySettingsStore` reads and writes the settings ones, and they are
/// what a settings export holds; the session keys are never exported.
abstract final class OverlaySettingsPrefKeys {
  /// Text size: `OverlayUiSettings.textScale`.
  static const String prefTextScale = 'editor.overlay.textScale';

  /// Corner radius: `OverlayUiSettings.cornerRadius`.
  static const String prefCornerRadius = 'editor.overlay.cornerRadius';

  /// The theme preset picked: `OverlayUiSettings.themeId`.
  static const String prefThemeId = 'editor.overlay.themeId';

  /// That theme's accent, as an ARGB integer: `OverlayUiSettings.accent`.
  static const String prefAccent = 'editor.overlay.accent';

  /// Density: `OverlayUiSettings.compactness`.
  static const String prefCompactness = 'editor.overlay.compactness';

  /// Animation speed: `OverlayUiSettings.animationSpeed`.
  static const String prefAnimationSpeed = 'editor.overlay.animationSpeed';

  /// Status bar refresh: `OverlayUiSettings.metricRefreshMs`.
  static const String prefMetricRefreshMs = 'editor.overlay.metricRefreshMs';

  /// Show grid: `OverlayUiSettings.showGrid`.
  static const String prefShowGrid = 'editor.overlay.showGrid';

  /// Snapping: `OverlayUiSettings.gridSnappingEnabled`.
  static const String prefGridSnappingEnabled =
      'editor.overlay.gridSnappingEnabled';

  /// Grid size: `OverlayUiSettings.gridSize`.
  static const String prefGridSize = 'editor.overlay.gridSize';

  // Accessibility.

  /// Bolder text: `OverlayUiSettings.boldText`.
  static const String prefBoldText = 'editor.a11y.boldText';

  /// High contrast: `OverlayUiSettings.highContrast`.
  static const String prefHighContrast = 'editor.a11y.highContrast';

  /// Colour-blind safe colours: `OverlayUiSettings.colourBlindSafe`.
  static const String prefColourBlindSafe = 'editor.a11y.colourBlindSafe';

  /// Reduce motion: `OverlayUiSettings.reduceMotion`.
  static const String prefReduceMotion = 'editor.a11y.reduceMotion';

  /// Longer timings: `OverlayUiSettings.longerTimings`.
  static const String prefLongerTimings = 'editor.a11y.longerTimings';

  /// Always-visible focus: `OverlayUiSettings.alwaysShowFocus`.
  static const String prefAlwaysShowFocus = 'editor.a11y.alwaysShowFocus';

  /// Bigger targets: `OverlayUiSettings.largeTargets`.
  static const String prefLargeTargets = 'editor.a11y.largeTargets';

  // Saving and starting.

  /// Minutes between autosaves: `OverlayUiSettings.autosaveMinutes`.
  static const String prefAutosaveMinutes = 'editor.save.autosaveMinutes';

  /// What an autosave does, by name: `OverlayUiSettings.autosaveMode`.
  static const String prefAutosaveMode = 'editor.save.autosaveMode';

  /// Backups kept: `OverlayUiSettings.backupsToKeep`.
  static const String prefBackupsToKeep = 'editor.save.backupsToKeep';

  /// Reopen the last scene: `OverlayUiSettings.reopenLastScene`.
  static const String prefReopenLastScene = 'editor.startup.reopenLastScene';

  /// Reopen the Level Designer: `OverlayUiSettings.reopenDesigner`.
  static const String prefReopenDesigner = 'editor.startup.reopenDesigner';

  // Keyboard.

  /// The commands whose keys were changed, as a JSON object:
  /// `OverlayUiSettings.shortcuts`.
  static const String prefShortcuts = 'editor.keys.shortcuts';

  // Performance.

  /// Target frame rate: `OverlayUiSettings.targetFps`.
  static const String prefTargetFps = 'editor.performance.targetFps';

  // Editing.

  /// Rotation step, in degrees: `OverlayUiSettings.rotationStep`.
  static const String prefRotationStep = 'editor.edit.rotationStep';

  /// Scale step: `OverlayUiSettings.scaleStep`.
  static const String prefScaleStep = 'editor.edit.scaleStep';

  /// Nudge distance: `OverlayUiSettings.nudgeDistance`.
  static const String prefNudgeDistance = 'editor.edit.nudgeDistance';

  /// Smart snap: `OverlayUiSettings.smartSnap`.
  static const String prefSmartSnap = 'editor.edit.smartSnap';

  /// Move step: `OverlayUiSettings.moveStep`.
  static const String prefMoveStep = 'editor.edit.moveStep';

  /// Move step in 3-D, in metres: `OverlayUiSettings.moveStep3D`.
  static const String prefMoveStep3D = 'editor.edit.moveStep3D';

  /// Undo steps: `OverlayUiSettings.undoLimit`.
  static const String prefUndoLimit = 'editor.edit.undoLimit';

  /// Confirm deletes: `OverlayUiSettings.confirmDelete`.
  static const String prefConfirmDelete = 'editor.edit.confirmDelete';

  /// Closing a scene, by name: `OverlayUiSettings.closePrompt`.
  static const String prefClosePrompt = 'editor.edit.closePrompt';

  // The viewport's look.

  /// Grid colour, as an ARGB integer: `OverlayUiSettings.gridColour`.
  static const String prefGridColour = 'editor.viewport.gridColour';

  /// Grid strength: `OverlayUiSettings.gridOpacity`.
  static const String prefGridOpacity = 'editor.viewport.gridOpacity';

  /// Backdrop, as an ARGB integer or empty for the game's own:
  /// `OverlayUiSettings.backdrop`.
  static const String prefBackdrop = 'editor.viewport.backdrop';

  /// Handle size: `OverlayUiSettings.gizmoScale`.
  static const String prefGizmoScale = 'editor.viewport.gizmoScale';

  /// Selection colour, as an ARGB integer or empty for each view's own:
  /// `OverlayUiSettings.selectionColour`.
  static const String prefSelectionColour = 'editor.viewport.selectionColour';

  /// The gizmos while editing, as `GizmoModeSettings.encode` writes them.
  static const String prefGizmosEditor = 'editor.viewport.gizmos.editor';

  /// The gizmos in the Level Designer, as `GizmoModeSettings.encode`
  /// writes them.
  static const String prefGizmosDesigner = 'editor.viewport.gizmos.designer';

  /// The gizmos in a play-test, as `GizmoModeSettings.encode` writes them.
  static const String prefGizmosPlay = 'editor.viewport.gizmos.play';

  // Play-testing.

  /// Pause on error: `OverlayUiSettings.pauseOnError`.
  static const String prefPauseOnError = 'editor.play.pauseOnError';

  /// Step aside while playing: `OverlayUiSettings.hideChromeWhilePlaying`.
  static const String prefHideChromeWhilePlaying = 'editor.play.hideChrome';

  // The Console and messages.

  /// Lines the Console keeps: `OverlayUiSettings.consoleMaxEntries`.
  static const String prefConsoleMaxEntries = 'editor.console.maxEntries';

  /// Levels a new Console hides, comma-separated:
  /// `OverlayUiSettings.consoleHiddenLevels`.
  static const String prefConsoleHiddenLevels = 'editor.console.hiddenLevels';

  /// Show times: `OverlayUiSettings.consoleTimestamps`.
  static const String prefConsoleTimestamps = 'editor.console.timestamps';

  /// Which messages show, by name: `OverlayUiSettings.messageLevel`.
  static const String prefMessageLevel = 'editor.messages.level';

  // Where the last session left off — kept, not settings: never exported.

  /// The scene open when the editor was last closed, by name.
  static const String sessionLastScene = 'editor.session.lastScene';

  /// Whether the Level Designer was open on that scene.
  static const String sessionDesignerOpen = 'editor.session.designerOpen';

  /// The scenes opened lately, newest first, one name per line.
  static const String sessionRecentScenes = 'editor.session.recentScenes';

  // How the Scenes list is sorted — kept with the session, not a setting.

  /// How the Scenes list was last sorted, by the sort's name.
  static const String scenesSort = 'editor.scenes.sort';
}

// ── Editor log service ────────────────────────────────────────────────────────

/// Limits of the editor's log: the lines it keeps and the file it writes.
abstract final class EditorLogConstants {
  /// Lines the log keeps until the Console's Lines kept setting is applied;
  /// the oldest go first.
  static const int maxEntries = 1000;

  /// Maximum file size in bytes before the log is rotated (~5 MB).
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Number of backup files to keep alongside the primary log.
  static const int maxBackupFiles = 2;
}

// ── Component picker ──────────────────────────────────────────────────────────

/// The order of the Add Component picker's sections, by group name.
///
/// This is an *ordering hint*, not a whitelist. A group a component
/// declares that is not listed here still appears, after these in
/// alphabetical order, and its components are found by search like any
/// other.
const List<String> kComponentGroups = [
  'Core',
  'Rendering',
  'Physics',
  'Gameplay',
  'Input',
  'Camera',
  'Audio',
  'Animation',
  'Hierarchy',
  'Effects',
  'UI',
];
