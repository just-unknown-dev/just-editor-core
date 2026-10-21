// A minimal editor module: a coin the Level Designer can place, and an
// inspector editor for the coin's own field type.
//
// A game hands its module to the editor in its debug entry point
// (lib/main_editor.dart, which imports just_game_engine_editor):
//
//     final plugin = await JustGameEditorPlugin.register(
//       engine: engine,
//       modules: [CoinModule()],
//     );
//
// main() below needs neither the editor nor a window: it makes an editor
// scope over a bare world, the way a module's tests do, and says what the
// module added to it.

import 'package:flutter/material.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ── The game's side: shipped with the game ─────────────────────────────────

/// A pickup worth [value] points.
class CoinComponent extends Component {
  /// A coin worth [value].
  CoinComponent({this.value = 1});

  /// The points it gives.
  int value;
}

/// A coin's worth: saved as a JSON number, edited as a choice of 1, 5 or 10
/// (the inspector looks its editor up by [id]).
class CoinValueFieldType extends FieldType<int> {
  /// The one instance there needs to be.
  const CoinValueFieldType();

  @override
  String get id => 'coins.value';

  @override
  Object? encode(int value) => value;

  @override
  Object? decode(Object? json, FieldConstraints constraints) =>
      json is num ? json.toInt() : json;
}

/// How a coin is saved, loaded and shown in the inspector. A getter, not a
/// `final`, so a hot reload picks up an edit to it.
ComponentDefinition<CoinComponent> get coinDefinition => ComponentDefinition(
  type: 'CoinComponent',
  create: CoinComponent.new,
  fields: [
    SchemaField(
      name: 'value',
      kind: const CoinValueFieldType(),
      read: (c) => (c as CoinComponent).value,
      write: (c, v) => (c as CoinComponent).value = v as int,
    ),
  ],
  hints: const ComponentHints(
    name: 'Coin',
    group: 'Gameplay',
    icon: Icons.monetization_on,
    fields: {'value': FieldHint(label: 'Value')},
  ),
);

// ── The editor's side: only the debug entry point imports it ───────────────

/// What the editor gets from the game for its coins.
class CoinModule extends EditorModule {
  @override
  String get id => 'coins';

  @override
  String get name => 'Coins';

  /// The coin, placed with a click, in every Level Designer beside the
  /// editor's own shapes. (Prefabs in `prefabs` instead make the module a
  /// Level Designer of its own, picked in the designer switch.)
  @override
  List<PrefabDefinition> get sharedPrefabs => [
    PrefabDefinition(
      id: 'coins.coin',
      name: 'Coin',
      category: 'Pickups',
      icon: Icons.monetization_on,
      color: const Color(0xFFFFC107),
      placement: PrefabPlacement.point,
      defaultSize: const Size(16, 16),
      description: 'A coin worth 1 point.',
      // New components every time: two coins must not share one.
      build: (position, size) => [
        TransformComponent(position: Vector3(position.dx, position.dy, 0)),
        CoinComponent(),
      ],
    ),
  ];

  /// The inspector's control for a [CoinValueFieldType] field, by its id.
  @override
  Map<String, FieldEditorBuilder> get fieldEditors => {
    'coins.value': (field) => DropdownEditorRow(
      label: field.label,
      value: '${field.value}',
      options: const ['1', '5', '10'],
      onChanged: (picked) => field.onChanged(int.parse(picked)),
    ),
  };
}

/// Makes an editor scope with [CoinModule] in it, over a bare world, and
/// says what the module added.
void main() {
  final world = World()..initialize();
  // The game registers its definitions at boot, in both entry points.
  world.context.definitions.register(coinDefinition);
  final scope = EditorScope(world: world, modules: [CoinModule()]);

  final coin = scope.prefabs.byId('coins.coin');
  debugPrint('Level Designer palette: ${coin?.name}, in ${coin?.category}');
  final editor = scope.fieldEditors.byTypeId(const CoinValueFieldType().id);
  debugPrint('Inspector editor for coins.value: ${editor != null}');

  scope.dispose();
  world.dispose();
}
