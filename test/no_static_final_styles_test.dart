// What hot reload cannot refresh: a style, a definition or a vector built
// once into a static final. Each must be a getter (or a const), so an edit
// shows after a reload, a theme change reaches it, and nobody can change a
// shared value in place. The kit, the theme and the sizes live in this
// package, so the rule the editor keeps is checked here for all of lib/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A class's static, or a top-level declaration — not a local — built from
/// a style, a definition or a vector.
final RegExp _built = RegExp(
  r'^(?:  static final|final) (?:[\w.]+ )?\w+ =\s*(?:\w+\.)?'
  r'(?:TextStyle|PrefabDefinition|WorkspaceDefinition|DockDefinition|'
  r'EditorMarker|SettingPref|Vector2|Vector3)\(',
  multiLine: true,
);

/// A class's static, or a top-level declaration, that reads the theme once.
final RegExp _readsTheme = RegExp(
  r'^(?:  static final|final) [^=;(\n]*=[^;]*EditorTheme\.',
  multiLine: true,
);

void main() {
  test('no style, definition or shared vector is a static final', () {
    final offenders = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (_built.hasMatch(file.readAsStringSync()) ||
              _readsTheme.hasMatch(file.readAsStringSync()))
            file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('the check finds what it is for, and only that', () {
    // So a pattern broken by an edit does not pass everything.
    expect(_built.hasMatch('  static final title = TextStyle(\n'), isTrue);
    expect(_built.hasMatch('final up = jge.Vector3(0, 1, 0);\n'), isTrue);
    expect(
      _readsTheme.hasMatch('  static final ink = EditorTheme.text;\n'),
      isTrue,
    );
    expect(
      _built.hasMatch('  static TextStyle get title => TextStyle(\n'),
      isFalse,
    );
    expect(_built.hasMatch('    final local = TextStyle(\n'), isFalse);
  });
}
