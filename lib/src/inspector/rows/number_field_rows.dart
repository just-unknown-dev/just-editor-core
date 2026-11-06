import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../look/editor_theme.dart';
import '../../look/inspector_field.dart';
import '../../look/kit/controls.dart' show EditorSlider;
import '../../look/kit/fields.dart';
import '../../look/widgets/scrubbable_number_field.dart';
import 'color_field_row.dart';
import 'parse_typed_number.dart';
import 'text_field_rows.dart';

/// One number with its label as a drag handle (a [ScrubbableNumberField]):
/// drag the label sideways to change it, or type a value and keep it with
/// Enter, Tab or a click elsewhere.
class ScrubFieldRow extends StatefulWidget {
  const ScrubFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.scrubConfig,
    required this.onChanged,
  });

  /// The field's name, in the label column; dragging it scrubs the value.
  final String label;

  /// The number shown. A new one replaces the text unless the field is
  /// being typed in.
  final double value;

  /// Step, drag speed, digits and limits; a typed value is kept within the
  /// limits.
  final NumberScrubConfig scrubConfig;

  /// Called with each value kept: every step of a drag, and a typed value
  /// once it is kept.
  final ValueChanged<double> onChanged;

  @override
  State<ScrubFieldRow> createState() => _ScrubFieldRowState();
}

class _ScrubFieldRowState extends State<ScrubFieldRow> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(ScrubFieldRow old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != old.value) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (widget.scrubConfig.integer) return v.round().toString();
    return v.toStringAsFixed(widget.scrubConfig.fractionDigits);
  }

  void _commit() {
    final v = parseTypedNumber(_ctrl.text, config: widget.scrubConfig);
    if (v != null) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return ScrubbableNumberField(
      label: widget.label,
      controller: _ctrl,
      focusNode: _focus,
      onCommit: _commit,
      config: widget.scrubConfig,
      labelWidth: InspectorField.labelWidth,
    );
  }
}

/// A number between two limits as a slider, with the value beside it to
/// type: for a setting whose range matters more than its digits.
class SliderFieldRow extends StatelessWidget {
  const SliderFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 0.05,
    this.decimals = 2,
    this.unit = '',
  });

  /// The field's name, in the label column.
  final String label;

  /// The value shown; clamped to [min]..[max] for the slider.
  final double value;

  /// The slider's left end, the lowest value it gives.
  final double min;

  /// The slider's right end, the highest value it gives.
  final double max;

  /// What the value moves in, 0.05 by default; 0 or less moves it freely.
  final double step;

  /// Decimal places in the number beside the slider, 2 by default.
  final int decimals;

  /// Written after the number (`%`, `px`); none when empty.
  final String unit;

  /// Every value the drag passes through, and the one it ends on. (An
  /// inspector edit merges consecutive writes, so a drag is one undo.)
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: InspectorField.labelWidth,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: InspectorField.labelStyle,
        ),
      ),
      Expanded(
        child: SizedBox(
          height: InspectorField.height,
          child: EditorSlider(
            value: value,
            min: min,
            max: max,
            step: step,
            decimals: decimals,
            unit: unit,
            accent: EditorTheme.primaryMutedLight,
            onChanged: (v) {
              if (v != value) onChanged(v);
            },
            onChangeEnd: (v) {
              if (v != value) onChanged(v);
            },
          ),
        ),
      ),
    ],
  );
}

/// A vector on one row: the field's label, then a scrubbable cell per axis —
/// `Position  X [ 0.0 ]  Y [ 0.0 ]`. Each cell's letter is its drag handle,
/// in the axis colour the gizmos use.
class AxesFieldRow extends StatefulWidget {
  const AxesFieldRow({
    super.key,
    required this.label,
    required this.axes,
    required this.values,
    required this.scrubConfig,
    required this.onChanged,
    this.scrubConfigs,
    this.readOnly = false,
  }) : assert(axes.length == values.length),
       assert(scrubConfigs == null || scrubConfigs.length == values.length);

  /// The field's name: left of the cells, or on a line above them in a
  /// narrow panel.
  final String label;

  /// The axis letters, one per value: `['X', 'Y']`.
  final List<String> axes;

  /// The numbers, one per axis in the order of [axes]. A new value
  /// replaces a cell's text unless that cell is being typed in.
  final List<double> values;

  /// Step, drag speed, digits and limits of every cell, unless
  /// [scrubConfigs] gives each its own.
  final NumberScrubConfig scrubConfig;

  /// One per cell, where they differ — a row of separate fields, each with
  /// its own limits. Null gives every cell [scrubConfig].
  final List<NumberScrubConfig>? scrubConfigs;

  /// Draws each value as plain text beside its letter, with nothing to
  /// drag or type. Off by default.
  final bool readOnly;

  /// Every value, with the edited one replaced.
  final ValueChanged<List<double>> onChanged;

  /// Red, green, blue, then amber for a fourth.
  static const List<Color> axisColors = [
    Color(0xFFE5737B),
    Color(0xFF7DD68A),
    Color(0xFF6FA8F5),
    Color(0xFFE6C36B),
  ];

