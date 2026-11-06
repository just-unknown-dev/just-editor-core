import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart' as jge;

/// How the 3-D designer's Array lays copies out.
enum Array3DMode {
  /// In a row, each a step further on.
  linear('Line', 'In a row, each copy one step further on'),

  /// In rows and columns (and floors).
  grid('Grid', 'In rows and columns, and floors above them'),

  /// Round a circle.
  radial('Circle', 'Round a circle whose middle is the radius away along -X');

  const Array3DMode(this.label, this.description);

  /// Its name on a button.
  final String label;

  /// What it does.
  final String description;
}

/// One copy an array makes, as a change to the original: turned by [turn]
/// about [about] (its position, and its own turn when [turnsItself]), then
/// moved by [move].
final class Array3DStep {
  const Array3DStep(
    this.move,
    this.turn,
    this.about, {
    this.turnsItself = false,
  });

  /// How far it moves.
  final jge.Vector3 move;

  /// How it turns about [about].
  final jge.Quaternion turn;

  /// What it turns about.
  final jge.Vector3 about;

  /// Whether its own facing turns too, or only where it is.
  final bool turnsItself;

  /// Where something at [position] goes.
  jge.Vector3 apply(jge.Vector3 position) {
    final offset = position - about;
    turn.rotate(offset);
    return about + offset + move;
  }
}

/// The 3-D designer's Array: how many copies of the selection, laid out
/// how. Counts include the original.
///
/// +Y is down: a grid's floors go up, along -Y.
final class Array3DSpec {
  const Array3DSpec({
    this.mode = Array3DMode.linear,
    this.count = 4,
    this.stepX = 2,
    this.stepY = 0,
    this.stepZ = 0,
    this.columns = 3,
    this.floors = 1,
    this.rows = 3,
    this.spacingX = 2,
    this.spacingY = 2,
    this.spacingZ = 2,
    this.around = 8,
    this.radius = 4,
    this.sweep = 360,
    this.faceCentre = true,
  });

  /// How the copies are laid out, which picks the fields that count.
  final Array3DMode mode;

  /// In a row: how many.
  final int count;

  /// In a row: the step from one to the next along X, Y and Z (metres; +Y
  /// is down).
  final double stepX, stepY, stepZ;

  /// In a grid: how many along X, up, and along Z.
  final int columns, floors, rows;

  /// In a grid: how far apart along X, up, and along Z (metres).
  final double spacingX, spacingY, spacingZ;

  /// Round a circle: how many.
  final int around;

  /// Round a circle: its radius (metres), and how far round they go
  /// (degrees; 360 for all the way). The middle is [radius] along -X from
  /// the original.
  final double radius, sweep;

  /// Round a circle: whether each copy turns as it goes round, so it faces
  /// the middle as the original does, or only moves.
  final bool faceCentre;

  /// How many things there are when it is made, the original among them.
  int get total => switch (mode) {
    Array3DMode.linear => _one(count),
    Array3DMode.grid => _one(columns) * _one(floors) * _one(rows),
    Array3DMode.radial => _one(around),
  };

  static int _one(int n) => n < 1 ? 1 : n;

  /// The copies, each as a change to the original standing at [pivot]
  /// (the circle's middle is [radius] along -X from it).
  List<Array3DStep> steps(jge.Vector3 pivot) {
    final none = jge.Quaternion.identity();
    switch (mode) {
      case Array3DMode.linear:
        return [
          for (var i = 1; i < count; i++)
            Array3DStep(
              jge.Vector3(stepX * i, stepY * i, stepZ * i),
              none,
              pivot,
            ),
        ];
      case Array3DMode.grid:
        return [
          for (var f = 0; f < _one(floors); f++)
            for (var r = 0; r < _one(rows); r++)
              for (var c = 0; c < _one(columns); c++)
                if (c != 0 || f != 0 || r != 0)
                  Array3DStep(
                    jge.Vector3(c * spacingX, -f * spacingY, r * spacingZ),
                    none,
                    pivot,
                  ),
        ];
      case Array3DMode.radial:
        final centre = pivot - jge.Vector3(radius, 0, 0);
        // All the way round, the last stops short of the first; part way,
        // the last is at the end.
        final full = sweep.abs() >= 360 - 1e-9;
        final gaps = full ? around : around - 1;
        if (gaps <= 0) return const [];
        final each = sweep * math.pi / 180 / gaps;
        return [
          for (var i = 1; i < around; i++)
            Array3DStep(
              jge.Vector3.zero(),
              jge.Quaternion.axisAngle(jge.Vector3(0, -1, 0), each * i),
              centre,
              turnsItself: faceCentre,
            ),
        ];
    }
  }

  /// This spec with the given fields changed.
  Array3DSpec copyWith({
    Array3DMode? mode,
    int? count,
    double? stepX,
    double? stepY,
    double? stepZ,
    int? columns,
    int? floors,
    int? rows,
    double? spacingX,
    double? spacingY,
    double? spacingZ,
    int? around,
    double? radius,
    double? sweep,
    bool? faceCentre,
  }) => Array3DSpec(
    mode: mode ?? this.mode,
    count: count ?? this.count,
    stepX: stepX ?? this.stepX,
    stepY: stepY ?? this.stepY,
    stepZ: stepZ ?? this.stepZ,
    columns: columns ?? this.columns,
    floors: floors ?? this.floors,
    rows: rows ?? this.rows,
    spacingX: spacingX ?? this.spacingX,
    spacingY: spacingY ?? this.spacingY,
    spacingZ: spacingZ ?? this.spacingZ,
    around: around ?? this.around,
    radius: radius ?? this.radius,
    sweep: sweep ?? this.sweep,
    faceCentre: faceCentre ?? this.faceCentre,
  );
}
