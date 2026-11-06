// An edit made by code — a handle dragged, a collider fitted, a preset
// applied — is one undo step of every saved field it changed, however many
// components it touched, and nothing when it changed nothing. Undone after
// its component was replaced, it writes the one in its place.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

void main() {
  late EditorScope scope;
  late Entity entity;
  late HealthComponent health;
  late TransformComponent transform;

  setUp(() {
    scope = EditorScope(
      world: World(extensions: [BuiltInComponents.extension])..initialize(),
      settingsStore: MemorySettingsStore(),
    );
    health = HealthComponent(maxHealth: 3);
    transform = TransformComponent();
    entity = scope.world.createEntityWithComponents([
      transform,
      health,
    ], name: 'Knight');
    scope.sceneState
      ..openScene(EditorScene(name: 'test'))
      ..registerEntity(entity)
      ..markClean();
  });
  tearDown(() => scope.dispose());

  test('what changed is one step, named for the edit', () {
    final edit = ComponentEdit.begin(scope, health);
    health
      ..maxHealth = 9
      ..health = 2;
    expect(edit.commit('Heal'), isTrue);

    final history = scope.history;
    expect(history.undoDepth, 1);
    expect(history.nextUndoLabel.value, 'Heal');
    expect(scope.sceneState.isDirty.value, isTrue);
    final step = history.undoEntries.single as CompositeCommand;
    expect(
      [for (final c in step.commands) (c as ComponentFieldCommand).field],
      unorderedEquals(['maxHealth', 'health']),
      reason: 'a step for each field changed, and no other',
    );

    history.undo();
    expect((health.maxHealth, health.health), (3.0, 3.0));
    history.redo();
    expect((health.maxHealth, health.health), (9.0, 2.0));
  });

  test('a commit with nothing changed records nothing', () {
    final edit = ComponentEdit.begin(scope, health);
    expect(edit.commit('Nothing'), isFalse);
    expect(scope.history.undoDepth, 0);
    expect(scope.sceneState.isDirty.value, isFalse);
  });

  test('components edited together, or one added as it goes, are one '
      'step', () {
    final edit = ComponentEdit.beginAll(scope, [health]);
    health.maxHealth = 5;
    edit
      ..include(transform)
      ..include(health); // in already: its "before" is kept
    transform.position.x = 64;
    expect(edit.components, hasLength(2));
    expect(edit.commit('Grow'), isTrue);
    expect(scope.history.undoDepth, 1);

    scope.history.undo();
    expect(health.maxHealth, 3);
    expect(transform.position.x, 0);
  });

  test('undone after its component was replaced, it writes the one in its '
      'place', () {
    final edit = ComponentEdit.begin(scope, health);
    health.maxHealth = 9;
    edit.commit('Heal');
    // A Stop after a play-test, or an undone delete, puts a fresh instance
    // where the edited one was.
    final fresh = HealthComponent(maxHealth: 9);
    entity.addComponent(fresh);

    scope.history.undo();
    expect(fresh.maxHealth, 3);
    scope.history.redo();
    expect(fresh.maxHealth, 9);
  });
}
