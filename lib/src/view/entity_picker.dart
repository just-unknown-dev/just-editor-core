import 'package:flutter/painting.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'editor_view.dart';

/// Finds what is under the pointer, seen through an [EditorView].
///
/// The 2-D editor picks by each entity's box on the world plane
/// (`PlanarEntityPicker`); a 3-D view will pick by casting the view's ray
/// ([EditorView.screenToRay]) against bounds in space — another picker
/// behind the same two calls.
abstract interface class EntityPicker {
  /// The topmost of [candidates] under the pixel [screen], or null.
  jge.Entity? pickAt(
    EditorView view,
    Offset screen,
    List<jge.Entity> candidates,
  );

  /// Every one of [candidates] inside the pixel rectangle [screenRect] — a
  /// marquee.
  List<jge.Entity> pickInRect(
    EditorView view,
    Rect screenRect,
    Iterable<jge.Entity> candidates,
  );
}
