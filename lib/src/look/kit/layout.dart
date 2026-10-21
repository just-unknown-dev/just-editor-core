import 'package:flutter/material.dart';

import '../editor_constants.dart';
import '../editor_metrics.dart';
import 'buttons.dart';

/// A row of controls along the top of a dock, a panel or a dialog.
///
/// Narrower than what is in it — a docked panel shrunk, a popped-out dock —
/// it scrolls sideways instead of spilling over the edge; wide enough, a
/// [Spacer] in it pushes what follows to the right as in any row.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key, required this.children, this.border = true});

  /// The controls, left to right, laid out in a [Row].
  final List<Widget> children;

  /// The line along its foot.
  final bool border;

  /// Room for a row of targets and a little air: taller with bigger ones.
  static double get height => EditorMetrics.minTarget + 8;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: border
        ? BoxDecoration(
            border: Border(bottom: BorderSide(color: EditorTheme.border)),
          )
        : null,
    child: LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          // At least as wide as there is room for, so a Spacer still
          // spaces; wider when what is in it needs more.
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: IntrinsicWidth(child: Row(children: children)),
        ),
      ),
    ),
  );
}

/// The uppercase caption over a group: `LAYERS`, `MODULES`.
class EditorSectionHeader extends StatelessWidget {
  const EditorSectionHeader(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 4),
  });

  /// The caption, shown in capitals whatever case it is given in.
  final String label;

  /// Something at the right end: a count, an Add button.
  final Widget? trailing;

  /// Space around the header; 12 at the sides and top, 4 below by default.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: EditorTheme.textMuted,
                fontSize: EditorMetrics.fontCaption,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A raised, bordered block of related things.
class EditorCard extends StatelessWidget {
  const EditorCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
  });

  /// What the card holds.
  final Widget child;

  /// Space inside the card, around [child]; 12 on every side by default.
  final EdgeInsetsGeometry padding;

  /// Space outside the card; none by default.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: EditorTheme.surfaceBg,
      borderRadius: BorderRadius.circular(EditorMetrics.radiusMd),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: child,
  );
}

/// A hairline between regions.
class EditorDivider extends StatelessWidget {
  const EditorDivider({super.key, this.vertical = false});

  /// Whether the line runs up and down (1 px wide, as tall as it is let
  /// be) rather than across (1 px tall). Off by default.
  final bool vertical;

  @override
  Widget build(BuildContext context) => Container(
    width: vertical ? 1 : null,
    height: vertical ? null : 1,
    color: Colors.white.withValues(alpha: 0.06),
  );
}

/// What a panel shows when it has nothing to show, and what to do about it.
class EditorEmptyState extends StatelessWidget {
  const EditorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  /// A small muted icon over the title.
  final IconData icon;

  /// What there is not, in a line: "Nothing selected".
  final String title;

  /// A quieter line under the title — how to get something to show; none
  /// when null.
  final String? hint;

  /// The one thing to do from here — "Add a Timeline Player". Shown only
  /// with [onAction].
  final String? actionLabel;

  /// The action button's icon; a plus when null.
  final IconData? actionIcon;

  /// Called when the action button is pressed; the button shows only when
  /// this and [actionLabel] are both set.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    // Scrolls rather than spill when the room is short — a docked panel
    // dragged down to a sliver.
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: EditorTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: EditorTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: EditorTheme.textMuted, fontSize: 10),
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            EditorButton(
              label: actionLabel!,
              icon: actionIcon ?? Icons.add_rounded,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    ),
  );
}
