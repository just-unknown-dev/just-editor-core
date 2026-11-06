import 'package:flutter/material.dart';
import 'package:just_colours/just_colours.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../../look/editor_theme.dart';
import '../../look/inspector_field.dart';
import '../color_picking.dart';
import '../shape_paint_selection.dart';

// ── Row widgets ───────────────────────────────────────────────────────────────

/// A colour field: a swatch and its hex code (or "Gradient") in a box that
/// opens the editor's colour picker when tapped. With [supportsGradient] the
/// picker offers gradients, and a tint over them, as well as a solid colour.
class ColorFieldRow extends StatelessWidget {
  const ColorFieldRow({
    super.key,
    required this.label,
    required this.paintStyle,
    required this.onChanged,
    this.supportsGradient = false,
    this.inherited = false,
    this.inheritedFrom = '',
    this.onClear,
    this.onPreview,
    this.onPreviewEnd,
  });

  /// The field's name: in the label column, and as the picker's title.
  final String label;

  /// The colour or gradient shown. Its blend mode is kept on what the
  /// picker returns.
  final jge.ShapePaintStyle paintStyle;

  /// Called with the new paint when the picker closes on a different one;
  /// not called when it closes on what it opened with.
  final ValueChanged<jge.ShapePaintStyle> onChanged;

  /// Whether the picker offers gradients, and a tint over them, besides a
  /// solid colour. Off by default.
  final bool supportsGradient;

  /// Whether this colour is not the field's own but the one it falls back
  /// to. The swatch still shows what will be drawn; the value beside it is
  /// muted, because a colour nobody chose here must not read as one
  /// somebody did.
  final bool inherited;

  /// What it falls back to, for the note beside it: a theme role, or
  /// "nothing" where an unset colour means no colour at all.
  final String inheritedFrom;

  /// Puts the colour back to whatever it inherits. Null where the field
  /// must always have one.
  final VoidCallback? onClear;

  /// Shows a colour in the scene while the picker is open, unrecorded.
  /// Without it the scene changes only when the picker closes.
  final ValueChanged<jge.ShapePaintStyle>? onPreview;

  /// Puts back what [onPreview] replaced; called as the picker closes,
  /// before [onChanged] records the colour kept.
  final VoidCallback? onPreviewEnd;

  Future<void> _pick(BuildContext context) async {
    final mode = supportsGradient
        ? ColorPickerMode.both
        : ColorPickerMode.colorOnly;
    final initial = ColorPickerPanel.normalize(
      shapePaintStyleToSelection(paintStyle),
      mode,
    );
    jge.ShapePaintStyle styleOf(ColorSelection s) =>
        selectionToShapePaintStyle(s, blendMode: paintStyle.blendMode);
    final preview = onPreview;
    final picked = await showEditorColorPicker(
      context,
      initial: initial,
      mode: mode,
      title: label,
      showTint: supportsGradient,
      onPreview: preview == null ? null : (s) => preview(styleOf(s)),
    );
    onPreviewEnd?.call();
    // Opened and closed without a change is no edit — and must not turn a
    // colour the field inherits into one set here.
    if (picked != null && picked != initial) onChanged(styleOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final hasGradient = supportsGradient && paintStyle.gradient != null;
    final gradColors = paintStyle.gradient?.colors ?? [];
    final hex =
        '#${paintStyle.color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return Row(
      children: [
        SizedBox(
          width: InspectorField.labelWidth,
          child: Text(label, style: InspectorField.labelStyle),
        ),
        Expanded(
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: InspectorField.height,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: EditorTheme.inputBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorTheme.border),
              ),
              child: Row(
                children: [
                  // Swatch: gradient preview or solid colour
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: hasGradient ? null : paintStyle.color,
                      gradient: hasGradient && gradColors.length >= 2
                          ? LinearGradient(colors: gradColors.take(2).toList())
                          : null,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // One stretch for the words, so the picker icon is always
                  // at the box's end: a text and a spacer each took a share
                  // of the room, and the icon moved with every value.
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            hasGradient ? 'Gradient' : hex,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: inherited
                                  ? EditorTheme.textMuted
                                  : EditorTheme.textPrimary,
                              fontSize: 11,
                              fontStyle: inherited
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (inherited && inheritedFrom.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              inheritedFrom,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: EditorTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.colorize_rounded,
                    size: 13,
                    color: EditorTheme.primaryMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Only where there is something to put back: a row that always
        // offers to clear reads as though something is always set.
        if (!inherited && onClear != null)
          Tooltip(
            message: inheritedFrom.isEmpty ? 'Clear' : 'Back to $inheritedFrom',
            child: IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.settings_backup_restore_rounded),
              iconSize: 14,
              color: EditorTheme.textMuted,
              splashRadius: 12,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
          ),
      ],
    );
  }
}

/// A bare colour swatch that opens the colour dialog: the same box, no
/// label column.
class MiniColorField extends StatelessWidget {
  const MiniColorField({
    super.key,
    required this.color,
    required this.onChanged,
    this.showHex = true,
    this.inherited = false,
    this.title,
    this.onPreview,
    this.onPreviewEnd,
  });

  /// The colour in the swatch, and the picker's starting colour.
  final Color color;

  /// Called with the colour picked when the picker closes on a different
  /// one.
  final ValueChanged<Color> onChanged;

  /// What the colour is for, shown at the top of the picker.
  final String? title;

  /// Shows a colour while the picker is open, unrecorded; see
  /// [ColorFieldRow.onPreview].
  final ValueChanged<Color>? onPreview;

  /// Puts back what [onPreview] replaced, before [onChanged] records.
  final VoidCallback? onPreviewEnd;

  /// Whether the value is written beside the swatch. Off where the row is
  /// tight and the swatch says enough.
  final bool showHex;

  /// Whether the colour comes from somewhere else — a theme role. The
  /// swatch is still the colour that will be drawn; the text beside it is
  /// muted to say nobody chose it here.
  final bool inherited;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final preview = onPreview;
      final picked = await showEditorColorPicker(
        context,
        initial: ColorSelection(color: color),
        mode: ColorPickerMode.colorOnly,
        title: title,
        onPreview: preview == null ? null : (s) => preview(s.color),
      );
      onPreviewEnd?.call();
      if (picked != null && picked.color.toARGB32() != color.toARGB32()) {
        onChanged(picked.color);
      }
    },
    borderRadius: BorderRadius.circular(InspectorField.radius),
    child: Container(
      height: InspectorField.height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: InspectorField.boxDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
          ),
          if (showHex) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                style: inherited
                    ? InspectorField.valueStyle.copyWith(
                        color: EditorTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      )
                    : InspectorField.valueStyle,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
