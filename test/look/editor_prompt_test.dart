// The kit's text prompt: what is typed comes back trimmed, Cancel gives
// null, a check says what is wrong as it is typed and holds the answer
// back, and an empty answer is taken only when asked for. And the
// viewport's look follows the one set of settings the host applies.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  // The dialog's answer, as a record: an async function returning the
  // future itself would wait for it.
  Future<({Future<String?> answer})> open(
    WidgetTester tester, {
    String? Function(String text)? validate,
    bool allowEmpty = false,
    String initial = '',
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final answer = showEditorPrompt(
      context,
      title: 'Rename',
      initial: initial,
      actionLabel: 'Rename',
      validate: validate,
      allowEmpty: allowEmpty,
    );
    await tester.pumpAndSettle();
    return (answer: answer);
  }

  testWidgets('what is typed comes back trimmed', (tester) async {
    final (:answer) = await open(tester);
    await tester.enterText(find.byType(TextField), '  level_2 ');
    await tester.pump();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'closed');
    expect(await answer, 'level_2');
  });

  testWidgets('Cancel gives null', (tester) async {
    final (:answer) = await open(tester, initial: 'level_1');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'closed');
    expect(await answer, isNull);
  });

  testWidgets('a check says what is wrong, and holds the answer back', (
    tester,
  ) async {
    final (:answer) = await open(
      tester,
      validate: (text) => text == 'taken' ? 'That name is taken' : null,
    );
    await tester.enterText(find.byType(TextField), 'taken');
    await tester.pump();
    expect(find.text('That name is taken'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget, reason: 'still open');

    await tester.enterText(find.byType(TextField), 'free');
    await tester.pump();
    expect(find.text('That name is taken'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'closed');
    expect(await answer, 'free');
  });

  testWidgets('an empty answer only when it is allowed', (tester) async {
    var (:answer) = await open(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget, reason: 'still open');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'closed');
    expect(await answer, isNull);

    (:answer) = await open(tester, allowEmpty: true);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'closed');
    expect(await answer, '');
  });

  test('the viewport look follows the settings the host applies', () {
    addTearDown(() => EditorMetrics.apply(const OverlayUiSettings.defaults()));
    const red = Color(0xFFFF0000);
    EditorMetrics.apply(
      const OverlayUiSettings.defaults().copyWith(
        selectionColor: red,
        gizmoScale: 1.5,
      ),
    );
    expect(ViewportLook.selection, red);
    expect(ViewportLook.designerSelection, red);
    expect(ViewportLook.gizmoScale, 1.5);
  });
}
