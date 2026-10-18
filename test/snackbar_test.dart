// Messages stack at the canvas's corner, each following its own task: one
// shown or minimised never cuts another's task off.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  late EditorSnackBarController c;
  setUp(() => c = EditorSnackBarController());
  tearDown(() => c.dispose());

  test('a minimised task goes on while another message shows', () async {
    final task = StreamController<EditorSnackBarStep>();
    final build = c.showSnackBar(
      EditorSnackBarEntry(message: 'Building', progressStream: task.stream),
    );
    c.minimize(build);
    c.showSnackBar(const EditorSnackBarEntry(message: 'Saved'));

    task.add(const EditorSnackBarStep(message: 'step 1'));
    await Future<void>.delayed(Duration.zero);
    expect(build.steps.single.message, 'step 1');
    expect(c.minimized, [build]);
    expect(c.visible.single.entry.message, 'Saved');
    await task.close();
  });

  test('no more than three show; the oldest message makes room', () {
    for (var i = 0; i < 4; i++) {
      c.showSnackBar(EditorSnackBarEntry(message: 'm$i'));
    }
    expect([for (final s in c.visible) s.entry.message], ['m1', 'm2', 'm3']);
  });

  testWidgets('a message goes by itself; a failed task stays', (tester) async {
    final task = StreamController<EditorSnackBarStep>();
    c.showSnackBar(
      const EditorSnackBarEntry(
        message: 'Hello',
        duration: Duration(seconds: 2),
      ),
    );
    final build = c.showSnackBar(
      EditorSnackBarEntry(message: 'Building', progressStream: task.stream),
    );
    task.add(const EditorSnackBarStep(message: 'broke', isError: true));
    await task.close();
    await tester.pump(const Duration(seconds: 10));

    expect(c.visible, [build]);
    expect(build.failed, isTrue);
    c.dismiss(build);
    expect(c.snacks.value, isEmpty);
  });

  // The layer in a corner, with [c] its controller.
  Future<void> mountLayer(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: EditorMessenger(
        child: Builder(
          builder: (context) => Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Builder(
                    builder: (context) {
                      c = EditorMessenger.of(context);
                      return const EditorSnackBarLayer();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('the layer shows them, and dismisses one', (tester) async {
    await mountLayer(tester);
    c.showSnackBar(const EditorSnackBarEntry(title: 'Saved', message: 'All'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a message has no bar; it goes when its time is up', (
    tester,
  ) async {
    await mountLayer(tester);
    c.showSnackBar(const EditorSnackBarEntry(message: '7 lines copied'));
    await tester.pump();
    expect(find.text('7 lines copied'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('7 lines copied'), findsNothing);
  });

  testWidgets('a task shows a bar with its percentage only while it counts', (
    tester,
  ) async {
    await mountLayer(tester);
    final task = StreamController<EditorSnackBarStep>();
    c.showSnackBar(
      EditorSnackBarEntry(message: 'Installing', progressStream: task.stream),
    );
    await tester.pump();
    // Running, but not saying how far: a spinner, no bar.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    task.add(const EditorSnackBarStep(message: 'Downloading', progress: 0.42));
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.42);
    expect(find.text('42%'), findsOneWidget);

    // Done: the bar goes, and the message after a moment.
    task.add(const EditorSnackBarStep(message: 'Done'));
    await task.close();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('42%'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Installing'), findsNothing);
  });

  testWidgets('minimising a task takes its card away at once', (tester) async {
    await mountLayer(tester);
    final task = StreamController<EditorSnackBarStep>();
    c.showSnackBar(
      EditorSnackBarEntry(message: 'Installing', progressStream: task.stream),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Minimise to the status bar'));
    await tester.pump();
    expect(find.text('Installing'), findsNothing);
    expect(c.minimized, hasLength(1));
    await task.close();
    await tester.pump(const Duration(seconds: 10));
  });
}
