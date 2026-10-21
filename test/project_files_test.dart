import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('project_files'));
  tearDown(() => dir.deleteSync(recursive: true));

  String at(String name) => '${dir.path}/$name';

  group('writeString', () {
    test('writes the whole file and leaves nothing beside it', () async {
      await ProjectFiles.writeString(at('a/b/scene.json'), '{"a":1}');
      expect(File(at('a/b/scene.json')).readAsStringSync(), '{"a":1}');
      expect(File(at('a/b/scene.json.saving')).existsSync(), isFalse);
    });

    test('replaces what was there', () async {
      File(at('x.json')).writeAsStringSync('old');
      await ProjectFiles.writeString(at('x.json'), 'new');
      expect(File(at('x.json')).readAsStringSync(), 'new');
    });

    test('a write that fails leaves the old file and no .saving', () async {
      File(at('x.json')).writeAsStringSync('old');
      // A folder where the file should be: the move over it fails.
      Directory(at('x.json.saving')).createSync();
      await expectLater(
        ProjectFiles.writeString(at('x.json'), 'new'),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(at('x.json')).readAsStringSync(), 'old');
    });

    test('waits out a reader holding the file open (Windows)', () async {
      File(at('held.json')).writeAsStringSync('old');
      final reader = await File(at('held.json')).open();
      // Let go a moment after the write starts trying.
      final release = Future<void>.delayed(
        const Duration(milliseconds: 60),
        reader.close,
      );
      await ProjectFiles.writeString(at('held.json'), 'new');
      await release;
      expect(File(at('held.json')).readAsStringSync(), 'new');
      expect(File(at('held.json.saving')).existsSync(), isFalse);
    }, skip: Platform.isWindows ? false : 'Only Windows locks open files');

    test('the sync form writes the same', () {
      ProjectFiles.writeStringSync(at('s/t.json'), 'text');
      expect(File(at('s/t.json')).readAsStringSync(), 'text');
      expect(File(at('s/t.json.saving')).existsSync(), isFalse);
    });
  });

  group('rename', () {
    test('moves a file, making the folder', () async {
      File(at('a.json')).writeAsStringSync('a');
      await ProjectFiles.rename(at('a.json'), at('sub/b.json'));
      expect(File(at('a.json')).existsSync(), isFalse);
      expect(File(at('sub/b.json')).readAsStringSync(), 'a');
    });

    test('never replaces a file already there', () async {
      File(at('a.json')).writeAsStringSync('a');
      File(at('b.json')).writeAsStringSync('b');
      await expectLater(
        ProjectFiles.rename(at('a.json'), at('b.json')),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(at('a.json')).readAsStringSync(), 'a');
      expect(File(at('b.json')).readAsStringSync(), 'b');
    });

    test('a change of letter case keeps the file', () async {
      File(at('level_01.json')).writeAsStringSync('level');
      await ProjectFiles.rename(at('level_01.json'), at('Level_01.json'));
      final names = dir.listSync().map((e) => e.uri.pathSegments.last);
      expect(names, ['Level_01.json']);
      expect(File(at('Level_01.json')).readAsStringSync(), 'level');
    });

    test('moves a folder', () async {
      File(at('f/a.json')).createSync(recursive: true);
      await ProjectFiles.rename(at('f'), at('g'));
      expect(File(at('g/a.json')).existsSync(), isTrue);
      expect(Directory(at('f')).existsSync(), isFalse);
    });
  });

  test('samePath folds case where the file system does', () {
    expect(ProjectFiles.samePath('a/b.json', r'a\b.json'), isTrue);
    expect(
      ProjectFiles.samePath('a/B.json', 'a/b.json'),
      ProjectFiles.foldsCase,
    );
  });

  test('isContained keeps paths inside the project', () {
    expect(ProjectFiles.isContained('assets/a.png'), isTrue);
    expect(ProjectFiles.isContained('assets/x/../a.png'), isTrue);
    expect(ProjectFiles.isContained(r'assets\a.png'), isTrue);
    expect(ProjectFiles.isContained('../a.png'), isFalse);
    expect(ProjectFiles.isContained('assets/../../a.png'), isFalse);
    expect(ProjectFiles.isContained('/etc/passwd'), isFalse);
    expect(ProjectFiles.isContained(r'C:\a.png'), isFalse);
    expect(ProjectFiles.isContained(''), isFalse);
  });
}
