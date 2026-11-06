// What uses an asset — a file, or a whole folder — in every kind of project
// file that names one, and those names following a rename, with the files
// as they were kept aside first.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  late Directory dir;
  late AssetIndex index;

  void write(String path, String content) => File('${dir.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  String read(String path) => File('${dir.path}/$path').readAsStringSync();

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('asset_references');
    write('assets/sprites/hero.png', 'png');
    write('assets/sprites/coin.png', 'png');
    write(
      'assets/sprites/hero.animator.json',
      '{"atlas": "assets/sprites/hero.json"}',
    );
    write('assets/sprites/hero.json', '{"image": "assets/sprites/hero.png"}');
    write(
      'assets/sprites/hero.jsprite',
      '{"sheet": "assets/sprites/hero.png"}',
    );
    write(
      'assets/scenes/level_01.scene.json',
      '{"a": "assets/sprites/hero.png", "b": "assets/spritesheet.png"}',
    );
    write('assets/audio/jump.wav', 'wav');
    write('assets/tilesets/grassland.png', 'png');
    write(
      'assets/tilesets/grassland.tsx',
      '<tileset name="g"><image source="grassland.png" width="8"/></tileset>',
    );
    write(
      'assets/maps/level.tmx',
      '<map><tileset firstgid="1" source="../tilesets/grassland.tsx"/>'
          '<tileset firstgid="9" source="../maps/inner.tsx"/></map>',
    );
    write('assets/maps/inner.tsx', '<tileset name="inner"/>');
    write(
      'lib/game/audio.dart',
      "const jump = 'assets/audio/jump.wav';\n"
          'const music = "assets/audio/music.wav";\n',
    );
    write(
      'pubspec.yaml',
      'name: game\n'
          'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n'
          'flutter:\n'
          '  assets:\n'
          '    - assets/sprites/\n'
          '    - "assets/audio/jump.wav"  # the jump\n'
          '    - assets/tilesets/\n',
    );
    index = AssetIndex(projectRoot: dir.path);
    await index.scan();
  });

  tearDown(() {
    index.dispose();
    dir.deleteSync(recursive: true);
  });

  List<String> backups() {
    final root = Directory('${dir.path}/${AssetReferences.backupFolder}');
    if (!root.existsSync()) return const [];
    return [
      for (final f in root.listSync(recursive: true))
        if (f is File)
          f.path
              .replaceAll(r'\', '/')
              .substring(root.path.replaceAll(r'\', '/').length + 1)
              .split('/')
              .skip(1)
              .join('/'),
    ]..sort();
  }

  test('a folder is used by every file naming a path under it', () async {
    expect(await AssetReferences.find(index, 'assets/sprites'), [
      'assets/scenes/level_01.scene.json',
      'assets/sprites/hero.animator.json',
      'assets/sprites/hero.json',
      'assets/sprites/hero.jsprite',
      'pubspec.yaml',
    ]);
  });

  test('renaming a folder points every path under it at the new one, and '
      'keeps the files as they were', () async {
    final before = read('assets/scenes/level_01.scene.json');
    await Directory(
      '${dir.path}/assets/sprites',
    ).rename('${dir.path}/assets/chars');
    await index.scan();

    final changed = await AssetReferences.rewrite(
      index,
      'assets/sprites',
      'assets/chars',
    );
    expect(changed..sort(), [
      'assets/chars/hero.animator.json',
      'assets/chars/hero.json',
      'assets/chars/hero.jsprite',
      'assets/scenes/level_01.scene.json',
      'pubspec.yaml',
    ]);
    expect(
      read('assets/scenes/level_01.scene.json'),
      '{"a": "assets/chars/hero.png", "b": "assets/spritesheet.png"}',
    );
    expect(
      read('assets/chars/hero.animator.json'),
      '{"atlas": "assets/chars/hero.json"}',
    );
    expect(read('pubspec.yaml'), contains('    - assets/chars/\n'));
    expect(read('pubspec.yaml'), contains('    - assets/tilesets/\n'));

    // As they were, aside.
    expect(backups(), [
      'assets/chars/hero.animator.json',
      'assets/chars/hero.json',
      'assets/chars/hero.jsprite',
      'assets/scenes/level_01.scene.json',
      'pubspec.yaml',
    ]);
    final kept = Directory(
      '${dir.path}/${AssetReferences.backupFolder}',
    ).listSync().single.path;
    expect(
      File('$kept/assets/scenes/level_01.scene.json').readAsStringSync(),
      before,
    );
    // Whole writes: nothing half-done left beside them.
    expect(
      Directory(
        dir.path,
      ).listSync(recursive: true).where((f) => f.path.endsWith('.saving')),
      isEmpty,
    );
  });

  test("the game's code and the pubspec name files too", () async {
    expect(await AssetReferences.find(index, 'assets/audio/jump.wav'), [
      'lib/game/audio.dart',
      'pubspec.yaml',
    ]);
    await File(
      '${dir.path}/assets/audio/jump.wav',
    ).rename('${dir.path}/assets/audio/boing.wav');
    await index.scan();
    expect(
      await AssetReferences.rewrite(
        index,
        'assets/audio/jump.wav',
        'assets/audio/boing.wav',
      ),
      ['lib/game/audio.dart', 'pubspec.yaml'],
    );
    expect(read('lib/game/audio.dart'), contains("'assets/audio/boing.wav'"));
    expect(
      read('lib/game/audio.dart'),
      contains('"assets/audio/music.wav"'),
      reason: 'untouched',
    );
    expect(
      read('pubspec.yaml'),
      contains('    - "assets/audio/boing.wav"  # the jump\n'),
    );
  });

  test("Tiled files name what they use relative to themselves", () async {
    expect(await AssetReferences.find(index, 'assets/tilesets/grassland.png'), [
      'assets/tilesets/grassland.tsx',
    ]);
    expect(await AssetReferences.find(index, 'assets/tilesets'), [
      'assets/maps/level.tmx',
      'assets/tilesets/grassland.tsx',
      'pubspec.yaml',
    ]);

    await File(
      '${dir.path}/assets/tilesets/grassland.png',
    ).rename('${dir.path}/assets/tilesets/meadow.png');
    await index.scan();
    await AssetReferences.rewrite(
      index,
      'assets/tilesets/grassland.png',
      'assets/tilesets/meadow.png',
    );
    expect(
      read('assets/tilesets/grassland.tsx'),
      contains('source="meadow.png"'),
    );

    // The map's folder renamed: what it names in its own folder by a way
    // through that folder's name follows; the rest still resolves.
    await Directory(
      '${dir.path}/assets/maps',
    ).rename('${dir.path}/assets/levels');
    await index.scan();
    expect(
      await AssetReferences.rewrite(index, 'assets/maps', 'assets/levels'),
      ['assets/levels/level.tmx'],
    );
    final map = read('assets/levels/level.tmx');
    expect(map, contains('source="../tilesets/grassland.tsx"'));
    expect(map, contains('source="inner.tsx"'));
  });

  test('a file that only looks the same is left alone', () async {
    expect(await AssetReferences.find(index, 'assets/sprites/hero'), isEmpty);
    expect(
      await AssetReferences.find(index, 'assets/sprites/coin.png'),
      isEmpty,
    );
  });
}
