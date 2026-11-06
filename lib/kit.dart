/// The editor's UI kit alone — buttons, fields, controls, dialogs,
/// dropdowns ([EditorDropdown]), menus ([showEditorMenu]), scroll bars
/// ([EditorScrollbar]), number fields to drag ([ScrubbableNumberField]),
/// the snackbar ([EditorSnackBarController]), the theme and its metrics —
/// for tools that draw like the editor. It needs no engine: Flutter and
/// `just_signals` are all it imports.
library;

export 'src/look/look.dart';
// The settings the look follows ([EditorMetrics.settings]).
export 'src/settings/gizmo_settings.dart';
export 'src/settings/overlay_ui_settings.dart';
