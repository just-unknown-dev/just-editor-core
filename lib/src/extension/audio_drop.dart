import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'asset_kind.dart';

/// What an audio file dropped on the viewport becomes, and the source
/// the editor's sound prefabs place.
abstract final class AudioDrop {
  /// An audio file dropped on the viewport: a looping source playing it —
  /// placed in 3-D in a 3-D scene, flat in a 2-D one.
  static jge.Entity? place(AssetDrop drop) {
    final in3d = drop.scope.sceneState.editingMode == jge.SceneMode.threeD;
    final slash = drop.path.lastIndexOf('/');
    final dot = drop.path.lastIndexOf('.');
    final stem = drop.path.substring(
      slash + 1,
      dot > slash ? dot : drop.path.length,
    );
    return drop.place([
      if (in3d)
        jge.TransformComponent(position: jge.Vector3.copy(drop.at)..y -= lift)
      else
        jge.LayerComponent(),
      source(drop.path, in3d: in3d, spatial: in3d),
    ], name: stem);
  }

  /// How far above the ground a sound is put in 3-D, metres (up is −Y).
  static const double lift = 1;

  /// A looping source of [path]. A 3-D one carries by the scene's units:
  /// metres in 3-D (full within 1, silent past 20, muffled, with doppler),
  /// pixels in 2-D (full within 64, silent past 1024).
  static jge.AudioSourceComponent source(
    String path, {
    required bool in3d,
    bool spatial = false,
  }) => jge.AudioSourceComponent(
    clipPath: path,
    loop: true,
    is3d: spatial,
    minDistance: in3d ? 1 : 64,
    maxDistance: in3d ? 20 : 1024,
    dopplerLevel: spatial && in3d ? 1 : 0,
    farCutoff: spatial ? 2000 : 0,
  );
}
