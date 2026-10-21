// One module's mistake must not stop the others, and a module replaced by
// another of its id is let go of properly.

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
}
