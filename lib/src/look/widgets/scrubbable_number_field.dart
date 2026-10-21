import '../../inspector/field_style.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../editor_constants.dart';
import '../kit/fields.dart' show PendingFieldEdits, isEscapeDown;

/// Drag-to-scrub configuration for numeric inspector fields: how far a drag
/// moves the value, how it is written, and the limits it is kept within.
class NumberScrubConfig {
  const NumberScrubConfig({
    this.step = 1.0,
    this.pixelsPerStep = 12.0,
    this.fractionDigits = 2,
    this.min,
    this.max,
    this.integer = false,
    this.suffix,
  });

  /// What one step of a drag adds or takes off: the value moves by this for
  /// every [pixelsPerStep] dragged. 1 by default.
  final double step;

  /// Horizontal drag distance per [step], in logical pixels; 12 by default.
  final double pixelsPerStep;

  /// Decimal places the value is written with, 2 by default; ignored when
  /// [integer].
  final int fractionDigits;

  /// The lowest value a drag or a typed number gives; null for no lower
  /// limit.
  final double? min;

  /// The highest value a drag or a typed number gives; null for no upper
  /// limit.
  final double? max;

  /// Whether the value is whole: a drag moves it in whole numbers and it is
  /// written with no decimals. Off by default.
  final bool integer;

  /// The unit shown after the value — `px`, `/s` — or none.
  final String? suffix;
}

/// A number box whose label is its drag handle: drag the label sideways to
/// scrub the value by the config's step, or type a number and keep it with
/// Enter, Tab or a click elsewhere. Esc, with a change typed, puts back what
/// was there; text that is not a finite number is refused the same way.
class ScrubbableNumberField extends StatefulWidget {
  const ScrubbableNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onCommit,
    required this.config,
    this.labelWidth = 52,
    this.labelInside = false,
    this.labelColor,
  });

  /// The name beside the box (inside it with [labelInside]); dragging it
  /// scrubs the value.
  final String label;

  /// Holds the value as text, owned by the caller. The field writes the
  /// scrubbed or clamped value here before calling [onCommit], which reads
  /// it back.
  final TextEditingController controller;

  /// The text field's focus, owned by the caller. Leaving it keeps what was
  /// typed.
  final FocusNode focusNode;

  /// Called when a value is kept: each drag step that changes the text, and
  /// a typed change kept by Enter, by leaving the field, or by a command
  /// such as Save that runs while it is typed in. The new value is in
  /// [controller].
  final VoidCallback onCommit;

  /// Step, drag speed, digits, limits and unit.
  final NumberScrubConfig config;

  /// Width of the label column in logical pixels when the label is not
  /// inside the box; 52 by default.
  final double labelWidth;

  /// Draw the label inside the box, before the value, instead of in a
  /// column of its own. What an axis cell does, so that every box on every
  /// row starts at the same place.
  final bool labelInside;

  /// The label's colour at rest — an axis letter's red, green or blue.
  /// Null is the usual muted text.
  final Color? labelColor;

  @override
  State<ScrubbableNumberField> createState() => _ScrubbableNumberFieldState();
}

class _ScrubbableNumberFieldState extends State<ScrubbableNumberField> {
  bool _isHovering = false;
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartValue = 0;

