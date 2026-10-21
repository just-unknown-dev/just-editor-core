import 'package:flutter/widgets.dart';

import '../designer/designer_session.dart';

/// A palette group, with where it sorts. Prefabs name their category by
/// [label]; a category nobody declares sorts after the declared ones.
class PrefabCategory {
  const PrefabCategory({required this.label, this.order = 100});

  /// The group's heading in the palette, and what a prefab gives as its
  /// category to be in it.
  final String label;

  /// Lower sorts first; the built-in groups use 0–99.
  final int order;
}

/// A control a module adds to the designer's status bar.
class StatusBarControl {
  const StatusBarControl({
    required this.id,
    required this.build,
    this.order = 100,
  });

  /// Names the control, prefixed by its module.
  final String id;

  /// Lower sorts first; the built-ins occupy 0–99.
  final int order;

  /// Builds the control, placed after the built-in ones on the status bar,
  /// which scrolls sideways when they do not all fit.
  final Widget Function(BuildContext context, DesignerSession session) build;
}

/// A collapsible section a module adds to the designer's side panel, under
/// the built-in ones.
class SidePanelSection {
  const SidePanelSection({
    required this.id,
    required this.title,
    required this.build,
    this.order = 100,
    this.expand = false,
    this.groups,
  });

  /// Names the section, prefixed by its module.
  final String id;

  /// The section's heading, drawn in capitals; the panel keeps whether the
  /// section is open or shut by it.
  final String title;

  /// The tool groups ([LevelToolHandler.group]) it opens for — its tools'
  /// own — and shut for the rest until opened; null to be open whatever the
  /// tool.
  final Set<String>? groups;

  /// Lower sorts first.
  final int order;

  /// Whether the section takes a share of the remaining height, like the
  /// prefab palette does, rather than its own height.
  final bool expand;

  /// Builds the section's content, shown while it is open.
  final Widget Function(BuildContext context, DesignerSession session) build;
}
