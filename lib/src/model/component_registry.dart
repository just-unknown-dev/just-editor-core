import 'package:just_game_engine/just_game_engine.dart';

import '../scope/editor_scope.dart';

/// A single entry in the component picker catalogue.
class ComponentEntry {
  const ComponentEntry({
    required this.name,
    required this.group,
    required this.description,
    required this.factory,
    this.componentTypeName,
    this.allowMultiple = false,
  });

  /// The name the picker lists it by: the definition's display name, or
  /// its type.
  final String name;

  /// The heading it is listed under in the picker (`Core` when the
  /// definition names none).
  final String group;

  /// One line on what it does, for the picker; empty for none.
  final String description;

  /// The definition's type: what a scene file saves the component as.
  final String? componentTypeName;

  /// The definition's `allowMultiple` hint. An entity holds one component
  /// per type (`Component.componentType`) whatever this says, so the picker
  /// never offers an entry whose type the entity already has.
  final bool allowMultiple;

  /// Produces a new component instance with sensible editor defaults.
  final Component Function() factory;
}

/// Every component the picker can add: each runtime definition the scope
/// knows.
List<ComponentEntry> getComponentRegistryEntries(EditorScope scope) => [
  for (final d in scope.definitions.definitions)
    // Only what belongs in the scene's mode: no tile map in a 3-D scene.
    if (d.hints.dimensions.allows(scope.sceneState.editingMode))
      ComponentEntry(
        name: d.hints.name ?? d.type,
        group: d.hints.group ?? 'Core',
        description: d.hints.description ?? '',
        factory: d.create,
        componentTypeName: d.type,
        allowMultiple: d.hints.allowMultiple,
      ),
];
