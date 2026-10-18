import 'package:flutter/foundation.dart';

/// Where the editor is, for what it draws over the level: each place keeps
/// its own gizmos, shown or hidden, and its own kinds turned off.
enum GizmoMode {
  /// Editing the scene, the Level Designer closed. Gizmos shown to begin
  /// with.
  editor('Editor', shownByDefault: true),

  /// The Level Designer open. Gizmos hidden to begin with: the level as it
  /// is built.
  designer('Level Designer', shownByDefault: false),

  /// A play-test, running or paused. Gizmos hidden to begin with: the game
  /// as it ships.
  play('Play-test', shownByDefault: false);

  const GizmoMode(this.label, {required this.shownByDefault});

  /// What the Gizmos menu calls it.
  final String label;

  /// Whether its gizmos are shown until it is told otherwise.
  final bool shownByDefault;
}

/// A kind of gizmo, turned off or on by itself: right-click the Gizmos
/// button.
enum GizmoKind {
  icons('Icons', 'Cameras, lights, sounds and spawn points, where they are'),
  cameras('Camera frames', 'What each camera frames: its zones, bounds, track'),
  colliders('Colliders', 'Collision shapes, coloured by their body'),
  selection('Selection outline', 'The frame round what is selected'),
  reach('Light and sound reach', 'How far a selected light or sound reaches'),
  aids('Paths and bounds', 'Motion paths, and a kit\'s paths, bounds and aids');

  const GizmoKind(this.label, this.description);

  /// What the Gizmos menu calls it.
  final String label;

  /// What it covers, for the menu's tooltip.
  final String description;
}

/// The gizmos of one [GizmoMode]: [shown] or not, and the kinds turned off
/// within it.
@immutable
class GizmoModeSettings {
  const GizmoModeSettings({required this.shown, this.hidden = const {}});

  /// [mode] as it starts: shown or not, every kind on.
  factory GizmoModeSettings.defaultFor(GizmoMode mode) =>
      GizmoModeSettings(shown: mode.shownByDefault);

  /// Whether this mode draws gizmos at all: the Gizmos button.
  final bool shown;

  /// The kinds left off while it does.
  final Set<GizmoKind> hidden;

  /// Whether [kind] is drawn: gizmos shown, and that kind not turned off.
  bool shows(GizmoKind kind) => shown && !hidden.contains(kind);

  GizmoModeSettings copyWith({bool? shown, Set<GizmoKind>? hidden}) =>
      GizmoModeSettings(
        shown: shown ?? this.shown,
        hidden: hidden ?? this.hidden,
      );

  /// With [kind] turned [on] or off.
  GizmoModeSettings withKind(GizmoKind kind, {required bool on}) => copyWith(
    hidden: on ? ({...hidden}..remove(kind)) : {...hidden, kind},
  );

  /// As the settings store keeps it: `on` or `off`, then any kinds turned
  /// off, `on:icons,colliders`.
  String encode() {
    final off = [
      for (final kind in GizmoKind.values)
        if (hidden.contains(kind)) kind.name,
    ];
    return '${shown ? 'on' : 'off'}${off.isEmpty ? '' : ':${off.join(',')}'}';
  }

  /// What [encode] wrote; [fallback] when there is nothing, or nothing it
  /// can read. A kind it does not know (from a newer editor) is skipped.
  static GizmoModeSettings decode(String? raw, GizmoModeSettings fallback) {
    if (raw == null) return fallback;
    final parts = raw.trim().split(':');
    final bool shown;
    switch (parts.first) {
      case 'on':
        shown = true;
      case 'off':
        shown = false;
      default:
        return fallback;
    }
    final hidden = <GizmoKind>{
      if (parts.length > 1)
        for (final name in parts[1].split(','))
          ?GizmoKind.values.asNameMap()[name.trim()],
    };
    return GizmoModeSettings(shown: shown, hidden: hidden);
  }

  @override
  bool operator ==(Object other) =>
      other is GizmoModeSettings &&
      other.shown == shown &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode => Object.hash(shown, Object.hashAllUnordered(hidden));

  @override
  String toString() => 'GizmoModeSettings(${encode()})';
}

/// The gizmos of every [GizmoMode], each its own.
@immutable
class GizmoSettings {
  const GizmoSettings({
    this.editor = const GizmoModeSettings(shown: true),
    this.designer = const GizmoModeSettings(shown: false),
    this.play = const GizmoModeSettings(shown: false),
  });

  /// Shown in the editor; hidden in the Level Designer and a play-test.
  static const GizmoSettings defaults = GizmoSettings();

  final GizmoModeSettings editor;
  final GizmoModeSettings designer;
  final GizmoModeSettings play;

  /// [mode]'s gizmos.
  GizmoModeSettings of(GizmoMode mode) => switch (mode) {
    GizmoMode.editor => editor,
    GizmoMode.designer => designer,
    GizmoMode.play => play,
  };

  /// With [mode]'s gizmos as [settings]; the other modes as they were.
  GizmoSettings withMode(GizmoMode mode, GizmoModeSettings settings) =>
      GizmoSettings(
        editor: mode == GizmoMode.editor ? settings : editor,
        designer: mode == GizmoMode.designer ? settings : designer,
        play: mode == GizmoMode.play ? settings : play,
      );

  /// With [mode]'s gizmos shown if they were hidden, or hidden if shown.
  GizmoSettings toggled(GizmoMode mode) =>
      withMode(mode, of(mode).copyWith(shown: !of(mode).shown));

  @override
  bool operator ==(Object other) =>
      other is GizmoSettings &&
      other.editor == editor &&
      other.designer == designer &&
      other.play == play;

  @override
  int get hashCode => Object.hash(editor, designer, play);
}
