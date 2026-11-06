// The open scene's state: what is selected and what may be, and what each
// entity destroyed and made again is now — found in one step however often
// it was rebuilt, and as it was told, even when told late.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  late World world;
  late EditorSceneState state;

  setUp(() {
    world = World()..initialize();
    state = EditorSceneState()..openScene(EditorScene(name: 'test'));
  });

  tearDown(() {
    state.dispose();
    world.dispose();
  });

  Entity make(String name) =>
      world.createEntityWithComponents([TransformComponent()], name: name);

  group('selection', () {
    test('a toggle adds to what is selected, and takes away', () {
      final a = make('A'), b = make('B'), c = make('C');
      state.toggleMultiSelect(a);
      expect(state.selectedEntity.value, same(a), reason: 'alone, at first');
      state
        ..toggleMultiSelect(b)
        ..toggleMultiSelect(c);
      expect(state.multiSelectedIds.value, {a.id, b.id, c.id});
      expect(state.selectedEntity.value, same(c), reason: 'the last added');

      state.toggleMultiSelect(c);
      expect(state.multiSelectedIds.value, {a.id, b.id});
      expect(state.selectedEntity.value, isNotNull, reason: 'another leads');
      state
        ..toggleMultiSelect(a)
        ..toggleMultiSelect(b);
      expect(state.hasAnySelection, isFalse);
    });

    test('a range is selected whole, its anchor leading', () {
      final rows = [
        for (final n in ['A', 'B', 'C', 'D']) make(n),
      ];
      state.selectRange(rows.sublist(1), anchor: rows[3]);
      expect(state.multiSelectedIds.value, {
        for (final e in rows.sublist(1)) e.id,
      });
      expect(state.selectedEntity.value, same(rows[3]));
      state.clearMultiSelection();
      expect(state.multiSelectedIds.value, {rows[3].id});
      state.clearSelection();
      expect(state.selectedEntity.value, isNull);
    });

    test('what may not be selected is let go of, and cannot be picked', () {
      final mapPiece = make('Piece'), outside = make('Outside');
      state
        ..selectEntity(outside)
        ..toggleMultiSelect(mapPiece);
      // The Level Designer narrows the selection to its map.
      state.setSelectable((e) => e.name == 'Piece');
      expect(state.multiSelectedIds.value, {mapPiece.id});
      expect(state.selectedEntity.value, same(mapPiece));

      state.selectEntity(outside);
      expect(state.selectedEntity.value, same(mapPiece), reason: 'refused');
      state.toggleMultiSelect(outside);
      expect(state.multiSelectedIds.value, {mapPiece.id});
      state.selectRange([outside, mapPiece], anchor: outside);
      expect(state.selectedEntity.value, same(mapPiece));
      expect(state.multiSelectedIds.value, {mapPiece.id});

      state.setSelectable(null);
      state.selectEntity(outside);
      expect(state.selectedEntity.value, same(outside));
    });
  });

  group('an entity made again', () {
    test('is found in one step after many rebuilds, and holds nothing '
        'destroyed on the way', () {
      final first = make('E');
      final ids = [first.id];
      var now = first;
      for (var i = 0; i < 50; i++) {
        world.destroyEntity(now);
        final again = make('E');
        state.entityRebuilt(state.currentId(ids.first), again);
        ids.add(again.id);
        now = again;
      }
      for (final id in ids) {
        expect(state.currentId(id), now.id);
      }
      expect(state.liveEntity(first), same(now));
    });

    test('told late — Stop putting back what was rebuilt during play — '
        'what led through it follows it', () {
      // Before play: E0 deleted and the delete undone, so E0 is E1.
      final e0 = make('E');
      world.destroyEntity(e0);
      final e1 = make('E');
      state.entityRebuilt(e0.id, e1);
      // During play, the same again: E1 is E2.
      world.destroyEntity(e1);
      final e2 = make('E');
      state.entityRebuilt(e1.id, e2);
      // Stop takes what play made away, and puts back the entity it had
      // when play began, E1, as E3.
      world.destroyEntity(e2);
      final e3 = make('E');
      state.entityRebuilt(e1.id, e3);

      expect(state.currentId(e1.id), e3.id);
      expect(state.currentId(e0.id), e3.id, reason: 'E0 led through E1');
      expect(state.liveEntity(e0), same(e3));
      expect(state.currentId(e2.id), e2.id, reason: 'play made it; gone');
      expect(state.liveEntity(e2), isNull);

      // And E3 made again in turn takes all of them along.
      world.destroyEntity(e3);
      final e4 = make('E');
      state.entityRebuilt(e3.id, e4);
      expect(state.liveEntity(e0), same(e4));
      expect(state.liveEntity(e1), same(e4));
    });

    test('is forgotten when another scene is opened', () {
      final e0 = make('E');
      world.destroyEntity(e0);
      final e1 = make('E');
      state.entityRebuilt(e0.id, e1);
      state.openScene(EditorScene(name: 'other'));
      expect(state.currentId(e0.id), e0.id);
      expect(state.liveEntity(e0), isNull);
    });
  });
}
