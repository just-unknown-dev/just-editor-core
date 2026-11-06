import 'package:just_game_engine/just_game_engine.dart';
import 'package:meta/meta.dart';

import '../scope/editor_scope.dart';

/// What `ScopeProject` keeps per scope beside its services: what points
/// at a layer or a tag, the game's spawners, and what it asks of the
/// modules — the tags their code declares, which the module wiring hands
/// in.
@internal
final class ProjectState {
  ProjectState._();

  /// [scope]'s, made when first asked for.
  static ProjectState of(EditorScope scope) =>
      scope.service<ProjectState>(ProjectState._, dispose: (s) => s.dispose());

  /// See `ScopeProject.highlightedLayer`.
  final Signal<int?> highlightedLayer = Signal(
    null,
    debugLabel: 'highlightedLayer',
  );

  /// See `ScopeProject.highlightedTag`.
  final Signal<String?> highlightedTag = Signal(
    null,
    debugLabel: 'highlightedTag',
  );

  /// See `ScopeProject.spawners`.
  final Signal<List<Spawner>> spawners = Signal(
    const [],
    debugLabel: 'spawners',
  );

  /// The tags the modules' code looks for by name. None until the module
  /// wiring sets it.
  List<TagDefinition> Function() declaredTags = _none;

  static List<TagDefinition> _none() => const [];

  /// Whether `ScopeProject.tags` has been made: reading it scans the
  /// scenes, so a rebuild of the modules' contributions brings its
  /// declared tags up to date only once it is.
  bool tagsMade = false;

  /// Disposes the signals; the scope does, when it is disposed.
  void dispose() {
    spawners.dispose();
    highlightedTag.dispose();
    highlightedLayer.dispose();
  }
}
