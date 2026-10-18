// A slider shows the value dragged to while the drag lasts, whether or not
// its value follows: a live preview need not rebuild what holds it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  Future<(List<double>, List<double>)> pumpSlider(
    WidgetTester tester, {
    double value = 0.2,
  }) async {
    final changes = <double>[], ends = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: EditorSlider(
                value: value,
                min: 0,
                max: 1,
                step: 0.01,
                decimals: 2,
                onChanged: changes.add,
                onChangeEnd: ends.add,
              ),
            ),
          ),
        ),
      ),
    );
    return (changes, ends);
  }

  double shown(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider)).value;

  testWidgets('a drag moves the thumb and the number with nothing above '
      'rebuilt', (tester) async {
    final (changes, ends) = await pumpSlider(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();

    expect(changes, isNotEmpty);
    expect(shown(tester), changes.last, reason: 'the value dragged to');
    expect(shown(tester), isNot(0.2));
    expect(
      find.text(changes.last.toStringAsFixed(2)),
      findsOneWidget,
      reason: 'the number follows',
    );
    // Each step is told once: the same value is not told again.
    expect(changes.toSet().length, changes.length);

    await gesture.up();
    await tester.pump();
    expect(ends, [changes.last]);
    // Not kept by what holds it: back to the value it was given.
    expect(shown(tester), 0.2);
    expect(find.text('0.20'), findsOneWidget);
  });

  testWidgets('kept by what holds it, the slider stays where it was let go', (
    tester,
  ) async {
    var value = 0.2;
    final ends = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: StatefulBuilder(
                builder: (context, setState) => EditorSlider(
                  value: value,
                  min: 0,
                  max: 1,
                  step: 0.01,
                  decimals: 2,
                  onChanged: (_) {},
                  onChangeEnd: (v) => setState(() {
                    ends.add(v);
                    value = v;
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(Slider), const Offset(40, 0));
    await tester.pump();
    expect(ends, hasLength(1));
    expect(shown(tester), ends.single);
    expect(find.text(ends.single.toStringAsFixed(2)), findsOneWidget);
  });
}
