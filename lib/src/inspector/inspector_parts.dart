import 'package:meta/meta.dart';

import '../scope/editor_scope.dart';
import 'inspector_contributions.dart';

/// What the modules give the inspector, as the module wiring last read it:
/// its sections and field accessories.
@internal
final class InspectorParts {
  InspectorParts._();

  /// [scope]'s, made when first asked for.
  static InspectorParts of(EditorScope scope) =>
      scope.service<InspectorParts>(InspectorParts._);

  /// See `ScopeInspector.inspectorSections`.
  final List<InspectorSection> sections = [];

  /// See `ScopeInspector.fieldAccessories`.
  final List<FieldAccessory> accessories = [];
}
