// One module's mistake must not stop the others, and a module replaced by
// another of its id is let go of properly.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

class _Module extends EditorModule {
  _Module(this.id, {this.throws = false});

  @override
  final String id;

  @override
  String get name => id;

  final bool throws;
  int updates = 0;
  int opened = 0;
  bool disposed = false;

  @override
  void onUpdate(double dt) {
    updates++;
    if (throws) throw StateError('broken update');
  }

  @override
  void onSceneOpened(String sceneName) {
    opened++;
    if (throws) throw StateError('broken open');
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  late List<FlutterErrorDetails> reported;
  late FlutterExceptionHandler? was;

  setUp(() {
    reported = [];
    was = FlutterError.onError;
    FlutterError.onError = reported.add;
  });
  tearDown(() => FlutterError.onError = was);

  test('a module that throws is reported once, and the others still run', () {
    final registry = ModuleRegistry();
    final broken = _Module('broken', throws: true);
    final fine = _Module('fine');
    registry
      ..register(broken)
      ..register(fine);

    for (var i = 0; i < 3; i++) {
      registry.notifyUpdate(1 / 60);
    }
    registry.notifySceneOpened('level_01');

    expect(fine.updates, 3);
    expect(fine.opened, 1);
    expect(broken.updates, 3);
    expect(
      reported,
      hasLength(2),
      reason: 'one for the updates (not one a frame), one for the open',
    );
  });

  test('a module replaced by one of the same id is disposed', () {
    final registry = ModuleRegistry();
    final first = _Module('kit');
    final second = _Module('kit');
    registry.register(first);
    registry.register(first); // the same one again: kept
    expect(first.disposed, isFalse);
    registry.register(second);
    expect(first.disposed, isTrue);
    expect(registry.byId('kit'), same(second));
  });

  group('a save', () {
    test('is told to every module, one that throws among them', () async {
      final told = <String>[];
      final registry = ModuleRegistry()
        ..register(_Saving('a', told))
        ..register(_Saving('b', told, throws: true))
        ..register(_Saving('c', told));
      final failed = await registry.notifySceneSaving('level');
      expect(told, ['a', 'b', 'c']);
      expect(failed.keys, ['b']);
      expect(failed['b'], isA<StateError>());
    });

    test('goes on when the modules change while one is saving', () async {
      final told = <String>[];
      final gate = Completer<void>();
      final slow = _Saving('slow', told, until: gate.future);
      final gone = _Saving('gone', told);
      final registry = ModuleRegistry()
        ..register(slow)
        ..register(gone);
      final saving = registry.notifySceneSaving('level');
      // A hot reload while the first is still writing: one comes, one goes.
      registry
        ..register(_Saving('new', told))
        ..unregister('gone');
      gate.complete();
      final failed = await saving;
      expect(failed, isEmpty, reason: 'nothing broke the save');
      expect(told, ['slow'], reason: 'the one gone is not told');
    });
  });
}

class _Saving extends EditorModule {
  _Saving(this.id, this.told, {this.throws = false, this.until});

  @override
  final String id;

  @override
  String get name => id;

  final List<String> told;
  final bool throws;
  final Future<void>? until;

  @override
  Future<void> onSceneSaving(String sceneName) async {
    told.add(id);
    await until;
    if (throws) throw StateError('broken save');
  }
}
