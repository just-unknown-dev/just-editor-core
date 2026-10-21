/// The scene open in the editor, as its file's header holds it.
library;

import 'package:just_game_engine/just_game_engine.dart';

/// A scene's name and how it is authored — the `name` and `mode` a scene
/// file keeps beside its `entities`.
///
/// The scene itself is its entities in the world; this is only what the
/// editor needs to know about the file they came from and go back to.
class EditorScene {
  EditorScene({required this.name, this.mode = SceneMode.twoD});

  /// Reads the header of a scene file (see [toJson]).
  ///
  /// [name] is the file's own name, and wins over the `name` written inside
  /// it: a scene copied to `level_07.scene.json` by hand still says
  /// `level_01`, and saving it under that name would overwrite level_01.
  /// Without [name], the file's `name` is used; a [FormatException] when it
  /// has none.
  factory EditorScene.fromJson(Map<String, dynamic> json, {String? name}) =>
      EditorScene(
        name:
            name ??
            switch (json['name']) {
              final String n when n.isNotEmpty => n,
              _ => throw const FormatException('The scene names no "name".'),
            },
        mode: SceneMode.fromId(json['mode']),
      );

  /// The scene's name — its file is `<name>.scene.json`.
  final String name;

  /// 2-D (the default) or 3-D. Only an editor reads it; every entity has a
  /// 3-D transform either way.
  SceneMode mode;

  /// The header fields a scene file starts with.
  Map<String, dynamic> toJson() => {'name': name, 'mode': mode.id};
}
