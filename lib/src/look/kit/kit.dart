/// The parts the editor is built from — buttons, fields, controls, the
/// shapes of panels and dialogs, dropdowns, menus, scroll bars, number
/// fields to drag, the snackbar — in its colours and at its sizes, so every
/// panel, dock and dialog looks like one editor, and a module's too.
///
/// Colours come from `EditorTheme`, sizes from `EditorMetrics`; both follow
/// the settings.
library;

export 'dialog_frame.dart' show EditorDialogFrame;
export 'buttons.dart';
export 'controls.dart';
export 'dialogs.dart';
export 'fields.dart';
export 'focus.dart';
export 'key_claim.dart';
export 'layout.dart';
export 'look.dart';
export 'workspace.dart';
export '../snackbar.dart';
export '../widgets/editor_dropdown.dart';
export '../widgets/editor_menu.dart';
export '../widgets/editor_scrollbar.dart';
export '../widgets/scrubbable_number_field.dart';
export '../widgets/throttled_signal_consumer.dart';
