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

  /// Colour-blind safe colours: `OverlayUiSettings.colorBlindSafe`.
  static const String prefColorBlindSafe = 'editor.a11y.colourBlindSafe';

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

  /// Grid colour, as an ARGB integer: `OverlayUiSettings.gridColor`.
  static const String prefGridColor = 'editor.viewport.gridColour';

  /// Grid strength: `OverlayUiSettings.gridOpacity`.
  static const String prefGridOpacity = 'editor.viewport.gridOpacity';

  /// Backdrop, as an ARGB integer or empty for the game's own:
  /// `OverlayUiSettings.backdrop`.
  static const String prefBackdrop = 'editor.viewport.backdrop';

  /// Handle size: `OverlayUiSettings.gizmoScale`.
  static const String prefGizmoScale = 'editor.viewport.gizmoScale';

  /// Selection colour, as an ARGB integer or empty for each view's own:
  /// `OverlayUiSettings.selectionColor`.
  static const String prefSelectionColor = 'editor.viewport.selectionColour';

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
