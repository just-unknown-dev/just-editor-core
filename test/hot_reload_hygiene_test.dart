// The kit, the theme and the sizes live here, so the rule the editor keeps
// for hot reload is checked here too: no style or definition is built once
// as a static final, where an edit or a theme change would never reach it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no style or definition is a static final', () {
    // Built once and never again: an edit to one would not show until a
    // restart, nor would a theme change. Each must be a getter.
    // A class's static, or a top-level declaration — not a local.
    final pattern = RegExp(
      r'^(?:  static final|final) (?:\w+ )?\w+ =\s*'
      r'(?:TextStyle|PrefabDefinition|WorkspaceDefinition|DockDefinition)\(',
      multiLine: true,
    );
    final readsTheme = RegExp(
      r'^(?:  static final|final) [^=;(\n]*=[^;]*EditorTheme\.',
      multiLine: true,
    );
    final offenders = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (pattern.hasMatch(file.readAsStringSync()) ||
              readsTheme.hasMatch(file.readAsStringSync()))
            file.path,
    ];
    expect(offenders, isEmpty);
  });
}
