import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../look/editor_theme.dart';
import '../../look/inspector_field.dart';
import '../../look/kit/buttons.dart';
import 'number_field_rows.dart';

// ── Vertex list row (Polygon / RoundedPolygon / Chain) ────────────────────────

/// A list of points — a polygon's or a chain's vertices — as an x and a y
/// box per point, a remove button on each, and "Add point" under them.
class OffsetListFieldRow extends StatefulWidget {
  const OffsetListFieldRow({
    super.key,
    required this.label,
    required this.points,
    required this.onChanged,
    this.minPoints = 0,
  });

  /// The field's name, in the label column.
  final String label;

  /// The points shown, in order. A list with different points replaces
  /// what the row shows.
  final List<Offset> points;

  /// Called with the whole list after every change: a coordinate kept, a
  /// point removed or added. A new point goes to the right of the last, by
  /// a quarter of the outline's size (20 with fewer than two points).
  final ValueChanged<List<Offset>> onChanged;

  /// The fewest points the list may be left with — 3 for a polygon, 2 for
  /// a chain: at that many the remove buttons are off.
  final int minPoints;

  @override
  State<OffsetListFieldRow> createState() => _OffsetListFieldRowState();
}

class _OffsetListFieldRowState extends State<OffsetListFieldRow> {
  late List<Offset> _points;

  @override
  void initState() {
    super.initState();
    _points = List<Offset>.from(widget.points);
  }

  @override
  void didUpdateWidget(OffsetListFieldRow old) {
    super.didUpdateWidget(old);
    if (!_sameOffsets(old.points, widget.points)) {
      _points = List<Offset>.from(widget.points);
    }
  }

  static bool _sameOffsets(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _commit() => widget.onChanged(List<Offset>.from(_points));

  void _setX(int index, double x) {
    setState(() => _points[index] = Offset(x, _points[index].dy));
    _commit();
  }

  void _setY(int index, double y) {
    setState(() => _points[index] = Offset(_points[index].dx, y));
    _commit();
  }

  void _remove(int index) {
    if (_points.length <= widget.minPoints) return;
    setState(() => _points.removeAt(index));
    _commit();
  }

  // A step in proportion to the outline: a 3-D polygon a metre across is
  // not stretched 20 metres by its next point.
  void _add() {
    final last = _points.isNotEmpty ? _points.last : Offset.zero;
    var step = 20.0;
    if (_points.length >= 2) {
      final xs = _points.map((p) => p.dx), ys = _points.map((p) => p.dy);
      final size = math.max(
        xs.reduce(math.max) - xs.reduce(math.min),
        ys.reduce(math.max) - ys.reduce(math.min),
      );
      if (size > 0) step = size / 4;
    }
    setState(() => _points.add(last + Offset(step, 0)));
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: InspectorField.labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.label, style: InspectorField.labelStyle),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _points.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: MiniNumberField(
                          value: _points[i].dx,
                          onSubmitted: (v) => _setX(i, v),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: MiniNumberField(
                          value: _points[i].dy,
                          onSubmitted: (v) => _setY(i, v),
                        ),
                      ),
                      const SizedBox(width: 4),
                      EditorIconButton(
                        icon: Icons.close,
                        tooltip: _points.length > widget.minPoints
                            ? 'Remove this point'
                            : 'At least ${widget.minPoints} points',
                        onTap: _points.length > widget.minPoints
                            ? () => _remove(i)
                            : null,
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: _add,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: EditorTheme.primaryMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add point',
                        style: TextStyle(
                          color: EditorTheme.primaryMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
