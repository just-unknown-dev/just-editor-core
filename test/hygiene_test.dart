// What hot reload cannot refresh: a style, a definition or a vector built
// once into a static final. Each must be a getter (or a const), so an edit
// shows after a reload and nobody can change a shared value in place.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no style, definition or shared vector is a static final', () {
    // A class's static, or a top-level declaration — not a local.
    final built = RegExp(
      r'^(?:  static final|final) (?:[\w.]+ )?\w+ =\s*(?:\w+\.)?'
      r'(?:TextStyle|PrefabDefinition|WorkspaceDefinition|DockDefinition|'
      r'EditorMarker|SettingPref|Vector2|Vector3)\(',
      multiLine: true,
    );
    final readsTheme = RegExp(
      r'^(?:  static final|final) [^=;(\n]*=[^;]*EditorTheme\.',
      multiLine: true,
    );
    final offenders = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (built.hasMatch(file.readAsStringSync()) ||
              readsTheme.hasMatch(file.readAsStringSync()))
            file.path,
    ];
    expect(offenders, isEmpty);
  });
}
