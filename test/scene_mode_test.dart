import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/host.dart';

class _Tool extends LevelToolHandler {
  _Tool(this.id, this.dimensions);
  @override
  final String id;
  @override
  final Dimensions dimensions;
  @override
  String get label => id;
  @override
  IconData get icon => const IconData(0);
}

void main() {
  test('a 3-D scene is edited in 3-D', () {
    final state = EditorSceneState();
    expect(state.editingMode, SceneMode.twoD);

    state.openScene(EditorScene(name: 'deep', mode: SceneMode.threeD));
    expect(state.sceneMode.value, SceneMode.threeD, reason: 'kept');
    expect(state.editingMode, SceneMode.threeD);

    state.closeScene();
    expect(state.sceneMode.value, SceneMode.twoD);
  });

  test('a 2-D scene shows a vector\'s x and y; a 3-D one all three', () {
    const field = SchemaField(
      name: 'scale',
      kind: FieldTypes.vector3,
      read: _none,
    );
    expect(SceneModeFilters.visibleChannels(field, null, SceneMode.twoD), {
      'x',
      'y',
    });
    expect(SceneModeFilters.visibleChannels(field, null, SceneMode.threeD), {
      'x',
      'y',
      'z',
    });
    expect(
      SceneModeFilters.visibleChannels(
        field,
        const FieldHint(channels2D: {'z'}),
        SceneMode.twoD,
      ),
      {'z'},
      reason: 'a hint can choose',
    );
  });

  test('fields and components show only where they belong', () {
    const threeDOnly = FieldHint(dimensions: Dimensions.threeD);
    expect(SceneModeFilters.fieldShown(threeDOnly, SceneMode.twoD), isFalse);
    expect(SceneModeFilters.fieldShown(threeDOnly, SceneMode.threeD), isTrue);
    expect(SceneModeFilters.fieldShown(null, SceneMode.twoD), isTrue);

    const flat = ComponentHints(dimensions: Dimensions.twoD);
    expect(SceneModeFilters.componentOffered(flat, SceneMode.twoD), isTrue);
    expect(SceneModeFilters.componentOffered(flat, SceneMode.threeD), isFalse);
  });

  test('tools, overlays and commands default to where they work', () {
    final tools = ToolRegistry()
      ..register(_Tool('flat', Dimensions.twoD))
      ..register(_Tool('any', Dimensions.both));
    var mode = SceneMode.twoD;
    tools.modeOf = () => mode;
    expect(tools.all.map((t) => t.id), containsAll(['flat', 'any']));
    mode = SceneMode.threeD;
    expect(tools.all.map((t) => t.id), ['any']);
    expect(
      tools.byId('flat'),
      isNull,
      reason: 'a hidden tool must not stay in hand',
    );
    mode = SceneMode.twoD;
    expect(tools.byId('flat'), isNotNull, reason: 'still registered');

    // One id, a tool for each mode: whoever asks by id gets the scene's.
    final flat = _Tool('select', Dimensions.twoD);
    final deep = _Tool('select', Dimensions.threeD);
    tools
      ..register(flat)
      ..register(deep);
    expect(tools.byId('select'), same(flat));
    mode = SceneMode.threeD;
    expect(tools.byId('select'), same(deep));
    expect(tools.all.where((t) => t.id == 'select'), [deep]);
    // Registering one for both modes replaces both.
    final both = _Tool('select', Dimensions.both);
    tools.register(both);
    expect(tools.byId('select'), same(both));
    mode = SceneMode.twoD;
    expect(tools.byId('select'), same(both));

    final overlays = OverlayRegistry();
    expect(overlays.all, isEmpty);

    final command = DesignerCommand(id: 'x', label: 'x', run: (_) {});
    expect(command.dimensions, Dimensions.both);
  });
}

Object? _none(Component c) => null;
