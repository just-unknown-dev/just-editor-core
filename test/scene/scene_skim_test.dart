// The Scenes list reads a scene file's mode and how many entities it holds
// without decoding it. It must say what decoding it would: the same mode,
// the same count, and "unreadable" for the same files.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/src/scene/scene_skim.dart';

/// What decoding [text] says, as the Scenes list read it before.
({String? mode, int entityCount})? _decoded(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, dynamic>) return null;
  final entities = json['entities'];
  if (entities != null && entities is! List) return null;
  final mode = json['mode'];
  return (
    mode: mode is String ? mode : null,
    entityCount: (entities as List?)?.length ?? 0,
  );
}

void main() {
  final texts = <String>[
    // Scenes as saved.
    '{"name": "a", "mode": "3d", "entities": []}',
    jsonEncode({
      'name': 'level_01',
      'version': 11,
      'mode': '2d',
      'entities': [
        for (var i = 0; i < 20; i++)
          {
            'name': 'e$i',
            'parentName': i.isEven ? null : 'e${i - 1}',
            'enabled': i % 3 != 0,
            'components': [
              {
                'type': 'TransformComponent',
                'fields': {
                  'position': [i * 1.5, -2e-3, 1E+2],
                  'label': 'quote " backslash \\ tab \t é ✓ 𝄞',
                },
              },
            ],
          },
      ],
      'editor': {
        'guides': <Object?>[],
        'nested': [
          [[], {}],
          [],
        ],
      },
    }),
    const JsonEncoder.withIndent('  ').convert({
      'mode': '3d',
      'entities': [
        {'name': 'x'},
        [1, 2],
        'text',
        3,
        null,
        true,
      ],
    }),
    '\r\n {"entities" : [ ] , "mode":"3d" }\r\n',
    // Keys and modes written with escapes.
    r'{"mode": "3d", "entities": [1]}',
    // Repeated keys: the last counts.
    '{"mode": "3d", "entities": [1, 2], "mode": 4, "entities": [3]}',
    '{"entities": {}, "entities": [1]}',
    '{"entities": [1], "entities": {}}',
    // No entities, or none said.
    '{}',
    '{"mode": "3d"}',
    '{"entities": null}',
    // Not a scene.
    '[]',
    '"text"',
    '42',
    '{"entities": {}}',
    '{"entities": "many"}',
    '{"entities": 3}',
    // Not JSON at all.
    '',
    '   ',
    '{',
    '{"entities": [1, 2,]}',
    '{"entities": [1 2]}',
    '{"mode": "3d",}',
    "{'mode': '3d'}",
    '{"mode": "3d"} trailing',
    '{"mode": "3d"}{}',
    '{"mode" "3d"}',
    '{"a": 01}',
    '{"a": 1.}',
    '{"a": .5}',
    '{"a": -}',
    '{"a": 1e}',
    '{"a": +1}',
    '{"a": NaN}',
    '{"a": tru}',
    '{"a": nul}',
    '{"a": "unterminated}',
    '{"a": "bad \\x escape"}',
    '{"a": "bad \\u12G4"}',
    '{"a": "raw \n newline"}',
    '{"a": [}',
    '{"a": [1, {"b": ]}]}',
    '{"a": {"b" 1}}',
    '{"a": {1: 2}}',
    '﻿{"mode": "3d"}',
  ];

  test('says what decoding says, of every file', () {
    for (final text in texts) {
      expect(skimScene(text), _decoded(text), reason: text);
    }
  });

  test('a file nested deeper than calls would go is still read', () {
    final deep = '${'[' * 20000}${']' * 20000}';
    expect(skimScene('{"entities": [$deep, 1]}'), (mode: null, entityCount: 2));
  });
}
