// Where asset keys may be written: never outside the project or the package
// a key names — a path read out of a scene cannot reach a file elsewhere —
// and never into pub's cache or the Flutter SDK.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  late String root;

  void write(String path, String content) => File('$root/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('asset_paths_');
    addTearDown(() => dir.deleteSync(recursive: true));
    root = dir.path.replaceAll(r'\', '/');
    write(
      'packages/knight/pubspec.yaml',
      'name: knight\nflutter:\n  assets:\n    - sprites/\n',
    );
    write(
      'sdk/packages/flutter_assets_pkg/pubspec.yaml',
      'name: sdkpkg\nflutter:\n  assets:\n    - icons/\n',
    );
    write(
      '.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'flutterRoot': Uri.directory('$root/sdk').toString(),
        'packages': [
          {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
          {
            'name': 'knight',
            'rootUri': '../packages/knight',
            'packageUri': 'lib/',
          },
          {
            'name': 'sdkpkg',
            'rootUri': '../sdk/packages/flutter_assets_pkg',
            'packageUri': 'lib/',
          },
        ],
      }),
    );
    write(
      'just_store.lock.json',
      jsonEncode({
        'items': {
          'escaped': {'path': '../../somewhere/else'},
        },
      }),
    );
  });

  test('a key that leaves the project or its package is never writable', () {
    final paths = PackageAssetPaths.of(root);
    expect(paths.isWritable('assets/timelines/intro.timeline.json'), isTrue);
    expect(paths.isWritable('packages/knight/sprites/a.tileset.json'), isTrue);
    for (final key in [
      '../../Documents/notes.timeline.json',
      'assets/../../outside.json',
      r'assets\..\..\outside.json',
      '/etc/passwd',
      'C:/Windows/win.ini',
      'packages/knight/../../outside.json',
      'packages/knight/../other/x.json',
    ]) {
      expect(paths.isWritable(key), isFalse, reason: key);
    }
  });

  test('a lockfile item outside the project is no package', () {
    final paths = PackageAssetPaths.of(root);
    expect(paths.packages.containsKey('escaped'), isFalse);
  });

  test("the Flutter SDK's packages are read-only, as pub's cache is", () {
    final paths = PackageAssetPaths.of(root);
    expect(paths.packages['sdkpkg']?.assetFolders, ['icons/']);
    expect(paths.isWritable('packages/sdkpkg/icons/a.png'), isFalse);
    expect(paths.isWritable('packages/knight/sprites/a.png'), isTrue);
  });
}
