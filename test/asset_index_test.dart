// The asset browser's model: what is on disk, kept current, and the file
// operations — none of which may lose a file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

import 'support/real_io.dart';

void main() {
  late Directory dir;
  late AssetIndex index;

  void write(String path, [String content = 'x']) => File('${dir.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  bool exists(String path) =>
      FileSystemEntity.typeSync('${dir.path}/$path') !=
      FileSystemEntityType.notFound;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('asset_index');
    write('assets/sprites/hero.png', 'png-bytes');
    write('assets/sprites/hero.jsprite');
    write('assets/sprites/hero.animator.json', '{}');
    write('assets/audio/jump.wav');
    write(
      'assets/scenes/level_01.scene.json',
      '{"entities":[{"spritePath": "assets/sprites/hero.png"},'
          '{"other": "assets/sprites/hero.png.bak"}]}',
    );
    index = AssetIndex(projectRoot: dir.path);
    await index.scan();
  });
  tearDown(() async {
    index.dispose();
    // A watcher lets go of the folder a moment after it is cancelled.
    await deleteWhenFree(dir);
  });

  test('it sees files and folders, by project-relative path and kind', () {
    expect(index.fileCount, 5);
    expect(index.childrenOf('assets').map((e) => e.name), [
      'audio',
      'scenes',
      'sprites',
    ]);
    final kinds = {for (final e in index.entries) e.name: e.kind};
    expect(kinds['hero.png'], AssetKind.image);
    expect(kinds['hero.jsprite'], AssetKind.sprite);
    expect(kinds['hero.animator.json'], AssetKind.animator);
    expect(kinds['level_01.scene.json'], AssetKind.scene);
    expect(kinds['jump.wav'], AssetKind.audio);
    expect(kinds['sprites'], AssetKind.folder);
    expect(index.entryAt('assets/sprites/hero.png')!.sizeLabel, '9 B');
  });

  test('search is by name, kind and folder', () {
    expect(index.search('HERO').map((e) => e.name), hasLength(3));
    expect(
      index.search('', kinds: {AssetKind.image}).single.path,
      'assets/sprites/hero.png',
    );
    expect(index.search('', within: 'assets/audio').single.name, 'jump.wav');
    expect(index.search('nothing'), isEmpty);
  });

  test('a file that appears on disk shows up by itself', () async {
    index.startWatching();
    write('assets/sprites/coin.png');
    // Heard, then rescanned after a short pause: on the real clock.
    await waitUntil(
      () => index.entryAt('assets/sprites/coin.png') != null,
      what: 'the new file to be listed',
    );
    expect(index.entryAt('assets/sprites/coin.png'), isNotNull);
  });

  test('new folder, duplicate and rename never overwrite', () async {
    expect(await index.newFolder('assets'), 'assets/New folder');
    expect(await index.newFolder('assets'), 'assets/New folder 2');
    expect(
      await index.duplicate('assets/sprites/hero.png'),
      'assets/sprites/hero copy.png',
    );
    expect(
      await index.rename('assets/audio/jump.wav', 'leap.wav'),
      'assets/audio/leap.wav',
    );
    expect(exists('assets/audio/jump.wav'), isFalse);
    await expectLater(
      index.rename('assets/sprites/hero.png', 'hero.jsprite'),
      throwsA(isA<FileSystemException>()),
      reason: 'taken',
    );
    await expectLater(
      index.rename('assets/sprites/hero.png', 'a/b.png'),
      throwsA(isA<FileSystemException>()),
    );
    expect(exists('assets/sprites/hero.png'), isTrue);
  });

  test('delete goes to the trash, and comes back', () async {
    final trashed = await index.trash('assets/sprites/hero.png');
    expect(exists('assets/sprites/hero.png'), isFalse);
    expect(index.entryAt('assets/sprites/hero.png'), isNull);
    expect(
      Directory('${dir.path}/${AssetIndex.trashFolder}').existsSync(),
      isTrue,
    );

    expect(await trashed.restore(), 'assets/sprites/hero.png');
    expect(
      File('${dir.path}/assets/sprites/hero.png').readAsStringSync(),
      'png-bytes',
    );

    // A folder too; and if its place was taken meanwhile, beside it.
    final folder = await index.trash('assets/audio');
    expect(exists('assets/audio'), isFalse);
    await index.newFolder('assets', name: 'audio');
    expect(await folder.restore(), 'assets/audio 2');
    expect(exists('assets/audio 2/jump.wav'), isTrue);
  });

  test('references are whole paths, and follow a rename', () async {
    expect(await AssetReferences.find(index, 'assets/sprites/hero.png'), [
      'assets/scenes/level_01.scene.json',
    ]);
    expect(await AssetReferences.find(index, 'assets/sprites/hero'), isEmpty);

    final changed = await AssetReferences.rewrite(
      index,
      'assets/sprites/hero.png',
      'assets/sprites/knight.png',
    );
    expect(changed, ['assets/scenes/level_01.scene.json']);
    final scene = File(
      '${dir.path}/assets/scenes/level_01.scene.json',
    ).readAsStringSync();
    expect(scene, contains('"assets/sprites/knight.png"'));
    expect(
      scene,
      contains('"assets/sprites/hero.png.bak"'),
      reason: 'untouched',
    );
  });

  test('a rename that only changes letter case works', () async {
    expect(
      await index.rename('assets/sprites/hero.png', 'Hero.png'),
      'assets/sprites/Hero.png',
    );
    final names = Directory(
      '${dir.path}/assets/sprites',
    ).listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(names, contains('Hero.png'));
    expect(names, isNot(contains('hero.png')));
    expect(
      File('${dir.path}/assets/sprites/Hero.png').readAsStringSync(),
      'png-bytes',
    );
  });

  test(
    'the indexed folder itself cannot be renamed, copied or trashed',
    () async {
      await expectLater(
        index.rename('assets', 'gone'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        index.trash('assets'),
        throwsA(isA<FileSystemException>()),
      );
      expect(exists('assets/sprites/hero.png'), isTrue);
    },
  );

  test('a scan asked for during another waits for a walk of its own', () async {
    final before = index.revision.value;
    final first = index.scan();
    // Made while the first walk may already have passed its folder.
    write('assets/sprites/late.png');
    final second = index.scan();
    final third = index.scan();
    expect(identical(second, third), isTrue, reason: 'folded into one pass');
    await second;
    expect(
      index.revision.value,
      greaterThanOrEqualTo(before + 2),
      reason: 'a second walk ran',
    );
    expect(index.entryAt('assets/sprites/late.png'), isNotNull);
    await first;
  });

  test('a scan still running when the index goes touches nothing', () async {
    final scanning = index.scan();
    index.dispose();
    await scanning; // no use of the disposed notifier, nothing thrown
  });

  test('a folder made while watching is watched too', () async {
    index.startWatching();
    Future<void> seen(String path) => waitUntil(
      () => index.entryAt(path) != null,
      what: '$path to be listed',
    );

    write('assets/levels/first.png');
    await seen('assets/levels/first.png');
    write('assets/levels/second.png');
    await seen('assets/levels/second.png');
  });
}
