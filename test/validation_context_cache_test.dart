// The scene checks run every second or so on the UI thread: a file many
// entities name is read once a run, and not again on later runs while it
// is unchanged on disk — but read afresh once it changes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

void main() {
  late Directory dir;
  late EditorScope scope;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('validation_cache');
    scope = EditorScope(world: World()..initialize());
    addTearDown(scope.dispose);
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold it a moment longer.
    }
  });

  ValidationContext run() =>
      ValidationContext(scope: scope, projectRoot: dir.path);

  test('an unchanged file is decoded once, across runs', () {
    File('${dir.path}/a.json').writeAsStringSync('{"image": "a.png"}');
    final first = run().readJson('a.json');
    final again = run().readJson('a.json');
    expect(first, {'image': 'a.png'});
    expect(again, same(first));
  });

  test('a changed file is read again', () {
    final file = File('${dir.path}/a.json')
      ..writeAsStringSync('{"image": "a.png"}');
    expect(run().readJson('a.json')?['image'], 'a.png');
    file.writeAsStringSync('{"image": "bigger.png"}');
    expect(run().readJson('a.json')?['image'], 'bigger.png');
  });

  test('within one run a path is asked about once', () {
    final context = run();
    expect(context.fileExists('missing.png'), isFalse);
    File('${dir.path}/missing.png').writeAsStringSync('');
    expect(
      context.fileExists('missing.png'),
      isFalse,
      reason: 'the answer of this run',
    );
    expect(run().fileExists('missing.png'), isTrue, reason: 'the next run');
  });

  test('a file that is not there is null', () {
    expect(run().readText('nope.json'), isNull);
    expect(run().readJson('nope.json'), isNull);
  });
}
