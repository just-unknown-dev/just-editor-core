import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart' show Color;
import 'package:just_storage/just_storage.dart';

import 'gizmo_settings.dart';
import 'overlay_settings_keys.dart';
import 'overlay_ui_settings.dart';

/// The editor's settings in its key-value store: [OverlayUiSettings] under
/// the [OverlaySettingsPrefKeys], each as text, beside the raw keys modules
/// keep through `EditorPrefs`. Also turns the settings into an exported
/// file and back.
class OverlaySettingsStore {
  /// Works on the store the future completes with; the scope hands it the
  /// editor's own store, opened once and shared with everything else that
  /// keeps something in it.
  OverlaySettingsStore(this._storageFuture);

  final Future<JustStandardStorage> _storageFuture;

  /// What the store holds under each key, as last read or written: a save
  /// writes only the settings that differ from it. Each write rewrites the
  /// store's whole file, so writing every setting for one change was some
  /// fifty full writes.
  Map<String, String>? _stored;

  /// The saved settings, each clamped to what the dialog allows.
  ///
  /// Keys that are not settings the editor knows are left where they are
  /// and not read.
  Future<OverlayUiSettings> loadSettings() async {
    final values = await (await _storageFuture).readAll();
    final stored = _stored = {
      for (final e in values.entries) e.key: e.value.toString(),
    };
    return decode(stored);
  }

  /// The saved settings, as [loadSettings] gives them, and every stored key
  /// with its raw value, as [readAll] does — from one read of the store,
  /// not two. A store that gives its settings some other way is read again
  /// for the raw values.
  Future<(OverlayUiSettings, Map<String, String>)> loadAll() async {
    _stored = null;
    final settings = await loadSettings();
    return (settings, Map.of(_stored ?? await readAll()));
  }

  /// Writes the settings that differ from what the store holds.
  Future<void> saveSettings(OverlayUiSettings settings) async {
    final storage = await _storageFuture;
    final stored = _stored ??= {
      for (final e in (await storage.readAll()).entries)
        e.key: e.value.toString(),
    };
    for (final MapEntry(:key, :value) in encode(settings).entries) {
      if (stored[key] == value) continue;
      stored[key] = value;
      try {
        await storage.write(key, value);
      } on Object {
        // Not written: the next save tries it again.
        stored.remove(key);
        rethrow;
      }
    }
  }

  // ── The settings as stored ───────────────────────────────────────────────

