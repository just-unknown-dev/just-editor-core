import 'package:just_game_engine/just_game_engine.dart' as jge;

/// How a game's player moves, as far as a level's shape goes: how high and
/// how far a jump carries it, how steep a slope it walks up, how high a
/// step it takes. What the Level Designer's aids draw from.
///
/// Speeds are metres a second, gravity metres a second each second.
final class MovementProfile {
  /// A profile that walks up slopes to 45° and onto steps 0.3 metres high
  /// unless told otherwise.
  const MovementProfile({
    required this.jumpSpeed,
    required this.gravity,
    required this.runSpeed,
    this.maxSlopeDegrees = 45,
    this.stepHeight = 0.3,
  });

  /// How fast it leaves the ground when it jumps.
  final double jumpSpeed;

  /// How fast it falls faster: up to a stop, then back down.
  final double gravity;

  /// How fast it goes along the ground at its fastest.
  final double runSpeed;

  /// The steepest slope it walks up.
  final double maxSlopeDegrees;

  /// The highest step it walks onto.
  final double stepHeight;

  /// How high a jump carries it.
  double get jumpHeight =>
      gravity <= 0 ? 0 : jumpSpeed * jumpSpeed / (2 * gravity);

  /// How long a jump keeps it off level ground.
  double get airTime => gravity <= 0 ? 0 : 2 * jumpSpeed / gravity;

  /// How far a running jump carries it across level ground.
  double get jumpDistance => runSpeed * airTime;
}

/// What a game kit knows about how its levels are played, for the Level
/// Designer's aids: how its player moves ([movementOf]), below what height
/// things are lost ([killHeight]), and how a play-test starts from a point
/// ([playFrom]). A module offers one (`EditorModule.levelAids`); every
/// module's is asked, whichever designer is chosen — it describes the
/// game, not the tools.
///
/// +Y is down: below means larger.
abstract class LevelAids {
  const LevelAids();

  /// How [world]'s player moves; null when this kit has no player there.
  MovementProfile? movementOf(jge.World world) => null;

  /// The height (engine Y) past which what falls is lost or put back;
  /// null for none.
  double? killHeight(jge.World world) => null;

  /// A play-test has just begun in [world]: puts the player at [at]
  /// instead of its spawn point. Whether it did.
  bool playFrom(jge.World world, jge.Vector3 at) => false;
}
