// Hex cells: each cell's centre maps back to it, a fill goes six ways and
// never merges, and a module that brings the grid makes the Level
// Designer's cells hexes once it is the designer chosen. (The cell tests
// moved here from just_game_engine_editor with the grid.)

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

void main() {
  group('HexGrid', () {
    const hex = HexGrid();
    test('a cell centre maps back to its cell', () {
      for (var q = -3; q <= 3; q++) {
        for (var r = -3; r <= 3; r++) {
          final cell = Point2(q, r);
          expect(hex.cellAt(hex.cellCenter(cell, 32), 32), cell);
        }
      }
    });

    test('fills six ways and never merges', () {
      expect(hex.neighbours(const Point2(0, 0)).toSet(), hasLength(6));
      expect(hex.merge({const Point2(0, 0), const Point2(1, 0)}, 32), isNull);
      // A ring of six around the origin encloses it.
      final ring = hex.neighbours(const Point2(0, 0)).toSet();
      final filled = hex.floodFill(
        const Point2(0, 0),
        ring,
        limit: const Rect.fromLTRB(-3, -3, 4, 4),
      );
      expect(filled, {const Point2(0, 0)});
    });

    test('a 3×3 brush is a hex of radius one: seven cells', () {
      expect(hex.brush(const Point2(0, 0), 3).toSet(), hasLength(7));
    });
  });

  test('the hex module makes the cells hexes while it is the designer', () {
    final scope = EditorScope(
      world: World()..initialize(),
      modules: [HexGridModule()],
      settingsStore: MemorySettingsStore(),
    );
    addTearDown(scope.dispose);
    expect(scope.grid, isA<SquareGrid>());

    scope.selectDesigner('hexGrid');
    expect(scope.grid, isA<HexGrid>());

    scope.selectDesigner(null);
    expect(scope.grid, isA<SquareGrid>());
  });
}
