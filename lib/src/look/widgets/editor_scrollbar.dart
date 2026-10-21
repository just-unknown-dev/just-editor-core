import 'package:flutter/material.dart';

import '../editor_constants.dart';

/// Builds a scrollable around [controller].
typedef ScrollableBuilder =
    Widget Function(BuildContext context, ScrollController controller);

/// A scroll bar that is always there when a list holds more than it shows.
///
/// On the desktop Flutter shows a list's bar only while it scrolls or the
/// pointer is over it, so a long list looks as if it ends at the foot of its
/// panel. This one keeps its thumb showing, and switches the default one
/// off beneath it so there are never two.
///
/// [builder] gets the controller to give its scrollable; pass [controller]
/// to use one of your own, otherwise one is made and disposed here.
class EditorScrollbar extends StatefulWidget {
  const EditorScrollbar({
    super.key,
    required this.builder,
    this.controller,
    this.axis = Axis.vertical,
  });

  /// Builds the scrollable, which must use the controller it is given so
  /// the bar follows it.
  final ScrollableBuilder builder;

  /// The scrollable's controller, when the owner needs it too; null makes
  /// one here and disposes of it.
  final ScrollController? controller;

  /// Which way the scrollable scrolls.
  final Axis axis;

  /// How thick the bar is drawn.
  static const double thickness = 6;

  /// The theme the editor's bars are drawn with: quiet until touched.
  static ScrollbarThemeData get theme => ScrollbarThemeData(
    thickness: const WidgetStatePropertyAll(thickness),
    radius: const Radius.circular(3),
    thumbColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)
          ? EditorTheme.textSecondary.withValues(alpha: 0.7)
          : EditorTheme.textMuted.withValues(alpha: 0.45),
    ),
    crossAxisMargin: 1,
    mainAxisMargin: 2,
  );

  @override
  State<EditorScrollbar> createState() => _EditorScrollbarState();
}

class _EditorScrollbarState extends State<EditorScrollbar> {
  ScrollController? _own;

  ScrollController get _controller =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ScrollbarTheme(
      data: EditorScrollbar.theme,
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        notificationPredicate: (n) =>
            n.depth == 0 && n.metrics.axis == widget.axis,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: widget.builder(context, controller),
        ),
      ),
    );
  }
}
