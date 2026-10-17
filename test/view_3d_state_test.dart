// The 3-D view's editor state: how the scene is drawn, the selection's
// outline, the slice — and hiding and locking that reach a group's
// children.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';

void main() {
  test('the view starts lit, outlined, unsliced', () {
    final state = Designer3DState();
    addTearDown(state.dispose);
    expect(state.viewMode.value, ViewMode3D.lit);
    expect(state.outline.value, isTrue);
    expect(state.sliceOn.value, isFalse);
    expect(state.sliceY.value, lessThan(0), reason: 'above the ground: up is -Y');
    expect(ViewMode3D.values.map((m) => m.label), everyElement(isNotEmpty));
  });

  group('hiding and locking reach a group\'s children', () {
    late World world;
    late Entity group, child, grandchild, other;
    late EditorViewState view;

    setUp(() {
      world = World()..initialize();
      view = EditorViewState();
      group = world.createEntityWithComponents([TransformComponent()], name: 'group');
      child = world.createEntityWithComponents([
        TransformComponent(),
        ParentComponent(parentId: group.id),
      ], name: 'child');
      grandchild = world.createEntityWithComponents([
        TransformComponent(),
        ParentComponent(parentId: child.id),
      ], name: 'grandchild');
      other = world.createEntityWithComponents([TransformComponent()], name: 'other');
    });
    tearDown(() {
      view.dispose();
      world.dispose();
    });

    test('hiding the group hides everything under it', () {
      view.setHidden([group.id], hidden: true);
      expect(view.isHiddenIn(group), isTrue);
      expect(view.isHiddenIn(grandchild), isTrue);
      expect(view.isHiddenIn(other), isFalse);
      expect(view.isHidden(grandchild.id), isFalse, reason: 'its own eye is open');
    });

    test('locking the group locks everything under it', () {
      view.setLocked([child.id], locked: true);
      expect(view.isLockedIn(grandchild), isTrue);
      expect(view.isLockedIn(group), isFalse);
    });
  });
}
