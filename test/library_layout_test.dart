// How lib/ is laid out (CONTRIBUTING.md, "How the Package Fits Together"),
// checked from the directives of every file:
// - every file under a top-level folder of lib/src is exported by a public
//   library — through its folder's barrel — or is internal: each of its
//   public declarations is `@internal`;
// - only a folder's barrel or a public library exports a file of this
//   package, and a barrel only its own folder; a library that holds parts
//   is not a barrel;
// - no file imports a barrel that leads back to it;
// - the kernel (`EditorScope`) imports no feature;
// - no import loop crosses from one feature (a top-level folder of
//   lib/src) to another, and no feature imports one in a layer above its
//   own;
// - kit.dart needs no engine: its closure is Flutter and just_signals;
// - only the `dart:io` seam and the native halves (`*_io.dart`) import
//   `dart:io`.
// Adapted from just_game_engine's test/library_layout_test.dart.
// Untagged: it only reads files.

import 'dart:io';
import 'dart:math' show min;

import 'package:flutter_test/flutter_test.dart';

/// The public libraries, under lib/.
const _public = ['just_editor_core.dart', 'host.dart', 'kit.dart', 'io.dart'];

/// Files no public library exports and that are not `@internal` either,
/// with why. Empty: an internal helper says so on its declarations.
const Map<String, String> _internalByList = {};

/// What the kernel — `src/scope/` — may import from the rest of lib/src:
/// the leaves below it.
const _kernelMayImport = [
  'src/scope/',
  'src/io/',
  'src/input/',
  'src/settings/',
  'src/log/',
  'src/look/',
];

/// The packages the kernel may import.
const _kernelPackages = [
  'dart:',
  'package:flutter/',
  'package:meta/',
  'package:just_game_engine/',
  'package:just_di/',
  'package:just_signals/',
  'package:just_debugger/',
  'package:just_storage/',
];

/// The features — the top-level folders of lib/src — in layers, bottom to
/// top, as CONTRIBUTING.md lists them. A feature imports features in its
/// own layer or below, never above; within a layer imports go one way only
/// (no loops). A new top-level folder takes its place here.
const _layers = [
  // Leaves: files, keys, views, settings, the log.
  ['io', 'input', 'view', 'settings', 'log'],
  // The look and the UI kit.
  ['look'],
  // The kernel every feature takes.
  ['scope'],
  // The project's files.
  ['assets'],
  // The open scene; the project's own files.
  ['scene', 'project'],
  // Undo over the scene.
  ['history'],
  // What modules build on: the Level Designer, the inspector, the tree.
  ['designer', 'inspector', 'scene_tree'],
  // The composition root: the module contract and its wiring.
  ['modules'],
];

/// What kit.dart's closure may import from outside this package.
const _kitPackages = ['dart:', 'package:flutter/', 'package:just_signals/'];

final _directive = RegExp(
  r'^[ \t]*(import|export|part[ \t]+of|part)\b([^;]*);',
  multiLine: true,
);
final _uri = RegExp(r"'([^']+)'");

/// One `import`, `export`, `part` or `part of` of a file, resolved.
final class _Directive {
  _Directive(this.kind, this.uri, this.target);

  final String kind;
  final String uri;

  /// The file it names, relative to lib/; null for another package's.
  final String? target;
}

/// A file under lib/: its path from lib/, text and directives.
final class _File {
  _File(this.path, this.text, this.directives);

  final String path;
  final String text;
  final List<_Directive> directives;

  Iterable<_Directive> of(String kind) =>
      directives.where((d) => d.kind == kind);

  /// The library it is part of, or itself.
  String get library =>
      of('part of').map((d) => d.target).nonNulls.firstOrNull ?? path;

  bool get holdsParts => of('part').isNotEmpty;

  /// A top-level folder's barrel: `src/<folder>/<folder>.dart`.
  bool get isBarrel {
    final parts = path.split('/');
    return parts.length == 3 &&
        parts[0] == 'src' &&
        parts[2] == '${parts[1]}.dart';
  }

  bool get isPublic => _public.contains(path);
}

