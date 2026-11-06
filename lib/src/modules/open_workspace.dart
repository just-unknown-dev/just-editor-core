import 'editor_contributions.dart';

/// A workspace that is open, and the file it was opened on.
class OpenWorkspace {
  const OpenWorkspace(this.definition, [this.path]);

  /// Which workspace is open.
  final WorkspaceDefinition definition;

  /// The project-relative file it was opened on; null when none.
  final String? path;
}
