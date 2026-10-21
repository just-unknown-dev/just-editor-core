import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_signals/just_signals.dart';

/// One reversible editor action.
///
/// Commands are the only sanctioned way to change a level once the Level
/// Designer is open. Anything that mutates the world outside one is invisible
/// to undo, which is worse than having no undo at all — the user stops
/// trusting Ctrl+Z and stops using it.
abstract class EditorCommand {
  /// Short, human-readable description, shown in the undo tooltip.
  /// Phrase it as the action performed: "Move 3 entities", "Delete Platform_4".
  String get label;

  /// Perform the action. Called once when the command is first executed and
  /// again on every redo, so it must be idempotent with respect to [undo].
  void redo();

  /// Reverse [redo], restoring the exact prior state.
  void undo();

  /// Fold [next] into this command if the two are part of one user gesture.
  ///
  /// Returns true when absorbed, in which case [next] is discarded. This is
  /// what stops a drag from pushing one command per pointer-move event and
  /// burying every earlier action under a hundred one-pixel nudges.
  bool mergeWith(EditorCommand next) => false;
}

/// A command built from two closures, for actions simple enough that a named
/// class would be noise.
class CallbackCommand extends EditorCommand {
  /// `onRedo` performs the action, the first time and on every redo;
  /// `onUndo` reverses it.
  CallbackCommand({
    required this.label,
    required void Function() onRedo,
    required void Function() onUndo,
  }) : _redo = onRedo,
       _undo = onUndo;

  @override
  final String label;

  final void Function() _redo;
  final void Function() _undo;

  @override
  void redo() => _redo();

  @override
  void undo() => _undo();
}

/// The editor's undo/redo stack: one for the whole editor (the scope's),
/// the Level Designer included.
///
/// Exposes its state as signals so toolbar buttons bind directly instead of
/// polling or being told to rebuild.
class EditorHistory {
  /// Keeps at most [capacity] steps: 200 unless given, and never fewer
  /// than 1.
  EditorHistory({int capacity = 200}) : _capacity = math.max(1, capacity);

  /// How many commands are retained. Older ones are dropped from the bottom.
  ///
  /// Bounded because a command can hold a full component snapshot of a deleted
  /// entity, so an unbounded stack is an unbounded memory leak across a long
  /// editing session. Made smaller, the oldest steps go at once.
  int get capacity => _capacity;
  int _capacity;
  set capacity(int value) {
    final next = math.max(1, value);
    if (next == _capacity) return;
    _capacity = next;
    if (_undoStack.length > next) {
      batch(() {
        _trim(_undoStack.length - next);
        _publish();
      });
    }
  }

  /// Drops the [count] oldest steps. Once one is gone it cannot be undone,
  /// so a save made before it — or at the empty stack below it — can never
  /// be on top again: the document stays dirty until the next save.
  void _trim(int count) {
    if (count <= 0) return;
    final dropped = _undoStack.sublist(0, count);
    if (_savedTop == null || dropped.any((c) => identical(c, _savedTop))) {
      _saveReachable = false;
    }
    _undoStack.removeRange(0, count);
  }

  final List<EditorCommand> _undoStack = [];
  final List<EditorCommand> _redoStack = [];

  /// Whether there is anything to undo.
  final Signal<bool> canUndo = Signal(false, debugLabel: 'canUndo');

  /// Whether there is anything to redo.
  final Signal<bool> canRedo = Signal(false, debugLabel: 'canRedo');

  /// Label of the action Ctrl+Z would reverse, for the button tooltip.
  final Signal<String?> nextUndoLabel = Signal(null, debugLabel: 'nextUndo');

  /// Label of the action Ctrl+Y would replay.
  final Signal<String?> nextRedoLabel = Signal(null, debugLabel: 'nextRedo');

  /// Raised whenever the stack changes, so the viewport can repaint.
  final Signal<int> revision = Signal(0, debugLabel: 'undoRevision');

  /// Whether what is applied differs from what was last saved — see
  /// [markSaved]. Undoing back to the save reads clean again.
  final Signal<bool> dirty = Signal(false, debugLabel: 'historyDirty');

  /// The command on top when [markSaved] was called — null for an empty
  /// stack — so the document is clean exactly when that is on top again.
  EditorCommand? _savedTop;

  /// Whether undo or redo can still get back to what was saved: false once
  /// the step it rests on was trimmed away, a step failed half-way, or the
  /// history was cleared over unsaved changes.
  bool _saveReachable = true;

  /// Whether the next push must stand alone; see [breakMerge].
  bool _noMerge = false;

  /// Records that what is applied now is what was saved.
  ///
  /// Nothing is folded into the command on top afterwards: merged, it would
  /// be a different state wearing the saved one's name.
  void markSaved() {
    _savedTop = _undoStack.isEmpty ? null : _undoStack.last;
    _saveReachable = true;
    _publish();
  }

  /// Makes the next command its own undo step, whatever it would have merged
  /// with. Called when a new gesture begins — a drag, a nudge — so two drags
  /// of the same thing undo as two, while one drag stays one.
  void breakMerge() => _noMerge = true;

  // Merging into the saved state would change it without moving off it.
  bool _mayMergeInto(EditorCommand top) =>
      !_noMerge && !identical(top, _savedTop);

  /// True while [undo] or [redo] is running.
  ///
  /// Mutation funnels check this and skip recording, so replaying a command
  /// does not push a new command describing the replay.
  bool get isApplying => _isApplying;
  bool _isApplying = false;