  /// The text when the field took the keyboard, or when it last kept a
  /// value: what is not a change, and what Esc or a typo puts back.
  String? _kept;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant ScrubbableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    PendingFieldEdits.leave(_keep);
    super.dispose();
  }

  /// Taking the keyboard remembers what is there; leaving it — Tab, a click
  /// anywhere else — keeps what was typed, as Enter does, so a value typed
  /// and left reaches the component.
  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      _kept = widget.controller.text;
      PendingFieldEdits.join(_keep);
    } else {
      PendingFieldEdits.leave(_keep);
      _keep();
    }
  }

  /// Keeps what was typed, once per change: on Enter, on leaving the field,
  /// and before a command that runs while it is typed in (Save). Text that
  /// is not a number — or is one no component can hold and no scene can
  /// save: `Infinity`, `NaN`, `1e999` — puts back what was there rather
  /// than writing it.
  void _keep() {
    if (!mounted) return;
    final text = widget.controller.text;
    if (text == _kept) return;
    if (_number(text) == null) {
      if (_kept != null) widget.controller.text = _kept!;
      return;
    }
    _commit();
    _kept = widget.controller.text;
  }

  /// Esc, with a change typed: what was there, and out of the field. With
  /// nothing typed Esc is left to whoever wants it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final kept = _kept;
    if (!isEscapeDown(event) || kept == null) return KeyEventResult.ignored;
    if (widget.controller.text == kept) return KeyEventResult.ignored;
    widget.controller.text = kept;
    widget.focusNode.unfocus();
    return KeyEventResult.handled;
  }

  /// [text] as a number, or null when it is none — or not a finite one,
  /// which `double.tryParse` reads `Infinity`, `NaN` and `1e999` as.
  static double? _number(String text) {
    final value = double.tryParse(text.trim());
    return value != null && value.isFinite ? value : null;
  }

  double _parseCurrentValue() => _number(widget.controller.text) ?? 0.0;

  double _clampValue(double value) {
    var result = value;
    if (widget.config.min != null) {
      result = math.max(result, widget.config.min!);
    }
    if (widget.config.max != null) {
      result = math.min(result, widget.config.max!);
    }
    return result;
  }

  String _formatValue(double value) {
    if (widget.config.integer) {
      return value.round().toString();
    }
    return value.toStringAsFixed(widget.config.fractionDigits);
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartX = details.globalPosition.dx;
      _dragStartValue = _parseCurrentValue();
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final deltaX = details.globalPosition.dx - _dragStartX;
    final ratio = deltaX / widget.config.pixelsPerStep;
    var nextValue = _dragStartValue + (ratio * widget.config.step);
    if (widget.config.integer) {
      nextValue = nextValue.roundToDouble();
    }
    nextValue = _clampValue(nextValue);
    final text = _formatValue(nextValue);
    if (widget.controller.text == text) return;

    widget.controller.text = text;
    widget.onCommit();
    // Scrubbed is kept: leaving the field after does not keep it again.
    if (widget.focusNode.hasFocus) _kept = text;
    setState(() {});
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
    });
  }

  /// Clamps what was typed to the config's [NumberScrubConfig.min] and
  /// [NumberScrubConfig.max], and writes it as the config says, before
  /// calling `widget.onCommit` — so a typed value stays in range as a
  /// scrubbed one does ([_onDragUpdate] clamps too).
  void _commit() {
    final clamped = _clampValue(_parseCurrentValue());
    final text = _formatValue(clamped);
    if (widget.controller.text != text) {
      widget.controller.text = text;
    }
    widget.onCommit();
  }

  /// The label, which is also the handle a value is scrubbed by.
  Widget _handle({required bool highlight, EdgeInsets? padding}) => MouseRegion(
    cursor: SystemMouseCursors.resizeLeftRight,
    onEnter: (_) => setState(() => _isHovering = true),
    onExit: (_) => setState(() => _isHovering = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () =>
          _onDragEnd(DragEndDetails(primaryVelocity: 0)),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Text(
          widget.label,
          style: TextStyle(
            color: highlight
                ? EditorTheme.primaryMutedLight
                : widget.labelColor ?? EditorTheme.textMuted,
            fontSize: 10,
            fontWeight: widget.labelColor == null
                ? FontWeight.w500
                : FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final highlight = _isDragging || _isHovering;
    if (widget.labelInside) return _field(highlight);

    return Row(
      children: <Widget>[
        SizedBox(
          width: widget.labelWidth,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: () =>
                  _onDragEnd(DragEndDetails(primaryVelocity: 0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: highlight
                          ? EditorTheme.primaryMutedLight
                          : widget.labelColor ?? EditorTheme.textMuted,
                      fontSize: 10,
                      fontWeight: widget.labelColor == null
                          ? FontWeight.w500
                          : FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _field(highlight)),
      ],
    );
  }

  Widget _field(bool highlight) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _onKey,
    child: TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: InspectorField.valueStyle,
      decoration: InspectorField.decoration(
        prefix: widget.labelInside
            ? _handle(
                highlight: highlight,
                padding: const EdgeInsets.only(left: 8, right: 6),
              )
            : null,
        suffix: widget.config.suffix,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      // Enter keeps the value and the field keeps the keyboard. Once: this
      // and onSubmitted both used to run, writing every Enter twice.
      onEditingComplete: _keep,
    ),
  );
}
