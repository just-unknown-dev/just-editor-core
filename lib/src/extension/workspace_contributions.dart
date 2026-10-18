/// What a module adds to a window — a workspace the editor or another
/// module opens — without owning it: tools on its toolbar, sections in its
/// panel, overlays over its view.
library;

import 'package:flutter/widgets.dart';
import 'package:just_game_engine_formats/just_game_engine_formats.dart'
    show Material2DFile, MaterialFile;

import '../look/kit/buttons.dart';
import '../look/kit/layout.dart';
import '../scope/editor_scope.dart';

/// The ids of the editor's windows that modules add to most.
abstract final class WorkspaceIds {
  /// The 3-D material window (`*.material.json`).
  static const String material = 'materials.material';

  /// The 2-D material window (`*.material2d.json`).
  static const String material2D = 'materials.material2D';
}

/// What a window hands what modules add to it: which window it is, the
/// file it has open, the editor — and [changes], which fires when what it
/// shows does, so what is built from it is built again.
///
/// A window that says more hands a view of its own — the material
/// windows' [Material2DWorkspaceView] and [Material3DWorkspaceView] — which
/// a contribution asks for with `is`.
abstract class WorkspaceView {
  /// The window's id: its `WorkspaceDefinition.id`.
  String get workspaceId;

  /// The file it has open, project-relative; null for none.
  String? get path;

  /// The editor.
  EditorScope get scope;

  /// Fires when what the window shows changes.
  Listenable get changes;
}

/// Something a module adds to the window [workspaceId] (a
/// `WorkspaceDefinition.id`; the editor's own are in [WorkspaceIds]).
sealed class WorkspaceContribution {
  const WorkspaceContribution({
    required this.workspaceId,
    required this.id,
    this.order = 0,
  });

  /// The window it goes into.
  final String workspaceId;

  /// Names it.
  final String id;

  /// Its place among the window's contributions of its kind: lower first.
  final int order;
}

/// A button on the window's toolbar, after the window's own.
final class WorkspaceTool extends WorkspaceContribution {
  const WorkspaceTool({
    required super.workspaceId,
    required super.id,
    super.order,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive,
    this.isEnabled,
  });

  /// What it shows.
  final IconData icon;

  /// What it says on hover.
  final String tooltip;

  /// What pressing it does.
  final void Function(WorkspaceView view) onTap;

  /// Whether it shows as on; never when null.
  final bool Function(WorkspaceView view)? isActive;

  /// Whether it can be pressed; always when null.
  final bool Function(WorkspaceView view)? isEnabled;
}

/// A section of the window's panel, after the window's own: [title] its
/// header, [build] what is under it.
final class WorkspaceSection extends WorkspaceContribution {
  const WorkspaceSection({
    required super.workspaceId,
    required super.id,
    super.order,
    required this.title,
    required this.build,
  });

  /// Its header.
  final String title;

  /// What is under the header.
  final Widget Function(BuildContext context, WorkspaceView view) build;
}

/// Drawn over the window's view — its preview, its canvas — filling it:
/// [build] is given the view's size.
final class WorkspaceOverlay extends WorkspaceContribution {
  const WorkspaceOverlay({
    required super.workspaceId,
    required super.id,
    super.order,
    required this.build,
  });

  /// What is drawn over the view.
  final Widget Function(BuildContext context, WorkspaceView view, Size size)
  build;
}

/// A 2-D material window, for what modules add to it.
abstract class Material2DWorkspaceView extends WorkspaceView {
  /// The material as it will be saved: for a variant, its own effects and
  /// values.
  Material2DFile get material;

  /// What is drawn: a variant laid over its parents, a value being dragged
  /// included.
  Material2DFile get shown;

  /// Changes the material as [change] says, as one undo step.
  void change(Material2DFile Function(Material2DFile m) change);

  /// Shows [change] without an undo step, until [change] puts it in or
  /// [endPreview] lets it go.
  void preview(Material2DFile Function(Material2DFile m) change);

  /// Stops showing a [preview].
  void endPreview();
}

/// A 3-D material window, for what modules add to it.
abstract class Material3DWorkspaceView extends WorkspaceView {
  /// The material as it will be saved: for a variant, what it overrides.
  MaterialFile get material;

  /// What is drawn: a variant laid over its parents, a value being dragged
  /// included.
  MaterialFile get shown;

  /// Changes the material as [change] says — given what is shown — as one
  /// undo step.
  void change(MaterialFile Function(MaterialFile m) change);

  /// Shows [change] without an undo step, until [change] puts it in or
  /// [endPreview] lets it go.
  void preview(MaterialFile Function(MaterialFile m) change);

  /// Stops showing a [preview].
  void endPreview();
}

/// The [WorkspaceTool]s modules add to [view]'s window, as buttons: what a
/// window puts on its toolbar after its own.
class WorkspaceToolButtons extends StatelessWidget {
  const WorkspaceToolButtons({super.key, required this.view});

  /// The window they act on.
  final WorkspaceView view;

  @override
  Widget build(BuildContext context) {
    final tools = view.scope.workspaceContributionsFor<WorkspaceTool>(
      view.workspaceId,
    );
    if (tools.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: view.changes,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in tools)
            EditorIconButton(
              icon: t.icon,
              tooltip: t.tooltip,
              isActive: t.isActive?.call(view) ?? false,
              onTap: (t.isEnabled?.call(view) ?? true)
                  ? () => t.onTap(view)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// The [WorkspaceSection]s modules add to [view]'s window, each under its
/// header: what a window puts in its panel after its own sections.
class WorkspaceSections extends StatelessWidget {
  const WorkspaceSections({super.key, required this.view});

  /// The window they are in.
  final WorkspaceView view;

  @override
  Widget build(BuildContext context) {
    final sections = view.scope.workspaceContributionsFor<WorkspaceSection>(
      view.workspaceId,
    );
    if (sections.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: view.changes,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in sections) ...[
            EditorSectionHeader(s.title),
            s.build(context, view),
          ],
        ],
      ),
    );
  }
}

/// The [WorkspaceOverlay]s modules add to [view]'s window, over a view of
/// [size]: each fills it, the first furthest back. What a window stacks
/// over its view.
List<Widget> workspaceOverlays(WorkspaceView view, Size size) => [
  for (final o in view.scope.workspaceContributionsFor<WorkspaceOverlay>(
    view.workspaceId,
  ))
    Positioned.fill(
      child: ListenableBuilder(
        listenable: view.changes,
        builder: (context, _) => o.build(context, view, size),
      ),
    ),
];