String? _resolve(String from, String uri) {
  if (uri.startsWith('package:just_editor_core/')) {
    return uri.substring('package:just_editor_core/'.length);
  }
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
  final segments = from.split('/')..removeLast();
  for (final s in uri.split('/')) {
    if (s == '..') {
      segments.removeLast();
    } else if (s != '.') {
      segments.add(s);
    }
  }
  return segments.join('/');
}

/// Every Dart file under lib/, by path from lib/.
Map<String, _File> _readLib() {
  final root = Directory('lib');
  final files = <String, _File>{};
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final path = f.path.substring(root.path.length + 1).replaceAll(r'\', '/');
    var text = f.readAsStringSync();
    if (text.startsWith('﻿')) text = text.substring(1);
    files[path] = _File(path, text, [
      for (final m in _directive.allMatches(text))
        for (final u in _uri.allMatches(m.group(2)!))
          _Directive(
            m.group(1)!.replaceAll(RegExp(r'\s+'), ' '),
            u.group(1)!,
            _resolve(path, u.group(1)!),
          ),
    ]);
  }
  return files;
}

/// What [from] exports, itself included, following exports onward.
Set<String> _exportedFrom(Map<String, _File> files, Iterable<String> from) {
  final seen = <String>{};
  final stack = [...from];
  while (stack.isNotEmpty) {
    final path = stack.removeLast();
    if (!seen.add(path)) continue;
    for (final d in files[path]?.of('export') ?? const <_Directive>[]) {
      if (d.target != null) stack.add(d.target!);
    }
  }
  return seen;
}

/// Every file [from] reaches through its imports and exports, itself
/// included, and every other package's library on the way.
({Set<String> files, Set<String> packages}) _closure(
  Map<String, _File> files,
  String from,
) {
  final seen = <String>{};
  final packages = <String>{};
  final stack = [from];
  while (stack.isNotEmpty) {
    final path = stack.removeLast();
    if (!seen.add(path)) continue;
    final file = files[path];
    if (file == null) continue;
    for (final d in [...file.of('import'), ...file.of('export')]) {
      if (d.target != null) {
        stack.add(d.target!);
      } else {
        packages.add(d.uri);
      }
    }
  }
  return (files: seen, packages: packages);
}

final _typeDeclaration = RegExp(
  r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*'
  r'(?:class|mixin|enum|typedef|extension\s+type|extension)\s+([A-Za-z_]\w*)',
);

/// The public top-level declarations of [text]: their line and name, and
/// whether `@internal` is among their annotations.
List<({int line, String name, bool internal})> _publicDeclarations(
  String text,
) {
  final lines = text.split('\n');
  final found = <({int line, String name, bool internal})>[];
  var depth = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    if (depth == 0 &&
        line.isNotEmpty &&
        !line.startsWith(RegExp(r'[\s/*@})\]]')) &&
        !line.startsWith(RegExp(r'(import|export|part|library)\b')) &&
        !line.startsWith(RegExp(r'extension\s+on\b'))) {
      final type = _typeDeclaration.firstMatch(line);
      String? name;
      if (type != null) {
        name = type.group(1);
      } else {
        // A function or variable: the last name before its parameters or
        // value, past any type arguments of its own.
        final head = line
            .split(RegExp(r'[(=;{]'))
            .first
            .trim()
            .replaceFirst(RegExp(r'<[^<>]*>$'), '');
        name = RegExp(r'[A-Za-z_]\w*').allMatches(head).lastOrNull?.group(0);
      }
      if (name != null && !name.startsWith('_')) {
        var internal = false;
        for (var j = i - 1; j >= 0; j--) {
          final above = lines[j].trim();
          if (above.startsWith('@')) {
            internal |= RegExp(r'^@internal\b').hasMatch(above);
          } else if (!above.startsWith('///')) {
            break;
          }
        }
        found.add((line: i + 1, name: name, internal: internal));
      }
    }
    // Brace depth, outside strings and comments, so only top-level lines
    // are read as declarations.
    final code = line
        .replaceAll(RegExp(r"'(?:[^'\\]|\\.)*'"), '')
        .replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '')
        .split('//')
        .first;
    depth += '{'.allMatches(code).length - '}'.allMatches(code).length;
    if (depth < 0) depth = 0;
  }
  return found;
}

