import 'dart:convert';

import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'editor_commands.dart';
import 'editor_history.dart';
import '../scope/editor_scope.dart';

/// An edit of components made by code — a handle dragged, a collider
/// fitted, a preset applied — recorded as one undo step of every saved
/// field it changed, whatever those were. Several components edited
/// together — a shape's size and where its entity stands, so one face
/// stays put — are still one step.
///
/// ```dart
/// final edit = ComponentEdit.begin(scope, collider);
/// collider.size = Vector2(64, 20);
/// edit.commit('Fit collider');
/// ```
final class ComponentEdit {
  ComponentEdit._(this.scope, this._components, this._before);

  /// Remembers [component]'s saved fields, before changing it.
  factory ComponentEdit.begin(EditorScope scope, jge.Component component) =>
      ComponentEdit.beginAll(scope, [component]);

  /// Remembers the saved fields of each of [components], before changing
  /// them.
  factory ComponentEdit.beginAll(
    EditorScope scope,
    List<jge.Component> components,
  ) => ComponentEdit._(
    scope,
    [...components],
    [for (final c in components) snapshot(scope, c)],
  );

  /// The editor.
  final EditorScope scope;

  final List<jge.Component> _components;

  /// What is edited.
  List<jge.Component> get components => List.unmodifiable(_components);

  /// Adds [component] to what is edited, remembering its saved fields —
  /// before it is changed: a stroke painting one thing after another, all
  /// one undo step. Nothing when it is in already.
  void include(jge.Component component) {
    if (_components.any((c) => identical(c, component))) return;
    _components.add(component);
    _before.add(snapshot(scope, component));
  }

  /// The first of [components].
  jge.Component get component => _components.first;

  final List<Map<String, Object?>?> _before;

  /// Records what changed since [ComponentEdit.begin] as one undo step
  /// called [label] — nothing when nothing did. Whether anything did.
  bool commit(String label) {
    final commands = <EditorCommand>[];
    final owners = _ownersOf(_components);
    for (final (i, component) in _components.indexed) {
      final before = _before[i];
      final definition = scope.definitions.definitionFor(component);
      if (before == null || definition == null) continue;
      for (final field in definition.fields) {
        if (field.write == null || !before.containsKey(field.name)) continue;
        final after = _copy(field.encodeFrom(component));
        if (jsonEncode(after) == jsonEncode(before[field.name])) continue;
        commands.add(
          ComponentFieldCommand(
            label: '$label: ${field.name}',
            component: component,
            // Found again by its entity when undone: a Stop, or a delete
            // undone, puts a fresh instance in its place.
            entity: owners[component],
            write: (c, v) => field.decodeInto(c, v),
            before: before[field.name],
            after: after,
            sceneState: scope.sceneState,
          ),
        );
      }
    }
    if (commands.isEmpty) return false;
    scope.history.pushApplied(
      CompositeCommand(label: label, commands: commands),
    );
    scope.sceneState
      ..markDirty()
      ..refresh();
    return true;
  }

  /// Every saved field of [component], as saved (deep-copied); null for a
  /// component with no definition.
  static Map<String, Object?>? snapshot(
    EditorScope scope,
    jge.Component component,
  ) {
    final definition = scope.definitions.definitionFor(component);
    if (definition == null) return null;
    return {
      for (final field in definition.fields)
        if (field.write != null) field.name: _copy(field.encodeFrom(component)),
    };
  }

  static Object? _copy(Object? value) => jsonDecode(jsonEncode(value));

  /// The entity of the scene's world each of [components] is on, where it
  /// is on one — one pass over the world, once per edit.
  Map<jge.Component, jge.Entity> _ownersOf(List<jge.Component> components) {
    final wanted = Set<jge.Component>.identity()..addAll(components);
    final out = Map<jge.Component, jge.Entity>.identity();
    final types = {for (final c in components) c.componentType};
    for (final e in scope.world.entities) {
      for (final type in types) {
        final c = e.getComponentByType(type);
        if (c != null && wanted.contains(c)) out[c] = e;
      }
      if (out.length == wanted.length) break;
    }
    return out;
  }
}
