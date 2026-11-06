// A component's card records each field edit as an undo step of that
// field. Labels repeat — the framing camera's dead zone and soft zone each
// have a Height — and moving from one to the other presses nothing in the
// card, so the field, not the label, is what keeps the two steps apart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

void main() {
  testWidgets('typing in two fields of one label is two undo steps, each '
      'undoing its own', (tester) async {
    final scope = EditorScope(
      world: World(extensions: [BuiltInComponents.extension])..initialize(),
      settingsStore: MemorySettingsStore(),
    );
    addTearDown(scope.dispose);
    final camera = CameraFramingComponent();
    final entity = scope.world.createEntityWithComponents([
      TransformComponent(),
      camera,
    ], name: 'Camera');
    final deadBefore = camera.deadZoneHeight;
    final softBefore = camera.softZoneHeight;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: DefinitionSection(
                component: camera,
                entity: entity,
                definition: scope.definitions.definitionFor(camera)!,
                scope: scope,
                showAccessories: false,
                onDelete: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );

    Finder cell(String row, int index) => find
        .descendant(
          of: find.byWidgetPredicate(
            (w) => w is AxesFieldRow && w.label == row,
          ),
          matching: find.byType(TextField),
        )
        .at(index);

    // Typed in, Enter, then into the next field by the keys alone: no
    // press in the card between them to start a new step.
    await tester.enterText(cell('Dead zone', 1), '0.3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(cell('Soft zone', 1), '0.9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(camera.deadZoneHeight, closeTo(0.3, 1e-9));
    expect(camera.softZoneHeight, closeTo(0.9, 1e-9));
    final history = scope.history;
    expect(history.undoDepth, 2);
    // Named apart, too: an undo button that says which Height it undoes.
    expect(history.nextUndoLabel.value, 'Change Soft zone Height');

    history.undo();
    expect(camera.softZoneHeight, softBefore);
    expect(camera.deadZoneHeight, closeTo(0.3, 1e-9));
    history.undo();
    expect(camera.deadZoneHeight, deadBefore);
    history
      ..redo()
      ..redo();
    expect(camera.deadZoneHeight, closeTo(0.3, 1e-9));
    expect(camera.softZoneHeight, closeTo(0.9, 1e-9));
  });
}
