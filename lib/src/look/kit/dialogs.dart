import 'package:flutter/material.dart';

import '../editor_theme.dart';
import '../editor_metrics.dart';
import 'buttons.dart';
import 'editor_look.dart';
import 'fields.dart';

/// A small dialog in the editor's look: a title, what it is about, and the
/// buttons — the one to press last and filled.
class EditorAlert extends StatelessWidget {
  const EditorAlert({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  /// The dialog's title, at the top.
  final String title;

  /// What it is about, under the title; ignored when [content] is given.
  final String? message;

  /// Anything more than a message: a field, a list.
  final Widget? content;

  /// The buttons along the foot, usually [EditorButton]s, in order: the
  /// one to press last and filled.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => EditorLook(
    child: AlertDialog(
      backgroundColor: EditorTheme.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EditorMetrics.radiusLg),
        side: BorderSide(color: EditorTheme.borderStrong),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      title: Text(
        title,
        style: TextStyle(
          color: EditorTheme.textPrimary,
          fontSize: EditorMetrics.fontTitle,
          fontWeight: FontWeight.w600,
        ),
      ),
      content:
          content ??
          (message == null
              ? null
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    message!,
                    style: TextStyle(
                      color: EditorTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                )),
      actions: actions,
    ),
  );
}

/// Asks before something that cannot be taken back. True when the user
/// went ahead.
Future<bool> showEditorConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => EditorAlert(
      title: title,
      message: message,
      actions: [
        EditorButton(
          label: 'Cancel',
          kind: EditorButtonKind.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        EditorButton(
          label: confirmLabel,
          kind: danger ? EditorButtonKind.danger : EditorButtonKind.primary,
          autofocus: !danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Asks for a line of text — a name, a label — in the editor's look. The
/// text, trimmed, once [actionLabel] is pressed or Enter typed; null when
/// cancelled.
///
/// [validate] says what is wrong with the text as it is typed — null when
/// nothing is — and the answer waits until nothing is. An empty answer is
/// taken only when [allowEmpty] says so.
Future<String?> showEditorPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String actionLabel = 'OK',
  String? Function(String text)? validate,
  bool allowEmpty = false,
}) => showDialog<String>(
  context: context,
  barrierColor: Colors.black54,
  builder: (context) => _EditorPrompt(
    title: title,
    initial: initial,
    hint: hint,
    actionLabel: actionLabel,
    validate: validate,
    allowEmpty: allowEmpty,
  ),
);

// The dialog owns its text, so the text goes with it — after its closing
// animation, not while it still draws.
class _EditorPrompt extends StatefulWidget {
  const _EditorPrompt({
    required this.title,
    required this.initial,
    required this.hint,
    required this.actionLabel,
    required this.validate,
    required this.allowEmpty,
  });

  final String title;
  final String initial;
  final String? hint;
  final String actionLabel;
  final String? Function(String text)? validate;
  final bool allowEmpty;

  @override
  State<_EditorPrompt> createState() => _EditorPromptState();
}

class _EditorPromptState extends State<_EditorPrompt> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  // Said once something is typed, or on an answer: not of the text it
  // opened with.
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canAnswer =>
      _error == null && (widget.allowEmpty || _text.text.trim().isNotEmpty);

  void _changed(String value) =>
      setState(() => _error = widget.validate?.call(value.trim()));

  void _answer() {
    final text = _text.text.trim();
    final error = widget.validate?.call(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (!_canAnswer) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => EditorAlert(
    title: widget.title,
    content: SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            onChanged: _changed,
            onSubmitted: (_) => _answer(),
            cursorColor: EditorTheme.primaryBright,
            style: TextStyle(color: EditorTheme.textPrimary, fontSize: 13),
            decoration: editorFieldDecoration(
              hint: widget.hint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(color: EditorTheme.errorLight, fontSize: 11),
            ),
          ],
        ],
      ),
    ),
    actions: [
      EditorButton(
        label: 'Cancel',
        kind: EditorButtonKind.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      EditorButton(
        label: widget.actionLabel,
        kind: EditorButtonKind.primary,
        onPressed: _canAnswer ? _answer : null,
      ),
    ],
  );
}

/// What to do with work that has not been saved.
enum UnsavedChoice {
  /// Save the work, then go on.
  save,

  /// Go on without saving: the work is lost.
  discard,
}

/// Asks whether to save before something that would lose unsaved work:
/// Save, Don't save, or Cancel — which is null.
Future<UnsavedChoice?> askToSaveChanges(
  BuildContext context, {
  required String title,
  String? message,
}) => showDialog<UnsavedChoice>(
  context: context,
  barrierColor: Colors.black54,
  builder: (context) => EditorAlert(
    title: title,
    message: message,
    actions: [
      EditorButton(
        label: "Don't save",
        kind: EditorButtonKind.danger,
        onPressed: () => Navigator.of(context).pop(UnsavedChoice.discard),
      ),
      EditorButton(
        label: 'Cancel',
        kind: EditorButtonKind.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      EditorButton(
        label: 'Save',
        kind: EditorButtonKind.primary,
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(UnsavedChoice.save),
      ),
    ],
  ),
);

/// Offers work that was never saved — an autosaved backup: Recover (true),
/// Open saved (false), or Cancel — which is null, and decides nothing.
Future<bool?> askToRecover(
  BuildContext context, {
  required String title,
  String? message,
}) => showDialog<bool>(
  context: context,
  barrierColor: Colors.black54,
  builder: (context) => EditorAlert(
    title: title,
    message: message,
    actions: [
      EditorButton(
        label: 'Open saved',
        kind: EditorButtonKind.ghost,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      EditorButton(
        label: 'Recover',
        kind: EditorButtonKind.primary,
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  ),
);
