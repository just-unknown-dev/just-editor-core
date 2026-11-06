import '../designer/grid/hex_grid.dart';
import '../designer/grid/grid_topology.dart';
import 'editor_module.dart';

/// Opt in to hex cells: `modules: [HexGridModule()]`.
class HexGridModule extends EditorModule {
  @override
  String get id => 'hexGrid';

  @override
  String get name => 'Hex grid';

  @override
  GridTopology? get gridTopology => const HexGrid();
}
