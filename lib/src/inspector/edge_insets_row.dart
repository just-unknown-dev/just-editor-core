import 'package:flutter/material.dart';

import '../look/widgets/scrubbable_number_field.dart';
import 'field_rows.dart';

/// Space around something, as four numbers on one row.
class EdgeInsetsEditorRow extends StatelessWidget {
  const EdgeInsetsEditorRow({
    super.key,
    required this.label,
    required this.insets,
    required this.onChanged,
  });

  /// The field's name, in the label column.
  final String label;

  /// The space shown, as left, top, right and bottom cells: written without
  /// decimals, and a drag moves them by 1.
  final EdgeInsets insets;

  /// Called with all four sides, one of them changed.
  final ValueChanged<EdgeInsets> onChanged;

  @override
  Widget build(BuildContext context) => AxesFieldRow(
    label: label,
    axes: const ['L', 'T', 'R', 'B'],
    values: [insets.left, insets.top, insets.right, insets.bottom],
    scrubConfig: const NumberScrubConfig(step: 1, fractionDigits: 0),
    onChanged: (next) =>
        onChanged(EdgeInsets.fromLTRB(next[0], next[1], next[2], next[3])),
  );
}
