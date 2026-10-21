import 'package:just_debugger/just_debugger.dart';
import 'package:just_signals/just_signals.dart';
import '../look/editor_constants.dart';
import 'editor_prefs.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

/// What the editor's chrome remembers while it is open, per editor: the
/// dragged width of the right panel and its tab, whether the settings
/// dialog is open, which inspector cards and groups are folded, and the
/// performance history the docks chart.
///
/// A scope service: the compact dock, the chrome and the right panel are
/// parallel widgets, not parent and child, so a State field on any one of
/// them could not reach the others. Each editor in a process has its own.
class EditorChromeState {
  /// True while the Keyboard settings wait for a chord to bind: every key
  /// is theirs, Esc and the settings' own chord among them.
  bool capturingKeys = false;

  /// Keys the editor keeps for itself, outside its commands — F1 shows and
  /// hides it — which no command can be bound to.
  Set<LogicalKeyboardKey> reservedKeys = const {};

  EditorChromeState();

  /// Where the right panel's width is kept between launches.
  static final SettingPref<double> rightPanelWidthPref = SettingPref.decimal(
    'editor.panel.width',
    OverlayLayout.rightPanelDefaultWidth,
  );

  /// Where the scene tree's height in the right panel is kept.
  static final SettingPref<double> sceneTreeHeightPref = SettingPref.decimal(
    'editor.panel.treeHeight',
    220,
  );

  /// Live width of the right inspector panel, dragged via the handle on its
  /// left edge; kept as [rightPanelWidthPref] when a drag ends.
  final Signal<double> rightPanelWidth = Signal<double>(
    OverlayLayout.rightPanelDefaultWidth,
  );

  /// Whether the settings dialog is open. The gear at the viewport's foot,
  /// the `editor.settings` command and Esc all go through this.
  final Signal<bool> settingsOpen = Signal<bool>(
    false,
    debugLabel: 'settingsOpen',
  );

  /// Opens the settings dialog if it is shut, or shuts it.
  void toggleSettings() => settingsOpen.value = !settingsOpen.value;

  /// The right panel's tab while the Level Designer is open: the scene
  /// tree and inspector, or the designer's [levelTab].
  final Signal<String> rightPanelTab = Signal<String>(
    inspectorTab,
    debugLabel: 'rightPanelTab',
  );

  /// [rightPanelTab]'s value for the scene tree and inspector.
  static const String inspectorTab = 'inspector';

  /// [rightPanelTab]'s value for the Level Designer's own tab.
  static const String levelTab = 'level';

  /// The component types whose inspector cards are folded to their header —
  /// on every entity, until the editor closes.
  final Signal<Set<String>> collapsedComponents = Signal<Set<String>>(
    const {},
    debugLabel: 'collapsedComponents',
  );

  /// Folds the inspector cards of [componentType] to their header, or opens
  /// them if they are folded.
  void toggleCollapsed(String componentType) {
    final now = collapsedComponents.value;
    collapsedComponents.value = Set.unmodifiable(
      now.contains(componentType)
          ? ({...now}..remove(componentType))
          : {...now, componentType},
    );
  }

  /// Field groups opened or folded by hand, against how their component
  /// starts them (`ComponentHints.foldedGroups`), as `type/group` — on
  /// every entity, until the editor closes.
  final Signal<Set<String>> flippedGroups = Signal<Set<String>>(
    const {},
    debugLabel: 'flippedGroups',
  );

  /// Whether [group] of [componentType] is folded, given whether it
  /// [startsFolded].
  bool isGroupFolded(
    String componentType,
    String group, {
    required bool startsFolded,
  }) => startsFolded != flippedGroups.value.contains('$componentType/$group');

  /// Folds [group] of [componentType] if it is open, or opens it if it is
  /// folded.
  void toggleGroup(String componentType, String group) {
    final key = '$componentType/$group';
    final now = flippedGroups.value;
    flippedGroups.value = Set.unmodifiable(
      now.contains(key) ? ({...now}..remove(key)) : {...now, key},
    );
  }

  /// Performance samples, oldest first and at most
  /// [OverlayLayout.perfHistoryCapacity], kept across dock open/close.
  final List<PerfHistorySample> perfHistory = <PerfHistorySample>[];

  /// Appends a sample, skipping duplicates when the frame has not advanced
  /// (the game is paused, say).
  void recordPerfSample(
    PerformanceDebuggerSnapshot performance,
    MemoryDebuggerSnapshot memory,
  ) {
    if (perfHistory.isNotEmpty &&
        perfHistory.last.frameNumber == performance.frameNumber) {
      return;
    }
    perfHistory.add(
      PerfHistorySample(
        frameNumber: performance.frameNumber,
        fps: performance.currentFps,
        frameMs: performance.lastUpdateMs,
        budgetRemainingMs: performance.budgetRemainingMs,
        rssBytes: memory.rssBytes,
      ),
    );
    if (perfHistory.length > OverlayLayout.perfHistoryCapacity) {
      perfHistory.removeAt(0);
    }
  }

  /// Disposes the signals; the scope calls it when it is disposed.
  void dispose() {
    rightPanelWidth.dispose();
    settingsOpen.dispose();
    collapsedComponents.dispose();
    flippedGroups.dispose();
    rightPanelTab.dispose();
  }
}

/// One frame's performance, as [EditorChromeState.recordPerfSample] took it
/// from the debugger, for the docks' charts.
class PerfHistorySample {
  const PerfHistorySample({
    required this.frameNumber,
    required this.fps,
    required this.frameMs,
    required this.budgetRemainingMs,
    required this.rssBytes,
  });

  /// The engine's frame count when the sample was taken.
  final int frameNumber;

  /// Frames per second at the time.
  final int fps;

  /// How long the frame's update took, in milliseconds.
  final double frameMs;

  /// What was left of the frame's budget after it, in milliseconds.
  final double budgetRemainingMs;

  /// The process's resident memory, in bytes; 0 when it is not reported.
  final int rssBytes;

  /// Frame time as a percentage of the engine's fixed frame budget — used as
  /// a CPU-load proxy since no real OS-level CPU% is tracked anywhere in the
  /// engine/debugger. Can exceed 100 when the frame is over budget.
  double get cpuUsagePercent {
    final totalBudgetMs = frameMs + budgetRemainingMs;
    if (totalBudgetMs <= 0) return 0;
    return (frameMs / totalBudgetMs) * 100;
  }
}
