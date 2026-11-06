import 'package:flutter/widgets.dart';

import 'editor_scope.dart';

/// Makes an [EditorScope] available to a widget subtree.
class EditorScopeProvider extends InheritedWidget {
  const EditorScopeProvider({
    super.key,
    required this.scope,
    required super.child,
  });

  /// The scope [of] and [maybeOf] find below this widget.
  final EditorScope scope;

  /// The nearest scope above [context].
  static EditorScope of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<EditorScopeProvider>();
    assert(provider != null, 'No EditorScopeProvider above this widget');
    return provider!.scope;
  }

  /// The nearest scope above [context], or null.
  static EditorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EditorScopeProvider>()?.scope;

  @override
  bool updateShouldNotify(EditorScopeProvider old) => old.scope != scope;
}
