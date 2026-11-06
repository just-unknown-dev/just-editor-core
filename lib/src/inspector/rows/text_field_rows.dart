import 'package:flutter/material.dart';

import '../../look/editor_theme.dart';
import '../../look/inspector_field.dart';
import '../../look/kit/fields.dart';

/// A label and a value that cannot be edited: the same box as the other
/// rows, unfilled, with the value in quieter text.
class ReadonlyFieldRow extends StatelessWidget {
  const ReadonlyFieldRow({super.key, required this.label, required this.value});

  /// The field's name, in the label column.
  final String label;

  /// The text shown in the box.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: InspectorField.labelWidth,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: InspectorField.labelStyle,
          ),
        ),
        // The same box as every other row, so it sits on the same lines —
        // left unfilled and quieter, since there is nothing in it to change.
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: InspectorField.height),
            // Less the border's pixel on each side, which a box's padding
            // grows by: then one line comes out at the height of the rest.
            padding: InspectorField.padding - const EdgeInsets.all(1),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(InspectorField.radius),
              border: Border.all(color: EditorTheme.border),
            ),
            child: Text(
              value,
              style: InspectorField.valueStyle.copyWith(
                color: EditorTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A text field: a [CommitTextField] that wraps a long value onto up to four
/// lines and keeps what was typed on Enter or when the field is left.
class TextFieldRow extends StatelessWidget {
  const TextFieldRow({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSubmitted,
  });

  /// The field's name, in the label column.
  final String label;

  /// The text shown. A new one replaces it unless the field is being typed
  /// in.
  final String initialValue;

  /// Called with the text kept, once per change; not called when it is
  /// what it was.
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: InspectorField.labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label, style: InspectorField.labelStyle),
          ),
        ),
        Expanded(
          // Kept on Enter or when the field is left; an undo shows.
          child: CommitTextField(
            value: initialValue,
            style: InspectorField.valueStyle,
            maxLines: 4,
            onCommit: onSubmitted,
            decoration: InspectorField.decoration(),
          ),
        ),
      ],
    );
  }
}

/// A bare line of text: the same box, no label column. Kept on Enter, Tab or
/// a click elsewhere, as every typed field is.
class MiniTextField extends StatelessWidget {
  const MiniTextField({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.accept,
    this.hint = '',
  });

  /// The text shown.
  final String value;

  /// Called with the text kept, once per change.
  final ValueChanged<String> onSubmitted;

  /// Whether typed text can be kept; refused, the field shows [value]
  /// again. See [CommitTextField.accept].
  final bool Function(String text)? accept;

  /// Muted text shown while the box is empty; `''` (the default) shows
  /// none.
  final String hint;

  @override
  Widget build(BuildContext context) => CommitTextField(
    key: ValueKey(value),
    value: value,
    accept: accept,
    style: InspectorField.valueStyle,
    onCommit: onSubmitted,
    decoration: InspectorField.decoration().copyWith(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(
        color: EditorTheme.textMuted,
        fontSize: InspectorField.fontSize,
      ),
    ),
  );
}
