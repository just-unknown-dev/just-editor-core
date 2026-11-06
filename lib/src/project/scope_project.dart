import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;
import 'package:just_game_engine/just_game_engine.dart';

import '../scene/scope_scene.dart';
import '../scope/editor_scope.dart';
import 'project_colors.dart';
import 'project_physics_layers.dart';
import 'project_state.dart';
import 'project_tags.dart';
import 'tag_references.dart';

/// The project's own files on an [EditorScope] — its tags, collision
/// layers and palettes — and what points at them in the viewport.
extension ScopeProject on EditorScope {
  /// The project's tags: its tag file, the tags code declares, and the ones
  /// the game's spawners give.
  ///
  /// Without a tag file, the tags the open world carries stand in for it at
  /// once, and the ones the project's other scenes carry join them once
  /// those are read, in the background (`ProjectTags.seeded`).
  ProjectTags get tags => service<ProjectTags>(() {
    final state = ProjectState.of(this);
    final tags =
        ProjectTags(
            path: ProjectTags.pathFor(
              scenesRoot: scenesRoot,
              projectRoot: hasProjectRoot ? projectRoot : null,
            ),
            spawners: () => spawners.value,
            onProblem: (problem) => _reportProject(this, 'tags', problem),
          )
          ..setDeclared(state.declaredTags())
          ..load(seed: () => _tagsTheWorldCarries(this));
    if (!tags.hasFile) tags.seedLater(_tagsTheScenesCarry(this));
    // Only once it is made: a rebuild before then must not ask for it,
    // and one after a failed try must not take it as made.
    state.tagsMade = true;
    return tags;
  }, dispose: (t) => t.dispose());

  /// The project's collision layers: their names and which collide. Every
  /// change is saved and reaches the running game.
  ProjectPhysicsLayers get physicsLayers => service<ProjectPhysicsLayers>(
    () => ProjectPhysicsLayers(
      path: ProjectPhysicsLayers.pathFor(
        scenesRoot: scenesRoot,
        projectRoot: hasProjectRoot ? projectRoot : null,
      ),
      context: () => context,
      onProblem: (problem) => _reportProject(this, 'physics', problem),
    )..load(),
    dispose: (l) => l.dispose(),
  );

  /// The palettes and gradients the project keeps, and this user's recent
  /// colours: what every colour picker in the editor offers.
  ProjectColors get colors => service<ProjectColors>(
    () => ProjectColors(
      path: ProjectColors.pathFor(
        scenesRoot: scenesRoot,
        projectRoot: hasProjectRoot ? projectRoot : null,
      ),
      // A scope given its own settings store is a test's: it keeps its
      // hands off this machine's storage.
      storage: machineStorage,
      onProblem: (problem) => _reportProject(this, 'colours', problem),
    )..load(),
    dispose: (c) => c.dispose(),
  );

  /// Finds and rewrites tags in saved scenes and timelines, through
  /// [ScopeScene.definitions].
  TagReferences get tagReferences =>
      TagReferences(definitions.definitionByType);

  /// The collision layer being pointed at — a chip, a picker, a row of the
  /// Physics Layers dock — whose bodies the viewport rings. Null when none
  /// is.
  Signal<int?> get highlightedLayer => ProjectState.of(this).highlightedLayer;

  /// The tag being pointed at — a chip under the mouse — whose entities the
  /// viewport rings. Null when none is.
  Signal<String?> get highlightedTag => ProjectState.of(this).highlightedTag;

  /// What the game's spawn points can create, as the app registered it with
  /// the editor: what Play spawns, what a spawn point's "Spawns" field
  /// offers, and the tags that exist only once the game runs.
  Signal<List<Spawner>> get spawners => ProjectState.of(this).spawners;
}

/// A project file the editor keeps — the tags, the collision layers, the
/// palettes — that could not be read or written, in the log.
void _reportProject(EditorScope scope, String category, String problem) =>
    scope.log.log(
      problem,
      source: 'editor',
      category: category,
      level: DebuggerLogLevel.warning,
    );

/// The tags the open world carries: what a project that has no tag file
/// yet already uses, at once.
Set<String> _tagsTheWorldCarries(EditorScope scope) {
  try {
    return scope.world.tagsInUse.toSet();
  } on Object {
    // No world yet: the files will do.
    return {};
  }
}

/// The tags the project's scene files carry, each read and decoded in the
/// background ([SceneStore.readRawInBackground]): a project of many big
/// levels and no tag file must not stall the first tag picker opened.
Future<Set<String>> _tagsTheScenesCarry(EditorScope scope) async {
  final found = <String>{};
  final references = scope.tagReferences;
  final store = scope.scenes;
  for (final name in store.listSceneNames()) {
    // A scene that cannot be read — broken, from a newer engine, not a
    // scene at all — gives no tags; the others still do.
    try {
      final raw = await store.readRawInBackground(name);
      if (scope.isDisposed) break;
      if (raw == null) continue;
      final migrated = SceneFormat.migrate(
        raw,
        hooks: scope.context.migrations,
      );
      for (final use in references.inScene(migrated)) {
        if (use.kind == TagUseKind.carried) found.add(use.tag);
      }
    } on Object {
      continue;
    }
  }
  return found;
}
