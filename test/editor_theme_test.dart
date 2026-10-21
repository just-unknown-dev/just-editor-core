// One palette: what `EditorTheme.of(context)` hands out is what every
// `EditorTheme` colour reads — high contrast and colour-blind-safe colours
// included — inside a theme scope or out of it.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  tearDown(() => EditorTheme.apply(EditorThemeData.classic));

  testWidgets('the palette in force is the one applied, in a scope or not', (
    tester,
  ) async {
    final controller = ThemeController();
    addTearDown(controller.dispose);
    // As the overlay does: the picked theme, adjusted for accessibility.
    final applied = EditorThemeData.classic.colourBlindSafe().highContrast();
    EditorTheme.apply(applied, from: controller.current.value);

    EditorThemeData? inside, outside;
    await tester.pumpWidget(
      Column(
        children: [
          EditorThemeScope(
            controller: controller,
            child: Builder(
              builder: (context) {
                inside = EditorTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
          Builder(
            builder: (context) {
              outside = EditorTheme.of(context);
              return const SizedBox();
            },
          ),
        ],
      ),
    );
    expect(inside, same(applied));
    expect(outside, same(applied));
    expect(inside!.error, EditorTheme.error);
  });

  testWidgets('a widget reading it is built again when the theme changes', (
    tester,
  ) async {
    final controller = ThemeController();
    addTearDown(controller.dispose);
    var builds = 0;
    await tester.pumpWidget(
      EditorThemeScope(
        controller: controller,
        child: Builder(
          builder: (context) {
            EditorTheme.of(context);
            builds++;
            return const SizedBox();
          },
        ),
      ),
    );
    controller.select(ThemeController.builtIn.last.$1);
    await tester.pump();
    expect(builds, 2);
  });

  testWidgets('a theme not applied yet is the scope\'s own', (tester) async {
    final controller = ThemeController();
    addTearDown(controller.dispose);
    EditorTheme.apply(EditorThemeData.classic.highContrast());
    controller.select(ThemeController.builtIn[1].$1);
    EditorThemeData? shown;
    await tester.pumpWidget(
      EditorThemeScope(
        controller: controller,
        child: Builder(
          builder: (context) {
            shown = EditorTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(shown, same(controller.current.value));
  });
}
