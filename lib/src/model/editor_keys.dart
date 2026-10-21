import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The keyboard as the platform has it, in one place: which modifier the
/// editor's shortcuts are made with, what it is called, and which keys
/// delete.
///
/// The *primary* modifier is Cmd on macOS and Ctrl everywhere else. Every
/// shortcut, every "add to the selection" click and every chord shown in a
/// tooltip goes through here, so a Mac gets Cmd+Z, Cmd+click and `Cmd+S`
/// in its tooltips without each panel asking which platform it is on.
///
/// On macOS Ctrl is *not* an alias for Cmd: Ctrl+click is the Mac's
/// context click, and Ctrl+letter moves the caret in its text fields. The
/// platform is [defaultTargetPlatform], so a test picks one with
/// `debugDefaultTargetPlatformOverride`.
abstract final class EditorKeys {
  /// Whether the editor follows the Mac's conventions: Cmd for shortcuts,
  /// and Backspace — the key a Mac keyboard labels "delete" — deletes.
  static bool get isMac => defaultTargetPlatform == TargetPlatform.macOS;

  /// What the primary modifier is called in a chord: `Cmd` on macOS,
  /// `Ctrl` elsewhere.
  static String get primaryLabel => isMac ? 'Cmd' : 'Ctrl';

  /// [rest] after the primary modifier, as a tooltip writes a chord:
  /// `withPrimary('Z')` is `Ctrl+Z`, and `Cmd+Z` on macOS.
  static String withPrimary(String rest) => '$primaryLabel+$rest';

  /// Whether the primary modifier is held now: Cmd on macOS, Ctrl
  /// elsewhere. False when no Flutter binding exists.
  static bool get primaryPressed =>
      _read((keys) => isMac ? keys.isMetaPressed : keys.isControlPressed);

  /// Whether the modifier the editor binds nothing to is held now: Ctrl on
  /// macOS, the Windows or Super key elsewhere. While it is down no
  /// shortcut runs, so Ctrl+Z on a Mac is not taken for a plain Z.
  static bool get otherPressed =>
      _read((keys) => isMac ? keys.isControlPressed : keys.isMetaPressed);

  /// Whether [key] is the primary modifier itself, either side.
  static bool isPrimaryKey(LogicalKeyboardKey key) => isMac
      ? key == LogicalKeyboardKey.meta ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight
      : key == LogicalKeyboardKey.control ||
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight;

  /// Whether [key] deletes: Delete everywhere, and Backspace on macOS, where
  /// the keyboard's delete key sends it. A text field with the focus keeps
  /// both for itself; this is for what has the selection.
  static bool isDeleteKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.delete ||
      (isMac && key == LogicalKeyboardKey.backspace);

  /// The keys [isDeleteKey] accepts, for a panel that claims them.
  static Set<LogicalKeyboardKey> get deleteKeys => {
    LogicalKeyboardKey.delete,
    if (isMac) LogicalKeyboardKey.backspace,
  };

  /// A [SingleActivator] for [key] with the primary modifier: `meta` on
  /// macOS, `control` elsewhere — for a `Shortcuts` or `CallbackShortcuts`
  /// map that should follow the platform.
  static SingleActivator primary(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) => SingleActivator(
    key,
    control: !isMac,
    meta: isMac,
    shift: shift,
    alt: alt,
  );

  static bool _read(bool Function(HardwareKeyboard keys) read) {
    try {
      return read(HardwareKeyboard.instance);
    } catch (_) {
      return false;
    }
  }
}
