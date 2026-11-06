import 'package:flutter/material.dart';

import '../../look/editor_theme.dart';
import '../../look/inspector_field.dart';
import '../../look/widgets/editor_dropdown.dart';

/// An on/off field: a checkbox and "On" or "Off" in a box; a tap flips it.
class BoolFieldRow extends StatelessWidget {
  const BoolFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// The field's name, in the label column and for a screen reader.
  final String label;

  /// Whether the field is on.
  final bool value;

  /// Called with the flipped value on a tap.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: InspectorField.labelWidth,
          child: Text(label, style: InspectorField.labelStyle),
        ),
        Expanded(
          child: Semantics(
            label: label,
            checked: value,
            child: InkWell(
              onTap: () => onChanged(!value),
              borderRadius: BorderRadius.circular(InspectorField.radius),
              child: Container(
                height: InspectorField.height,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: InspectorField.boxDecoration(),
                child: Row(
                  children: [
                    Icon(
                      value
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 14,
                      color: value
                          ? EditorTheme.primaryMutedLight
                          : EditorTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      value ? 'On' : 'Off',
                      style: InspectorField.valueStyle.copyWith(
                        color: value
                            ? EditorTheme.textPrimary
                            : EditorTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One text value out of a list, as an [EditorDropdown] whose entries read
/// as the values themselves.
class DropdownFieldRow extends StatelessWidget {
  const DropdownFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchable = false,
    this.allowCustom = false,
  });

  /// The field's name, in the label column.
  final String label;

  /// The chosen value; it is ticked in the list. A value that is not among
  /// [options] shows an empty field.
  final String value;

  /// The values to choose from, each its own label.
  final List<String> options;

  /// Called with the value picked from the list, or typed with
  /// [allowCustom].
  final ValueChanged<String> onChanged;

  /// A filter box at the top of the list, for a long one.
  final bool searchable;

  /// With [searchable]: what was typed may be chosen even if it is not
  /// listed — an entity that does not exist yet.
  final bool allowCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: InspectorField.labelWidth,
          child: Text(label, style: InspectorField.labelStyle),
        ),
        Expanded(
          child: EditorDropdown<String>(
            value: value,
            options: [
              for (final option in options)
                EditorDropdownOption(value: option, label: option),
            ],
            searchable: searchable,
            customValue: allowCustom ? (typed) => typed : null,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