  /// Runs [command] and records it.
  ///
  /// Does nothing while a command is already being applied, which is what
  /// keeps undo from recording its own side effects.
  void push(EditorCommand command) {
    if (_isApplying) {
      command.redo();
      return;
    }

    batch(() {
      command.redo();

      // A new action makes the redo branch unreachable — standard linear undo.
      _redoStack.clear();

      if (_undoStack.isNotEmpty &&
          _mayMergeInto(_undoStack.last) &&
          _undoStack.last.mergeWith(command)) {
        // Absorbed into the previous command; nothing new to stack.
      } else {
        _undoStack.add(command);
        _trim(_undoStack.length - _capacity);
      }
      _noMerge = false;

      _publish();
    });
  }

  /// Records [command] as already performed, without running it.
  ///
  /// For state a widget has already changed by the time it can build the
  /// command — an inspector field whose controller has committed, say.
  void pushApplied(EditorCommand command) {
    if (_isApplying) return;
    batch(() {
      _redoStack.clear();
      if (_undoStack.isEmpty ||
          !_mayMergeInto(_undoStack.last) ||
          !_undoStack.last.mergeWith(command)) {
        _undoStack.add(command);
        _trim(_undoStack.length - _capacity);
      }
      _noMerge = false;
      _publish();
    });
  }

  /// What has been done, oldest first.
  List<EditorCommand> get undoEntries => List.unmodifiable(_undoStack);

  /// What has been undone, the next to redo last.
  List<EditorCommand> get redoEntries => List.unmodifiable(_redoStack);

  /// Undoes or redoes until exactly [done] steps are applied: 0 is the scene
  /// as opened, [undoEntries].length plus [redoEntries].length is everything.
  void jumpTo(int done) {
    final target = done.clamp(0, _undoStack.length + _redoStack.length);
    while (_undoStack.length > target) {
      final before = _undoStack.length;
      undo();
      if (_undoStack.length == before) return; // a step refused to move
    }
    while (_undoStack.length < target) {
      final before = _undoStack.length;
      redo();
      if (_undoStack.length == before) return;
    }
  }

  /// Reverses the most recent command.
  ///
  /// A command that throws is reported (`FlutterError.reportError`) and
  /// dropped: what it left half-done cannot be trusted to undo or redo
  /// again. The buttons and labels are brought up to date either way, and
  /// the document reads dirty until it is saved.
  void undo() {
    if (_undoStack.isEmpty) return;
    final command = _undoStack.removeLast();
    _apply(command, 'undoing', () {
      command.undo();
      _redoStack.add(command);
    });
  }

  /// Replays the most recently undone command; see [undo] for one that
  /// throws.
  void redo() {
    if (_redoStack.isEmpty) return;
    final command = _redoStack.removeLast();
    _apply(command, 'redoing', () {
      command.redo();
      _undoStack.add(command);
    });
  }

  void _apply(EditorCommand command, String doing, void Function() run) {
    _isApplying = true;
    try {
      batch(() {
        try {
          run();
        } catch (error, stack) {
          _saveReachable = false;
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'just_editor_core',
              context: ErrorDescription(
                'while $doing "${command.label}" (the step was dropped)',
              ),
            ),
          );
        } finally {
          _publish();
        }
      });
    } finally {
      _isApplying = false;
    }
  }

  /// Drops all history, e.g. when a different scene is opened.
  ///
  /// Essential rather than tidy: a command holds entity references from the
  /// scene it was recorded in, so undoing across a scene load would write into
  /// destroyed entities.
  ///
  /// What is applied becomes the new starting point, and reads clean: the
  /// save point of what came before means nothing to it. (Clearing a
  /// document that still has unsaved changes is the caller's to guard.)
  void clear() {
    batch(() {
      _saveReachable = true;
      _savedTop = null;
      _undoStack.clear();
      _redoStack.clear();
      _publish();
    });
  }

  /// What the history holds now — every step done and every step undone —
  /// to go back to with [restore].
  ///
  /// A play-test takes one when it starts and goes back to it when it
  /// stops: whatever was done while the game ran was done to a world that
  /// Stop puts back as authored, so undoing it afterwards would move the
  /// authored level to where the play-test had it.
  EditorHistoryMark mark() =>
      EditorHistoryMark._(List.of(_undoStack), List.of(_redoStack));

  /// Puts the history back as it was at [mark], running nothing: what was
  /// done since is dropped, and what was undone since is a step done again.
  /// For a world that has itself been put back as it was then.
  void restore(EditorHistoryMark mark) {
    batch(() {
      _undoStack
        ..clear()
        ..addAll(mark._undo);
      _redoStack
        ..clear()
        ..addAll(mark._redo);
      // Folding the next edit into a step from before would make it one.
      _noMerge = true;
      _publish();
    });
  }

  void _publish() {
    canUndo.value = _undoStack.isNotEmpty;
    canRedo.value = _redoStack.isNotEmpty;
    nextUndoLabel.value = _undoStack.isEmpty ? null : _undoStack.last.label;
    nextRedoLabel.value = _redoStack.isEmpty ? null : _redoStack.last.label;
    dirty.value =
        !_saveReachable ||
        !identical(_undoStack.isEmpty ? null : _undoStack.last, _savedTop);
    revision.value = revision.value + 1;
  }

  /// Number of commands available to undo. Exposed for tests and diagnostics.
  int get undoDepth => _undoStack.length;

  /// Number of commands available to redo.
  int get redoDepth => _redoStack.length;

  /// Releases the signals.
  void dispose() {
    canUndo.dispose();
    canRedo.dispose();
    nextUndoLabel.dispose();
    nextRedoLabel.dispose();
    revision.dispose();
    dirty.dispose();
  }
}

/// An [EditorHistory] as it was at one moment ([EditorHistory.mark]), to go
/// back to ([EditorHistory.restore]).
final class EditorHistoryMark {
  EditorHistoryMark._(this._undo, this._redo);

  final List<EditorCommand> _undo;
  final List<EditorCommand> _redo;
}
