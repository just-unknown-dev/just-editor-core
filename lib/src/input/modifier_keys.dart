import 'package:flutter/services.dart';

import 'editor_keys.dart';

/// The modifier keys held during a pointer gesture or a key press.
class ModifierKeys {
  const ModifierKeys({
    this.shift = false,
    this.alt = false,
    this.control = false,
    this.other = false,
  });

  /// Reads the live keyboard state, the way the platform means it:
  /// [control] is Cmd on macOS (see [EditorKeys]).
  ///
  /// Falls back to no modifiers when no Flutter binding exists, so a headless
  /// caller degrades to plain unmodified gestures rather than throwing.
  factory ModifierKeys.fromHardwareKeyboard() {
    try {
      final keys = HardwareKeyboard.instance;
      final mac = EditorKeys.isMac;
      return ModifierKeys(
        shift: keys.isShiftPressed,
        alt: keys.isAltPressed,
        control: mac ? keys.isMetaPressed : keys.isControlPressed,
        other: mac ? keys.isControlPressed : keys.isMetaPressed,
      );
    } catch (_) {
      return const ModifierKeys();
    }
  }

  /// Shift: constrains a drag to its dominant axis.
  final bool shift;

  /// Alt (Option on macOS). An Alt+drag in the designer's select tool moves
  /// a copy of the selection, and while resizing grows both sides about the
  /// centre; in a 3-D view an Alt+drag orbits the camera.
  final bool alt;

  /// The primary modifier: Ctrl, and Cmd on macOS. At the start of a
  /// gesture it adds to the selection rather than replacing it, during a
  /// drag it suspends snapping, and it makes the editor's shortcuts —
  /// Ctrl+Z, Cmd+Z on a Mac. On macOS Ctrl does not count as it: that is
  /// [other].
  final bool control;

  /// The modifier the editor binds nothing to: Ctrl on macOS, the Windows or
  /// Super key elsewhere. No key binding matches while it is held, so the
  /// key is not taken for a bare letter's command.
  final bool other;
}