  /// Every setting under its key, as the store keeps it: what a save
  /// writes, and what an export holds.
  static Map<String, String> encode(OverlayUiSettings s) {
    String color(Color? c) => c == null ? '' : c.toARGB32().toString();
    return {
      OverlaySettingsPrefKeys.prefTextScale: '${s.textScale}',
      OverlaySettingsPrefKeys.prefCornerRadius: '${s.cornerRadius}',
      OverlaySettingsPrefKeys.prefThemeId: s.themeId,
      OverlaySettingsPrefKeys.prefAccent: color(s.accent),
      OverlaySettingsPrefKeys.prefCompactness: '${s.compactness}',
      OverlaySettingsPrefKeys.prefAnimationSpeed: '${s.animationSpeed}',
      OverlaySettingsPrefKeys.prefMetricRefreshMs: '${s.metricRefreshMs}',
      OverlaySettingsPrefKeys.prefShowGrid: '${s.showGrid}',
      OverlaySettingsPrefKeys.prefGridSnappingEnabled:
          '${s.gridSnappingEnabled}',
      OverlaySettingsPrefKeys.prefGridSize: '${s.gridSize}',
      OverlaySettingsPrefKeys.prefBoldText: '${s.boldText}',
      OverlaySettingsPrefKeys.prefHighContrast: '${s.highContrast}',
      OverlaySettingsPrefKeys.prefColorBlindSafe: '${s.colorBlindSafe}',
      OverlaySettingsPrefKeys.prefReduceMotion: '${s.reduceMotion}',
      OverlaySettingsPrefKeys.prefLongerTimings: '${s.longerTimings}',
      OverlaySettingsPrefKeys.prefAlwaysShowFocus: '${s.alwaysShowFocus}',
      OverlaySettingsPrefKeys.prefLargeTargets: '${s.largeTargets}',
      OverlaySettingsPrefKeys.prefAutosaveMinutes: '${s.autosaveMinutes}',
      OverlaySettingsPrefKeys.prefAutosaveMode: s.autosaveMode.name,
      OverlaySettingsPrefKeys.prefBackupsToKeep: '${s.backupsToKeep}',
      OverlaySettingsPrefKeys.prefReopenLastScene: '${s.reopenLastScene}',
      OverlaySettingsPrefKeys.prefReopenDesigner: '${s.reopenDesigner}',
      OverlaySettingsPrefKeys.prefShortcuts: jsonEncode(s.shortcuts),
      OverlaySettingsPrefKeys.prefTargetFps: '${s.targetFps}',
      OverlaySettingsPrefKeys.prefRotationStep: '${s.rotationStep}',
      OverlaySettingsPrefKeys.prefScaleStep: '${s.scaleStep}',
      OverlaySettingsPrefKeys.prefNudgeDistance: '${s.nudgeDistance}',
      OverlaySettingsPrefKeys.prefSmartSnap: '${s.smartSnap}',
      OverlaySettingsPrefKeys.prefMoveStep: '${s.moveStep}',
      OverlaySettingsPrefKeys.prefMoveStep3D: '${s.moveStep3D}',
      OverlaySettingsPrefKeys.prefUndoLimit: '${s.undoLimit}',
      OverlaySettingsPrefKeys.prefConfirmDelete: '${s.confirmDelete}',
      OverlaySettingsPrefKeys.prefClosePrompt: s.closePrompt.name,
      OverlaySettingsPrefKeys.prefGridColor: color(s.gridColor),
      OverlaySettingsPrefKeys.prefGridOpacity: '${s.gridOpacity}',
      OverlaySettingsPrefKeys.prefBackdrop: color(s.backdrop),
      OverlaySettingsPrefKeys.prefGizmoScale: '${s.gizmoScale}',
      OverlaySettingsPrefKeys.prefSelectionColor: color(s.selectionColor),
      OverlaySettingsPrefKeys.prefGizmosEditor: s.gizmos.editor.encode(),
      OverlaySettingsPrefKeys.prefGizmosDesigner: s.gizmos.designer.encode(),
      OverlaySettingsPrefKeys.prefGizmosPlay: s.gizmos.play.encode(),
      OverlaySettingsPrefKeys.prefPauseOnError: '${s.pauseOnError}',
      OverlaySettingsPrefKeys.prefHideChromeWhilePlaying:
          '${s.hideChromeWhilePlaying}',
      OverlaySettingsPrefKeys.prefConsoleMaxEntries: '${s.consoleMaxEntries}',
      OverlaySettingsPrefKeys.prefConsoleHiddenLevels: s.consoleHiddenLevels
          .join(','),
      OverlaySettingsPrefKeys.prefConsoleTimestamps: '${s.consoleTimestamps}',
      OverlaySettingsPrefKeys.prefMessageLevel: s.messageLevel.name,
    };
  }

