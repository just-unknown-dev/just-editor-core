import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;

import '../scope/editor_scope.dart';
import 'designer_3d_state.dart';
import 'designer_command.dart';
import 'designer_config.dart';
import 'designer_contributions.dart';
import 'designer_parts.dart';
import 'grid/grid_topology.dart';
import 'layer_preset.dart';
import 'prefab_registry.dart';
import 'selection_handle_layout.dart';

/// The Level Designer on an [EditorScope]: its commands and keys, what it
/// places and on which layers, its grid, and what the chosen designer adds
/// to its palette, status bar and side panel.
extension ScopeDesigner on EditorScope {
  /// Fixed designer choices: grid sizes, brush sizes, bookmark slots. The
  /// defaults, unless a host registered its own in
  /// [EditorScope.container] before the first ask.
  DesignerConfig get config =>
      service<DesignerConfig>(() => const DesignerConfig());

  /// Where the selection handles sit; what a replacement select tool must
  /// also describe. As [config], the defaults unless a host registered its
  /// own.
  SelectionHandleLayout get handleLayout =>
      service<SelectionHandleLayout>(() => const SelectionHandleLayout());

  /// Designer commands and the keys bound to them. The keys changed in the
  /// settings go over the ones they were built with.
  CommandRegistry get commands => service<CommandRegistry>(() {
    // Built with nothing: what the modules bind is laid over this.
    final commands = CommandRegistry()..markBuilt();
    Map<String, List<String>>? applied;
    followSettings((s) {
      if (identical(s.shortcuts, applied)) return;
      applied = s.shortcuts;
      final unread = commands.applyShortcuts(s.shortcuts);
      for (final MapEntry(key: id, value: chords) in unread.entries) {
        final none = chords.length == s.shortcuts[id]?.length;
        log.log(
          'The settings bind "$id" to '
          '${chords.map((c) => '"$c"').join(', ')}, which names no key: '
          '${none ? 'the command keeps the keys it was built with' : 'left out'}.',
          source: 'editor',
          category: 'shortcuts',
          level: DebuggerLogLevel.warning,
        );
      }
    });
    return commands;
  });

  /// Prefabs the draw and paint tools can place.
  PrefabRegistry get prefabs => service<PrefabRegistry>(PrefabRegistry.new);

  /// Named draw-order layers: the built-in ones, then the designers'.
  LayerPresetRegistry get layers => service<LayerPresetRegistry>(
    () => LayerPresetRegistry()..registerAll(LayerPresetRegistry.builtIn),
  );

  /// How the 3-D Level Designer is set up to build: its working plane.
  /// Editor-only, like `ScopeScene.view`.
  Designer3DState get designer3D => service<Designer3DState>(
    Designer3DState.new,
    dispose: (d) => d.dispose(),
  );

  /// The shape of the designer's cells. Square unless a module says otherwise;
  /// the last module to contribute one wins.
  GridTopology get grid => DesignerParts.of(this).grid;

  /// Palette groups, built-in first, then each module's in order.
  List<PrefabCategory> get prefabCategories =>
      List.unmodifiable(DesignerParts.of(this).categories);

  /// Module controls appended to the designer status bar, by order.
  List<StatusBarControl> get statusControls =>
      List.unmodifiable(DesignerParts.of(this).controls);

  /// Module sections appended to the designer side panel, by order.
  List<SidePanelSection> get designerPanels =>
      List.unmodifiable(DesignerParts.of(this).panels);

  /// Where the palette group called [label] sorts; one nobody declared
  /// sorts after every declared one.
  int prefabCategoryOrder(String label) {
    for (final c in DesignerParts.of(this).categories) {
      if (c.label == label) return c.order;
    }
    return 1 << 20;
  }
}
