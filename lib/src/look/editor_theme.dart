import 'package:flutter/material.dart';

import 'editor_theme_data.dart';
import 'theme_controller.dart';

// ── Theme ────────────────────────────────────────────────────────────────────

/// The editor's colours by name, each read from the palette the overlay
/// last applied ([current]).
///
/// The overlay rebuilds what it draws when the palette changes, so a widget
/// can read `EditorTheme.panelBg` in its build. [of] reads the palette
/// through an [EditorThemeScope] instead, for a widget that has to rebuild
/// by itself when the theme changes.
abstract final class EditorTheme {
  /// The palette in force at [context], read through it so a widget under
  /// an [EditorThemeScope] is built again when the theme changes: the
  /// scope's theme as the editor shows it — [current], high-contrast or
  /// colour-blind-safe colours included, once [apply] was given it — or,
  /// outside any scope (a dialog on the app's own navigator), [current].
  static EditorThemeData of(BuildContext context) {
    final theme = context
        .dependOnInheritedWidgetOfExactType<EditorThemeScope>()
        ?.notifier
        ?.value;
    if (theme == null || identical(theme, _appliedFrom)) return _current;
    return theme;
  }

  /// The palette every colour below reads: [EditorThemeData.classic] until
  /// the overlay applies the accent the user picked, or a module's preset.
  static EditorThemeData get current => _current;
  static EditorThemeData _current = EditorThemeData.classic;

  /// Makes [data] the palette. The overlay does this when the theme changes,
  /// and rebuilds everything it draws so what reads a colour here sees the
  /// new one; anything else built after this reads it too.
  ///
  /// [from] is the theme [data] was made from — the preset picked, before
  /// the accessibility settings adjusted it — so that [of] hands out [data]
  /// wherever a scope holds that theme.
  static void apply(EditorThemeData data, {EditorThemeData? from}) {
    _current = data;
    _appliedFrom = from ?? data;
  }

  static EditorThemeData? _appliedFrom;

  /// The accent: what is picked, switched on, or wants to be seen.
  static Color get accent => _current.primary;

  // ── Accent ─────────────────────────────────────────────────────────────────

  /// The accent: [EditorThemeData.primary].
  static Color get primary => _current.primary;

  /// The accent brighter: a secondary button's label, a highlight.
  static Color get primaryBright => _current.primaryBright;

  /// The accent darker: a primary button's fill, a focused field's outline.
  static Color get primaryActive => _current.primaryActive;

  /// A quiet shade of the accent, for marks that should not stand out.
  static Color get primaryMuted => _current.primaryMuted;

  /// A quiet shade of the accent, lighter than [primaryMuted].
  static Color get primaryMutedLight => _current.primaryMutedLight;

  // ── Selection / hover backgrounds ──────────────────────────────────────────

  /// Behind the row or item that is selected.
  static Color get selectionBg => _current.selectionBg;

  /// Behind the row something dragged would drop onto.
  static Color get dragOverBg => _current.dragOverBg;

  /// Behind the rows of a selection of more than one, beside the main one.
  static Color get multiSelectBg => _current.multiSelectBg;

  /// Behind what is under the pointer.
  static Color get hoverBg => _current.hoverBg;

  // ── Surfaces ───────────────────────────────────────────────────────────────

  /// Behind the panels and workspaces: the darkest of the main surfaces.
  static Color get panelBg => _current.panelBg;

  /// Cards and bars that sit on a panel, a message's card.
  static Color get surfaceBg => _current.surfaceBg;

  /// Dialogs and the inspector's cards.
  static Color get dialogBg => _current.dialogBg;

  /// Inside a text or number field.
  static Color get inputBg => _current.inputBg;

  /// Menus and drop-down lists.
  static Color get menuBg => _current.menuBg;

  /// Something raised over a panel: a tooltip, a row being dragged.
  static Color get panelRaised => _current.panelRaised;

  /// Darker than [panelBg]: what sits sunk into a panel, a minimap's
  /// backing.
  static Color get surfaceDark => _current.surfaceDark;

  /// Darker than [surfaceDark]: the kit's field fill, a dock's strip.
  static Color get surfaceDarker => _current.surfaceDarker;

  /// The darkest surface: behind the start card and the scene loader.
  static Color get surfaceDarkest => _current.surfaceDarkest;

  // ── Borders / dividers ─────────────────────────────────────────────────────

  /// The faint line between regions.
  static Color get border => _current.border;

  /// A line that has to be seen: round a field, a dialog's panels.
  static Color get borderStrong => _current.borderStrong;

  // ── Button / badge backgrounds ─────────────────────────────────────────────

  /// A secondary button's fill.
  static Color get buttonBg => _current.buttonBg;

  /// A floating bar's or badge's fill over the level: the toolbars.
  static Color get statusBadgeBg => _current.statusBadgeBg;

  // ── Text ───────────────────────────────────────────────────────────────────

  /// Main text: names, values, titles.
  static Color get textPrimary => _current.textPrimary;

  /// Text that is read second: a message, a label beside a value.
  static Color get textSecondary => _current.textSecondary;

  /// Hints, placeholders, captions: text that stays in the background.
  static Color get textMuted => _current.textMuted;

  /// Text on the accent: a primary button's label, a selected row's name.
  static Color get textBright => _current.textBright;

  // ── Semantic ───────────────────────────────────────────────────────────────

  /// What went wrong: errors, a danger button.
  static Color get error => _current.error;

  /// A lighter [error], for error text on a dark surface.
  static Color get errorLight => _current.errorLight;

  /// What may go wrong: warnings.
  static Color get warning => _current.warning;

  /// What went right: a task done, a check passed.
  static Color get success => _current.success;

  /// What is merely said: information messages.
  static Color get info => _current.info;
}
