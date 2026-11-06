import 'package:meta/meta.dart';

import '../scope/editor_scope.dart';
import 'designer_contributions.dart';
import 'grid/grid_topology.dart';
import 'grid/square_grid.dart';

/// What the built-ins and the chosen designer give the Level Designer, as
/// the module wiring last read it: its grid, palette groups, status
/// controls and side-panel sections.
@internal
final class DesignerParts {
  DesignerParts._();

  /// [scope]'s, made when first asked for.
  static DesignerParts of(EditorScope scope) =>
      scope.service<DesignerParts>(DesignerParts._);

  /// See `ScopeDesigner.grid`.
  GridTopology grid = const SquareGrid();

  /// See `ScopeDesigner.prefabCategories`.
  final List<PrefabCategory> categories = [];

  /// See `ScopeDesigner.statusControls`.
  final List<StatusBarControl> controls = [];

  /// See `ScopeDesigner.designerPanels`.
  final List<SidePanelSection> panels = [];
}