  /// The settings [values] hold, each clamped to what the dialog allows;
  /// a key missing or unreadable is its default.
  static OverlayUiSettings decode(Map<String, String> values) {
    const d = OverlayUiSettings.defaults();

    double decimal(String key, double fallback, SettingRange range) =>
        range.clamp(double.tryParse(values[key] ?? '') ?? fallback);
    int whole(String key, int fallback, SettingRange range) =>
        decimal(key, fallback.toDouble(), range).round();
    bool flag(String key, bool fallback) {
      final raw = values[key];
      return raw == null ? fallback : raw == 'true';
    }

    Color? color(String key, Color? fallback) {
      final raw = values[key];
      if (raw == null) return fallback;
      final argb = int.tryParse(raw);
      return argb == null ? null : Color(argb);
    }

    T choice<T extends Enum>(String key, List<T> options, T fallback) =>
        options.asNameMap()[values[key]] ?? fallback;

    var themeId = values[OverlaySettingsPrefKeys.prefThemeId];
    var accent = int.tryParse(values[OverlaySettingsPrefKeys.prefAccent] ?? '');
    if (themeId == null) {
      // Nothing chosen yet: the default theme, the first built-in one.
      themeId = OverlayUiSettings.defaultThemeId;
      accent = OverlayUiSettings.defaultAccent.toARGB32();
    }

    return OverlayUiSettings(
      textScale: decimal(
        OverlaySettingsPrefKeys.prefTextScale,
        d.textScale,
        OverlayUiSettings.textScaleRange,
      ),
      cornerRadius: decimal(
        OverlaySettingsPrefKeys.prefCornerRadius,
        d.cornerRadius,
        OverlayUiSettings.cornerRadiusRange,
      ),
      themeId: themeId,
      accent: accent == null ? d.accent : Color(accent),
      compactness: decimal(
        OverlaySettingsPrefKeys.prefCompactness,
        d.compactness,
        OverlayUiSettings.compactnessRange,
      ),
      animationSpeed: decimal(
        OverlaySettingsPrefKeys.prefAnimationSpeed,
        d.animationSpeed,
        OverlayUiSettings.animationSpeedRange,
      ),
      metricRefreshMs: decimal(
        OverlaySettingsPrefKeys.prefMetricRefreshMs,
        d.metricRefreshMs,
        OverlayUiSettings.metricRefreshRange,
      ),
      showGrid: flag(OverlaySettingsPrefKeys.prefShowGrid, d.showGrid),
      gridSnappingEnabled: flag(
        OverlaySettingsPrefKeys.prefGridSnappingEnabled,
        d.gridSnappingEnabled,
      ),
      gridSize: decimal(
        OverlaySettingsPrefKeys.prefGridSize,
        d.gridSize,
        OverlayUiSettings.gridSizeRange,
      ),
      boldText: flag(OverlaySettingsPrefKeys.prefBoldText, d.boldText),
      highContrast: flag(
        OverlaySettingsPrefKeys.prefHighContrast,
        d.highContrast,
      ),
      colorBlindSafe: flag(
        OverlaySettingsPrefKeys.prefColorBlindSafe,
        d.colorBlindSafe,
      ),
      reduceMotion: flag(
        OverlaySettingsPrefKeys.prefReduceMotion,
        d.reduceMotion,
      ),
      longerTimings: flag(
        OverlaySettingsPrefKeys.prefLongerTimings,
        d.longerTimings,
      ),
      alwaysShowFocus: flag(
        OverlaySettingsPrefKeys.prefAlwaysShowFocus,
        d.alwaysShowFocus,
      ),
      largeTargets: flag(
        OverlaySettingsPrefKeys.prefLargeTargets,
        d.largeTargets,
      ),
      autosaveMinutes: decimal(
        OverlaySettingsPrefKeys.prefAutosaveMinutes,
        d.autosaveMinutes,
        OverlayUiSettings.autosaveRange,
      ),
      autosaveMode: choice(
        OverlaySettingsPrefKeys.prefAutosaveMode,
        AutosaveMode.values,
        d.autosaveMode,
      ),
      backupsToKeep: whole(
        OverlaySettingsPrefKeys.prefBackupsToKeep,
        d.backupsToKeep,
        OverlayUiSettings.backupsRange,
      ),
      reopenLastScene: flag(
        OverlaySettingsPrefKeys.prefReopenLastScene,
        d.reopenLastScene,
      ),
      reopenDesigner: flag(
        OverlaySettingsPrefKeys.prefReopenDesigner,
        d.reopenDesigner,
      ),
      shortcuts: decodeShortcuts(values[OverlaySettingsPrefKeys.prefShortcuts]),
      targetFps: decimal(
        OverlaySettingsPrefKeys.prefTargetFps,
        d.targetFps,
        OverlayUiSettings.targetFpsRange,
      ),
      rotationStep: decimal(
        OverlaySettingsPrefKeys.prefRotationStep,
        d.rotationStep,
        OverlayUiSettings.rotationStepRange,
      ),
      scaleStep: decimal(
        OverlaySettingsPrefKeys.prefScaleStep,
        d.scaleStep,
        OverlayUiSettings.scaleStepRange,
      ),
      nudgeDistance: decimal(
        OverlaySettingsPrefKeys.prefNudgeDistance,
        d.nudgeDistance,
        OverlayUiSettings.nudgeRange,
      ),
      smartSnap: flag(OverlaySettingsPrefKeys.prefSmartSnap, d.smartSnap),
      moveStep: decimal(
        OverlaySettingsPrefKeys.prefMoveStep,
        d.moveStep,
        OverlayUiSettings.moveStepRange,
      ),
      moveStep3D: decimal(
        OverlaySettingsPrefKeys.prefMoveStep3D,
        d.moveStep3D,
        OverlayUiSettings.moveStep3DRange,
      ),
      undoLimit: whole(
        OverlaySettingsPrefKeys.prefUndoLimit,
        d.undoLimit,
        OverlayUiSettings.undoLimitRange,
      ),
      confirmDelete: flag(
        OverlaySettingsPrefKeys.prefConfirmDelete,
        d.confirmDelete,
      ),
      closePrompt: choice(
        OverlaySettingsPrefKeys.prefClosePrompt,
        ClosePrompt.values,
        d.closePrompt,
      ),
      gridColor:
          color(OverlaySettingsPrefKeys.prefGridColor, d.gridColor) ??
          d.gridColor,
      gridOpacity: decimal(
        OverlaySettingsPrefKeys.prefGridOpacity,
        d.gridOpacity,
        OverlayUiSettings.gridOpacityRange,
      ),
      backdrop: color(OverlaySettingsPrefKeys.prefBackdrop, d.backdrop),
      gizmoScale: decimal(
        OverlaySettingsPrefKeys.prefGizmoScale,
        d.gizmoScale,
        OverlayUiSettings.gizmoScaleRange,
      ),
      selectionColor: color(
        OverlaySettingsPrefKeys.prefSelectionColor,
        d.selectionColor,
      ),
      gizmos: GizmoSettings(
        editor: GizmoModeSettings.decode(
          values[OverlaySettingsPrefKeys.prefGizmosEditor],
          d.gizmos.editor,
        ),
        designer: GizmoModeSettings.decode(
          values[OverlaySettingsPrefKeys.prefGizmosDesigner],
          d.gizmos.designer,
        ),
        play: GizmoModeSettings.decode(
          values[OverlaySettingsPrefKeys.prefGizmosPlay],
          d.gizmos.play,
        ),
      ),
      pauseOnError: flag(
        OverlaySettingsPrefKeys.prefPauseOnError,
        d.pauseOnError,
      ),
      hideChromeWhilePlaying: flag(
        OverlaySettingsPrefKeys.prefHideChromeWhilePlaying,
        d.hideChromeWhilePlaying,
      ),
      consoleMaxEntries: whole(
        OverlaySettingsPrefKeys.prefConsoleMaxEntries,
        d.consoleMaxEntries,
        OverlayUiSettings.consoleEntriesRange,
      ),
      consoleHiddenLevels: [
        for (final level
            in (values[OverlaySettingsPrefKeys.prefConsoleHiddenLevels] ?? '')
                .split(','))
          if (level.trim().isNotEmpty) level.trim(),
      ],
      consoleTimestamps: flag(
        OverlaySettingsPrefKeys.prefConsoleTimestamps,
        d.consoleTimestamps,
      ),
      messageLevel: choice(
        OverlaySettingsPrefKeys.prefMessageLevel,
        MessageLevel.values,
        d.messageLevel,
      ),
    );
  }