  @override
  State<AxesFieldRow> createState() => _AxesFieldRowState();
}

class _AxesFieldRowState extends State<AxesFieldRow> {
  final List<TextEditingController> _ctrls = [];
  final List<FocusNode> _focus = [];

  @override
  void initState() {
    super.initState();
    _grow();
  }

  void _grow() {
    while (_ctrls.length < widget.values.length) {
      _ctrls.add(
        TextEditingController(
          text: _fmt(_ctrls.length, widget.values[_ctrls.length]),
        ),
      );
      _focus.add(FocusNode());
    }
  }

  @override
  void didUpdateWidget(AxesFieldRow old) {
    super.didUpdateWidget(old);
    _grow();
    for (var i = 0; i < widget.values.length; i++) {
      final was = i < old.values.length ? old.values[i] : null;
      if (!_focus[i].hasFocus && widget.values[i] != was) {
        _ctrls[i].text = _fmt(i, widget.values[i]);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  NumberScrubConfig _config(int i) =>
      widget.scrubConfigs?[i] ?? widget.scrubConfig;

  /// A letter's width, or room for the longest of `Min` / `Max`.
  double get _cellLabelWidth {
    final longest = widget.axes.fold(0, (n, a) => math.max(n, a.length));
    return longest <= 1 ? 12 : 6.0 * longest + 6;
  }

  String _fmt(int i, double v) {
    final config = _config(i);
    if (config.integer) return v.round().toString();
    return v.toStringAsFixed(config.fractionDigits);
  }

  void _commit(int i) {
    final v = parseTypedNumber(_ctrls[i].text, config: _config(i));
    if (v == null) return;
    widget.onChanged(List<double>.of(widget.values)..[i] = v);
  }

  Widget _cell(int i) {
    final color = AxesFieldRow.axisColors[i % AxesFieldRow.axisColors.length];
    if (widget.readOnly) {
      return Row(
        children: [
          SizedBox(
            width: _cellLabelWidth,
            child: Text(
              widget.axes[i],
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _fmt(i, widget.values[i]),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: EditorTheme.textPrimary, fontSize: 11),
            ),
          ),
        ],
      );
    }
    return Tooltip(
      message: '${widget.label} ${widget.axes[i]}',
      child: ScrubbableNumberField(
        label: widget.axes[i],
        labelInside: true,
        labelColor: color,
        controller: _ctrls[i],
        focusNode: _focus[i],
        onCommit: () => _commit(i),
        config: _config(i),
      ),
    );
  }

  /// Below this a cell cannot show `-1234.5` next to its letter.
  static const double _minCell = 62;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: EditorTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
    final cells = Row(
      children: [
        for (var i = 0; i < widget.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _cell(i)),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final n = widget.values.length;
        final fits =
            box.maxWidth - 96 - 6 * (n - 1) >=
            (_minCell - 12 + _cellLabelWidth) * n;
        // A narrow panel: the label takes its own line, the axes still
        // share one.
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 4), cells],
          );
        }
        return Row(
          children: [
            SizedBox(width: 96, child: label),
            Expanded(child: cells),
          ],
        );
      },
    );
  }
}

/// A bare number box: the inspector's field box with no label column.
/// Kept on Enter, Tab or a click elsewhere; text that is not a finite
/// number puts back the value it had.
///
/// Every `…FieldRow` in this library is a *row* — a label column and then
/// its control — so one must never be put inside another row, or the label
/// column overflows whatever it was given. Anything building a row of its
/// own reaches for the bare fields instead: this one, [MiniTextField] and
/// [MiniColorField].
class MiniNumberField extends StatelessWidget {
  const MiniNumberField({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.fractionDigits = 1,
    this.inherited = false,
  });

  /// The number shown, written with [fractionDigits] decimals.
  final double value;

  /// Called with the number kept, once per change.
  final ValueChanged<double> onSubmitted;

  /// How the number is written; 0 for a whole one.
  final int fractionDigits;

  /// Whether this is not the field's own value but the one it takes from
  /// somewhere else — a theme role, a parent. Drawn muted, so a number
  /// nobody chose here does not read as a number somebody did.
  final bool inherited;

  @override
  Widget build(BuildContext context) {
    // Kept on Enter, Tab or a click elsewhere, as every typed field is; a
    // value that is not a number puts back the one it had. Keyed by the
    // value, so a kept one shows as it is written.
    return CommitTextField(
      key: ValueKey('$value:$inherited'),
      value: value.toStringAsFixed(fractionDigits),
      accept: (text) => parseTypedNumber(text) != null,
      onCommit: (text) => onSubmitted(parseTypedNumber(text)!),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      style: TextStyle(
        color: inherited ? EditorTheme.textMuted : EditorTheme.textPrimary,
        fontSize: 11,
        fontStyle: inherited ? FontStyle.italic : FontStyle.normal,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: InspectorField.padding,
        filled: true,
        fillColor: InspectorField.fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: EditorTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: EditorTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: EditorTheme.primaryActive),
        ),
      ),
    );
  }
}
