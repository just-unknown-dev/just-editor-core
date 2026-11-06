import 'package:flutter/painting.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'editor_view.dart';

/// Finds what is under the pointer, seen through an [EditorView].
///
/// A 3-D view picks by casting the view's ray ([EditorView.screenToRay])
/// against what is in space ([RayEntityPicker]); a picker of another kind
/// stands behind the same two calls.
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
