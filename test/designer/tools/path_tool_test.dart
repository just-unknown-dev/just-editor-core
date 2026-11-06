// Waypoints edited on the canvas: a click on empty space adds one, a drag
// moves one, Ctrl+click takes one away — each one undo step, found again
// by its entity. A waypoint clicked and let go where it was is no step.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

/// A component holding a route, as a kit's patrol would.
class _Route extends Component {
  _Route(this.points);
  List<Offset> points;
}

void main() {
  late World world;
  late EditorSceneState state;
  late EditorHistory history;
  late LevelDesignerController controller;
  late PathTool tool;
  late _Route route;

  setUp(() {
    world = World()..initialize();
    state = EditorSceneState()..openScene(EditorScene(name: 'test'));
    history = EditorHistory();
    controller = LevelDesignerController(sceneState: state, history: history)
      ..snapEnabled.value = false;
    tool = PathTool(
      sceneState: state,
      history: history,
      binding: PathBinding(
        resolve: (e) => e.getComponent<_Route>(),
        read: (c) => (c as _Route).points,
        write: (c, points) => (c as _Route).points = List.of(points),
      ),
    );
    route = _Route([const Offset(0, 0), const Offset(100, 0)]);
    final patrol = world.createEntityWithComponents([
      TransformComponent(),
      route,
    ], name: 'Patrol');
    state
      ..registerEntity(patrol)
      ..selectEntity(patrol);
  });

  tearDown(() {
    controller.dispose();
    history.dispose();
    state.dispose();
    world.dispose();
  });

  ToolContext at(double x, double y, {bool ctrl = false}) => ToolContext(
    world: world,
    controller: controller,
    worldPosition: Offset(x, y),
    gridSize: 32,
    isCtrlDown: ctrl,
  );

  test('a click on empty space adds a waypoint, as one step', () {
    expect(tool.onPointerDown(at(200, 50)), isTrue);
    tool.onPointerUp(at(200, 50));
    expect(route.points, [
      Offset.zero,
      const Offset(100, 0),
      const Offset(200, 50),
    ]);
    expect(history.undoDepth, 1);
    expect(history.nextUndoLabel.value, 'Add waypoint');
    history.undo();
    expect(route.points, [Offset.zero, const Offset(100, 0)]);
  });

  test('a drag moves a waypoint, as one step however far it went', () {
    tool.onPointerDown(at(101, 1));
    tool
      ..onPointerMove(at(120, 10))
      ..onPointerMove(at(140, 30));
    expect(route.points.last, const Offset(140, 30), reason: 'shown live');
    expect(history.undoDepth, 0, reason: 'recorded on release');
    tool.onPointerUp(at(140, 30));
    expect(history.undoDepth, 1);
    expect(history.nextUndoLabel.value, 'Move waypoint');
    history.undo();
    expect(route.points.last, const Offset(100, 0));
    history.redo();
    expect(route.points.last, const Offset(140, 30));
  });

  test('a waypoint clicked and let go where it was is no step', () {
    state.markClean();
    tool
      ..onPointerDown(at(100, 0))
      ..onPointerUp(at(100, 0));
    expect(history.undoDepth, 0);
    expect(state.isDirty.value, isFalse, reason: 'nothing to save');
  });

  test('Ctrl+click takes a waypoint away, but not below the least a '
      'path needs', () {
    route.points = [Offset.zero, const Offset(100, 0), const Offset(200, 0)];
    tool.onPointerDown(at(100, 0, ctrl: true));
    expect(route.points, [Offset.zero, const Offset(200, 0)]);
    expect(history.nextUndoLabel.value, 'Remove waypoint');
    tool.onPointerDown(at(200, 0, ctrl: true));
    expect(route.points, hasLength(2), reason: 'two is the least');
    expect(controller.status.value, 'A path needs at least two points');
    history.undo();
    expect(route.points, hasLength(3));
  });

  test('a cancelled drag puts the waypoint back and records nothing', () {
    tool
      ..onPointerDown(at(100, 0))
      ..onPointerMove(at(300, 300))
      ..onCancel();
    expect(route.points.last, const Offset(100, 0));
    expect(history.undoDepth, 0);
  });

  test('with nothing that has a path selected, it says so', () {
    state.clearSelection();
    expect(tool.onPointerDown(at(0, 0)), isFalse);
    expect(controller.status.value, 'Select something with an editable path');
  });

  test('each click is its own step', () {
    tool
      ..onPointerDown(at(200, 0))
      ..onPointerUp(at(200, 0))
      ..onPointerDown(at(300, 0))
      ..onPointerUp(at(300, 0));
    expect(history.undoDepth, 2);
  });
}