/// The feature a file under lib/ belongs to — its top-level folder of
/// lib/src — or null for a public library.
String? _featureOf(String path) {
  final parts = path.split('/');
  return parts.length > 2 && parts[0] == 'src' ? parts[1] : null;
}

/// Every import and export from one feature to another (parts are inside
/// their library's), by (from, to): the directives that make it.
Map<(String, String), List<String>> _featureEdges(Map<String, _File> files) {
  final edges = <(String, String), List<String>>{};
  for (final file in files.values) {
    final from = _featureOf(file.path);
    if (from == null) continue;
    for (final d in [...file.of('import'), ...file.of('export')]) {
      final target = d.target;
      final to = target == null ? null : _featureOf(target);
      if (to == null || to == from) continue;
      (edges[(from, to)] ??= []).add('${file.path} ${d.kind}s ${d.uri}');
    }
  }
  return edges;
}

/// The loops of [graph]: its strongly connected parts of more than one
/// node, each sorted (Tarjan's algorithm).
List<List<String>> _loops(Map<String, Set<String>> graph) {
  final index = <String, int>{};
  final low = <String, int>{};
  final stack = <String>[];
  final onStack = <String>{};
  final loops = <List<String>>[];
  var next = 0;
  void visit(String v) {
    index[v] = low[v] = next++;
    stack.add(v);
    onStack.add(v);
    for (final w in graph[v] ?? const <String>{}) {
      if (!index.containsKey(w)) {
        visit(w);
        low[v] = min(low[v]!, low[w]!);
      } else if (onStack.contains(w)) {
        low[v] = min(low[v]!, index[w]!);
      }
    }
    if (low[v] != index[v]) return;
    final loop = <String>[];
    String w;
    do {
      w = stack.removeLast();
      onStack.remove(w);
      loop.add(w);
    } while (w != v);
    if (loop.length > 1) loops.add(loop..sort());
  }

  final nodes = {...graph.keys, for (final to in graph.values) ...to}.toList()
    ..sort();
  for (final v in nodes) {
    if (!index.containsKey(v)) visit(v);
  }
  return loops;
}

