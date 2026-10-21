// The package's example (example/example.dart) is what pub.dev shows a
// module author first: it must keep compiling against the package, and
// what it says the module adds must be what a scope holds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../example/example.dart' as example;

void main() {
  test('the example runs', example.main);

  test("the example module's prefab and field editor reach the scope", () {
    final world = World()..initialize();
    addTearDown(world.dispose);
    world.context.definitions.register(example.coinDefinition);
    final scope = EditorScope(world: world, modules: [example.CoinModule()]);
    addTearDown(scope.dispose);

    final coin = scope.prefabs.byId('coins.coin');
    expect(coin, isNotNull, reason: 'shared: in every Level Designer');
    final parts = coin!.build(const Offset(10, 20), coin.defaultSize);
    expect(parts.whereType<example.CoinComponent>(), hasLength(1));
    final at = parts.whereType<TransformComponent>().single.position;
    expect((at.x, at.y), (10.0, 20.0));

    final field = example.coinDefinition.fields.single;
    expect(scope.fieldEditors.forField(field), isNotNull);
  });

  testWidgets('the example field editor writes the value picked', (
    tester,
  ) async {
    final world = World()..initialize();
    addTearDown(world.dispose);
    final scope = EditorScope(world: world, modules: [example.CoinModule()]);
    addTearDown(scope.dispose);
    final coin = example.CoinComponent(value: 5);
    final field = example.coinDefinition.fields.single;
    Object? written;
    final row = scope.fieldEditors.build(
      FieldEditorContext(
        field: field,
        hint: const FieldHint(label: 'Value'),
        value: coin.value,
        component: coin,
        onChanged: (value) => written = value,
        editors: scope.fieldEditors,
      ),
    );
    expect(row, isA<DropdownEditorRow>());
    (row as DropdownEditorRow).onChanged('10');
    expect(written, 10);
    expect(row.value, '5');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 320, child: row)),
      ),
    );
    expect(find.text('Value'), findsOneWidget);
  });
}
