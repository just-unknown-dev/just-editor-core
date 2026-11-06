import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/kit.dart';
import 'package:just_signals/just_signals.dart';

void main() {
  testWidgets('the first change at once, a run of them a few times a '
      'second, the last always', (tester) async {
    final often = Signal(0);
    final now = Signal(0);
    addTearDown(often.dispose);
    addTearDown(now.dispose);
    var builds = 0;
    await tester.pumpWidget(
      ThrottledSignalConsumer(
        often: often,
        signals: [now],
        builder: (context) {
          builds++;
          return Text(
            '${often.value} ${now.value}',
            textDirection: TextDirection.ltr,
          );
        },
      ),
    );
    expect(builds, 1);

    often.value = 1;
    await tester.pump();
    expect(builds, 2, reason: 'the first change, at once');
    expect(find.text('1 0'), findsOneWidget);

    // A drag: a change every frame for a third of a second.
    for (var i = 2; i <= 20; i++) {
      often.value = i;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds, lessThanOrEqualTo(6), reason: 'not once per change');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('20 0'), findsOneWidget, reason: 'the last one always');

    // The others are followed at once, whatever the first is doing.
    often.value = 21;
    now.value = 1;
    await tester.pump();
    expect(find.text('21 1'), findsOneWidget);

    // Gone mid-run: nothing left waiting.
    often.value = 22;
    await tester.pumpWidget(const SizedBox());
  });
}
