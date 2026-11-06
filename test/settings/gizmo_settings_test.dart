// Each mode keeps its own gizmos: shown while editing, hidden in the Level
// Designer and a play-test to begin with, and kinds turned off within a
// mode leave the other modes alone. Saved as short strings that read back
// the same, and survive what they do not know.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';

void main() {
  const defaults = GizmoSettings.defaults;

  test('as they start: shown in the editor, hidden in the Level Designer '
      'and a play-test, every kind on', () {
    expect(defaults.editor, const GizmoModeSettings(shown: true));
    expect(defaults.designer, const GizmoModeSettings(shown: false));
    expect(defaults.play, const GizmoModeSettings(shown: false));
    for (final mode in GizmoMode.values) {
      expect(defaults.of(mode), GizmoModeSettings.defaultFor(mode));
    }
    expect(const OverlayUiSettings.defaults().gizmos, defaults);
  });

  test('a mode toggled, or a kind turned off, leaves the other modes', () {
    final toggled = defaults.toggled(GizmoMode.play);
    expect(toggled.play.shown, isTrue);
    expect(toggled.editor, defaults.editor);
    expect(toggled.designer, defaults.designer);

    final mine = defaults.editor.withKind(GizmoKind.colliders, on: false);
    expect(mine.shows(GizmoKind.colliders), isFalse);
    expect(mine.shows(GizmoKind.icons), isTrue);
    expect(mine.withKind(GizmoKind.colliders, on: true), defaults.editor);
    expect(
      const GizmoModeSettings(shown: false).shows(GizmoKind.icons),
      isFalse,
      reason: 'hidden: no kind shows',
    );
  });

  test('saved as a short string that reads back the same', () {
    const mine = GizmoModeSettings(
      shown: true,
      hidden: {GizmoKind.selection, GizmoKind.colliders},
    );
    expect(mine.encode(), 'on:colliders,selection');
    expect(const GizmoModeSettings(shown: false).encode(), 'off');
    for (final s in [mine, const GizmoModeSettings(shown: false)]) {
      expect(GizmoModeSettings.decode(s.encode(), defaults.play), s);
    }
  });

  test('what it cannot read falls back; a kind it does not know is '
      'skipped', () {
    const fallback = GizmoModeSettings(shown: true);
    expect(GizmoModeSettings.decode(null, fallback), fallback);
    expect(GizmoModeSettings.decode('maybe', fallback), fallback);
    expect(
      GizmoModeSettings.decode('off:icons,sparkles', fallback),
      const GizmoModeSettings(shown: false, hidden: {GizmoKind.icons}),
    );
  });
}
