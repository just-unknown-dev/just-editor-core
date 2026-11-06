import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_colours/just_colours.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

// ── Colour ↔ ShapePaintStyle bridge ──────────────────────────────────────────

/// [sel] as a shape's paint. A gradient's tint becomes the style's colour,
/// which the engine multiplies over the gradient by [blendMode].
jge.ShapePaintStyle selectionToShapePaintStyle(
  ColorSelection sel, {
  BlendMode blendMode = BlendMode.modulate,
}) {
  if (!sel.useGradient) {
    return jge.ShapePaintStyle(color: sel.color, blendMode: blendMode);
  }
  final cfg = sel.gradient;
  final colors = cfg.colors.isEmpty ? [sel.color] : cfg.colors;
  jge.ShapeGradient gradient;
  switch (cfg.type) {
    case GradientType.linear:
      final (begin, end) = cfg.linearEnds;
      gradient = jge.ShapeGradient.linear(
        colors: colors,
        stops: cfg.stops,
        begin: begin,
        end: end,
        tileMode: cfg.tileMode,
      );
    case GradientType.radial:
      gradient = jge.ShapeGradient.radial(
        colors: colors,
        stops: cfg.stops,
        center: cfg.center,
        radius: cfg.radius,
        tileMode: cfg.tileMode,
      );
    case GradientType.sweep:
      gradient = jge.ShapeGradient.sweep(
        colors: colors,
        stops: cfg.stops,
        center: cfg.center,
        startAngle: cfg.startAngle * math.pi / 180,
        endAngle: cfg.endAngle * math.pi / 180,
        tileMode: cfg.tileMode,
      );
  }
  return jge.ShapePaintStyle(
    color: sel.tint,
    gradient: gradient,
    blendMode: blendMode,
  );
}

/// [style] as the picker's selection. With a gradient, the style's colour
/// is the tint over it, and the solid colour to switch back to is the
/// gradient's first.
ColorSelection shapePaintStyleToSelection(jge.ShapePaintStyle style) {
  final g = style.gradient;
  if (g == null) return ColorSelection(color: style.color);
  GradientType type;
  switch (g.kind) {
    case jge.ShapeGradientKind.linear:
      type = GradientType.linear;
    case jge.ShapeGradientKind.radial:
      type = GradientType.radial;
    case jge.ShapeGradientKind.sweep:
      type = GradientType.sweep;
  }
  var angle = 0.0;
  if (type == GradientType.linear) {
    final begin = g.begin is Alignment
        ? g.begin as Alignment
        : Alignment.centerLeft;
    final end = g.end is Alignment ? g.end as Alignment : Alignment.centerRight;
    final d = math.atan2(end.y - begin.y, end.x - begin.x) * 180 / math.pi;
    angle = d < 0 ? d + 360 : d;
  }
  return ColorSelection(
    color: g.colors.isEmpty ? style.color : g.colors.first,
    useGradient: true,
    tint: style.color,
    gradient: GradientConfig(
      type: type,
      colors: g.colors,
      stops: g.stops,
      angle: angle,
      center: g.center is Alignment ? g.center as Alignment : Alignment.center,
      radius: g.radius,
      startAngle: g.startAngle * 180 / math.pi,
      endAngle: g.endAngle * 180 / math.pi,
      tileMode: g.tileMode,
    ),
  );
}
