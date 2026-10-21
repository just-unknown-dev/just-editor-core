// Small controls that must not trap or corrupt: a number no file can hold
// is refused, an outline keeps the points it needs, and a refused rename
// can be tried again.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  group('a typed number', () {
    test('is refused when no file could hold it', () {
      for (final text in ['NaN', 'Infinity', '-Infinity', '1e999', 'abc']) {
        expect(parseTypedNumber(text), isNull, reason: text);
      }
      expect(parseTypedNumber(' 12.5 '), 12.5);
    });

    test('is kept within the field and whole when it should be', () {
      const config = NumberScrubConfig(min: 0, max: 10, integer: true);
      expect(parseTypedNumber('42', config: config), 10);
      expect(parseTypedNumber('-3', config: config), 0);
      expect(parseTypedNumber('2.6', config: config), 3);
    });

    testWidgets('a row given "1e999" writes nothing', (tester) async {
      final kept = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ScrubFieldRow(
                label: 'X',
                value: 1,
                scrubConfig: const NumberScrubConfig(),
                onChanged: kept.add,
              ),
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '1e999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(kept, isEmpty);
    });
  });

  testWidgets('an outline keeps the points it needs', (tester) async {
    final changes = <List<Offset>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: OffsetListEditorRow(
              label: 'Vertices',
              points: const [Offset(0, 0), Offset(10, 0), Offset(0, 10)],
              minPoints: 3,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(changes, isEmpty, reason: 'three is the least a polygon has');
  });

  testWidgets('a refused rename can be tried again', (tester) async {
    final kept = <String>[];
    String? error;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 300,
              child: EntityRenameBox(
                initial: 'Enemy',
                error: error,
                onCommit: (name) {
                  if (name == 'Player') {
                    setState(() => error = 'Something else is called that');
                  } else {
                    kept.add(name);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final box = find.byType(TextField);
    await tester.enterText(box, 'Player');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(error, isNotNull);
    expect(kept, isEmpty);

    await tester.tap(box);
    await tester.pump();
    await tester.enterText(box, 'Boss');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(kept, ['Boss'], reason: 'the second Enter is a second try');
  });
}