void main() {
  final files = _readLib();
  final exported = _exportedFrom(files, _public);

  test('every file is exported by a public library or is internal', () {
    final problems = <String>[];
    for (final file in files.values) {
      if (!file.path.startsWith('src/')) continue;
      if (exported.contains(file.library)) continue;
      if (_internalByList.containsKey(file.library)) continue;
      for (final d in _publicDeclarations(file.text)) {
        if (!d.internal) {
          problems.add(
            '${file.path}:${d.line} ${d.name} — exported by no public '
            'library: export it from its barrel, or mark it @internal',
          );
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('the explicit internal list names files that exist', () {
    expect([
      for (final path in _internalByList.keys)
        if (!files.containsKey(path)) path,
    ], isEmpty);
  });

  test('only a barrel or a public library exports, a barrel only its '
      'own folder', () {
    final problems = <String>[];
    for (final file in files.values) {
      // Re-exporting another package's library is no barrel's business:
      // the io seam's native half re-exports `dart:io`, its whole job.
      final exports = file.of('export').where((d) => d.target != null);
      if (exports.isEmpty || file.isPublic) continue;
      if (!file.isBarrel) {
        problems.add('${file.path} exports, but is not a barrel');
        continue;
      }
      final folder = '${file.path.substring(0, file.path.lastIndexOf('/'))}/';
      for (final d in exports) {
        if (!d.target!.startsWith(folder)) {
          problems.add('${file.path} exports ${d.uri}, outside its folder');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('every top-level folder has its barrel', () {
    final folders = files.keys.map(_featureOf).nonNulls.toSet();
    expect([
      for (final f in folders)
        if (!files.containsKey('src/$f/$f.dart')) '$f has no $f.dart',
    ], isEmpty);
  });

  test('a library that holds parts is not a barrel', () {
    expect([
      for (final file in files.values)
        if (file.holdsParts && file.of('export').isNotEmpty) file.path,
    ], isEmpty);
  });

  test('no file imports a barrel that leads back to it', () {
    final problems = <String>[];
    for (final file in files.values) {
      for (final d in file.of('import')) {
        final target = d.target;
        if (target == null || files[target]?.of('export').isEmpty != false) {
          continue;
        }
        final reached = _exportedFrom(files, [target]);
        if (reached.contains(file.library) && target != file.library) {
          problems.add('${file.path} imports ${d.uri}, which exports it');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('the kernel imports no feature', () {
    final problems = <String>[];
    for (final file in files.values) {
      if (!file.path.startsWith('src/scope/')) continue;
      for (final d in [...file.of('import'), ...file.of('export')]) {
        final target = d.target;
        final ok = target == null
            ? _kernelPackages.any(d.uri.startsWith)
            : _kernelMayImport.any(target.startsWith);
        if (!ok) problems.add('${file.path} imports ${d.uri}');
      }
    }
    expect(problems, isEmpty);
  });

  final features = _featureEdges(files);
  final layerOf = {
    for (var i = 0; i < _layers.length; i++)
      for (final feature in _layers[i]) feature: i,
  };

  test('every feature has one layer, and every layer names a feature', () {
    final folders = files.keys.map(_featureOf).nonNulls.toSet();
    final listed = [for (final layer in _layers) ...layer];
    expect([
      for (final f in folders)
        if (!listed.contains(f)) '$f has no layer',
      for (final f in listed.toSet())
        if (listed.where((l) => l == f).length > 1) '$f is in two layers',
      for (final f in listed)
        if (!folders.contains(f)) '$f is no folder of lib/src',
    ], isEmpty);
  });

  test('no import loop crosses from one feature to another', () {
    final graph = <String, Set<String>>{};
    for (final (from, to) in features.keys) {
      (graph[from] ??= {}).add(to);
    }
    final problems = <String>[];
    for (final loop in _loops(graph)) {
      problems.add('a loop of ${loop.join(', ')}:');
      for (final MapEntry(key: (from, to), value: why) in features.entries) {
        if (loop.contains(from) && loop.contains(to)) {
          problems.addAll(['  $from -> $to', for (final w in why) '    $w']);
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('no feature imports one in a layer above its own', () {
    expect([
      for (final MapEntry(key: (from, to), value: why) in features.entries)
        if ((layerOf[to] ?? -1) > (layerOf[from] ?? _layers.length))
          for (final w in why)
            '$from (layer ${layerOf[from]}) imports $to '
                '(layer ${layerOf[to]}): $w',
    ], isEmpty);
  });

  test('kit.dart needs no engine: Flutter and just_signals only', () {
    final kit = _closure(files, 'kit.dart');
    expect(kit.files, isNot(contains('src/scope/editor_scope.dart')));
    expect([
      for (final uri in kit.packages)
        if (!_kitPackages.any(uri.startsWith)) uri,
    ], isEmpty);
  });

  test('only the io seam and the native halves import dart:io', () {
    expect([
      for (final file in files.values)
        if ([
              ...file.of('import'),
              ...file.of('export'),
            ].any((d) => d.uri == 'dart:io') &&
            file.path != 'src/io/io_native.dart' &&
            !file.path.endsWith('_io.dart'))
          file.path,
    ], isEmpty);
  });

  test('the scanner reads declarations and their annotations', () {
    final found = _publicDeclarations('''
/// Doc.
@internal
final class Kept {
  void method() {}
  static const x = 1;
}

class Plain {}

@internal
Future<int> load() async => 1;

const int limit = 3;

T pick<T>(T a) => a;

extension on int {}

final class _Hidden {}
''');
    expect(found.map((d) => '${d.name}:${d.internal}'), [
      'Kept:true',
      'Plain:false',
      'load:true',
      'limit:false',
      'pick:false',
    ]);
  });
}
