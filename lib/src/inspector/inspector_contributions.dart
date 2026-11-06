import 'package:flutter/widgets.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../scope/editor_scope.dart';

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

  /// How [component] is saved and inspected: its definition.
  final jge.ComponentDefinition definition;

  /// The fields the row shows.
  final List<jge.FieldDefinition> fields;
}
