import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// [builder], built again when any of [signals] change, and when [often]
/// changes — that one at most every [every] while it keeps changing: the
/// first change after a still moment at once, the last one always.
///
/// For a panel that shows values of a scene being edited — the inspector,
/// a toolbar — with [often] the scene's revision: a gizmo drag bumps it on
/// every pointer move, and building the whole panel each time made the drag
/// stutter. What draws the move itself (the viewport) follows the revision
/// directly.
class ThrottledSignalConsumer extends StatefulWidget {
  const ThrottledSignalConsumer({
    super.key,
    required this.often,
    required this.signals,
    required this.builder,
    this.every = const Duration(milliseconds: 100),
  });

  /// The signal that changes too often to follow every change of.
  final ValueListenable<Object?> often;

  /// The signals followed at once.
  final List<ValueListenable<Object?>> signals;

  /// What is shown.
  final WidgetBuilder builder;

  /// How often a run of changes to [often] is passed on.
  final Duration every;

  @override
  State<ThrottledSignalConsumer> createState() =>
      _ThrottledSignalConsumerState();
}

class _ThrottledSignalConsumerState extends State<ThrottledSignalConsumer> {
  Timer? _cooling;
  bool _owed = false;

  @override
  void initState() {
    super.initState();
    _listen(widget);
  }

  @override
  void didUpdateWidget(covariant ThrottledSignalConsumer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.often, widget.often) ||
        !listEquals(oldWidget.signals, widget.signals)) {
      _forget(oldWidget);
      _listen(widget);
    }
  }

  @override
  void dispose() {
    _cooling?.cancel();
    _forget(widget);
    super.dispose();
  }

  void _listen(ThrottledSignalConsumer w) {
    w.often.addListener(_onOften);
    for (final s in w.signals) {
      s.addListener(_rebuild);
    }
  }

  void _forget(ThrottledSignalConsumer w) {
    w.often.removeListener(_onOften);
    for (final s in w.signals) {
      s.removeListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onOften() {
    if (_cooling != null) {
      _owed = true;
      return;
    }
    _pass();
  }

  void _pass() {
    _owed = false;
    _rebuild();
    _cooling = Timer(widget.every, () {
      _cooling = null;
      if (_owed && mounted) _pass();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