  /// The changed keys as stored: a JSON object of command id to the keys
  /// that run it. Anything unreadable is no change at all.
  static Map<String, List<String>> decodeShortcuts(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is List)
            e.key as String: [
              for (final chord in e.value as List)
                if (chord is String) chord,
            ],
      };
    } on FormatException {
      return const {};
    }
  }

  // ── Export and import ────────────────────────────────────────────────────

  /// What an exported settings file says it is.
  static const String exportFormat = 'just-game-editor-settings';

  /// [settings] as a file another editor can import: every setting under
  /// its key, the changed shortcuts among them.
  static String export(OverlayUiSettings settings) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': exportFormat,
        'version': 1,
        'settings': encode(settings),
      });

  /// The settings [text] holds, over [current]: a key it leaves out keeps
  /// its current value. Null when [text] is not an exported settings file.
  static OverlayUiSettings? import(String text, OverlayUiSettings current) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded['format'] != exportFormat) return null;
    final values = decoded['settings'];
    if (values is! Map) return null;
    return decode({
      ...encode(current),
      for (final e in values.entries)
        if (e.key is String && e.value != null) e.key as String: '${e.value}',
    });
  }

  // ── Raw access ───────────────────────────────────────────────────────────

  /// Every stored key and its raw value; what module preferences decode from.
  Future<Map<String, String>> readAll() async =>
      (await _storageFuture).readAll().then(
        (values) => {for (final e in values.entries) e.key: e.value.toString()},
      );

  /// Stores one raw value under [key].
  Future<void> writeRaw(String key, String value) async {
    await (await _storageFuture).write(key, value);
    _stored?[key] = value;
  }
}
