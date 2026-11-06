import '../scope/editor_scope.dart';
import 'component_extras.dart';
import 'field_editor.dart';
import 'inspector_contributions.dart';
import 'inspector_parts.dart';

/// The inspector on an [EditorScope]: which control edits which field,
/// what the modules add to how components are inspected, and the sections
/// and accessories they put beside them.
extension ScopeInspector on EditorScope {
  /// Which control edits which field type.
  FieldEditorRegistry get fieldEditors =>
      service<FieldEditorRegistry>(FieldEditorRegistry.new);

  /// Editor-only additions to how components are inspected.
  ComponentExtrasRegistry get extras =>
      service<ComponentExtrasRegistry>(ComponentExtrasRegistry.new);

  /// Module sections appended after the inspector's component sections.
  List<InspectorSection> get inspectorSections =>
      List.unmodifiable(InspectorParts.of(this).sections);

  /// What the modules put beside component fields, in order.
  List<FieldAccessory> get fieldAccessories =>
      List.unmodifiable(InspectorParts.of(this).accessories);
}
