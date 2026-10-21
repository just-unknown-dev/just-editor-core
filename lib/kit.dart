/// The editor's UI kit alone — buttons, fields, controls, dialogs,
/// dropdowns ([EditorDropdown]), menus ([showEditorMenu]), scroll bars
/// ([EditorScrollbar]), number fields to drag ([ScrubbableNumberField]),
/// the snackbar ([EditorSnackBarController]), the theme and its metrics —
/// for tools that draw like the editor.
library;

export 'src/look/editor_constants.dart' show EditorTheme;
export 'src/look/editor_metrics.dart';
export 'src/look/editor_theme_data.dart';
export 'src/look/kit/kit.dart';
// The settings the look follows ([EditorMetrics.settings]).
export 'src/settings/gizmo_settings.dart';
export 'src/settings/overlay_ui_settings.dart';
