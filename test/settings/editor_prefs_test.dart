// A module's preference is a typed key in the editor's own store: read
// once, written on every change, watched. One set while the store is
// still being read keeps its value — it is newer than what was read.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';
import 'package:just_storage/just_storage.dart';

import '../support/memory_settings_store.dart';

/// [MemorySettingsStore], whose read of the raw values takes what is
/// stored when it starts and finishes only when the test says.
class _SlowStore extends MemorySettingsStore {
  final Completer<void> reading = Completer<void>();
  final Completer<void> gate = Completer<void>();

  @override
  Future<Map<String, String>> readAll() async {
    final read = Map.of(values);
    reading.complete();
    await gate.future;
    return read;
  }
}

/// A store on a real storage in memory, counting how often it is read.
class _CountingStorage implements JustStandardStorage {
  final Map<String, String> values = {};
  int reads = 0;

  @override
  Future<Map<String, String>> readAll() async {
    reads++;
    return Map.of(values);
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _waves = SettingPref.boolean('test.showWaves', false);

void main() {
  test('a preference reads its default until loaded, then what was '
      'stored, and is written and heard on every change', () async {
    final store = MemorySettingsStore()..values['test.showWaves'] = 'true';
    final prefs = EditorPrefs(store: store);
    addTearDown(prefs.dispose);

    expect(prefs.get(_waves), isFalse, reason: 'the default before load');
    final watched = prefs.watch(_waves);
    await prefs.load();
    expect(prefs.get(_waves), isTrue);
    expect(watched.value, isTrue);

    var heard = 0;
    watched.addListener(() => heard++);
    await prefs.set(_waves, false);
    expect(prefs.get(_waves), isFalse);
    expect(store.values['test.showWaves'], 'false');
    expect(heard, 1);

    await prefs.update(prefs.settings.value.copyWith(gridSize: 48));
    expect(store.saved.gridSize, 48);
  });

  test('one set while the store is still read keeps the value it was set '
      'to', () async {
    final store = _SlowStore()..values['test.showWaves'] = 'false';
    final prefs = EditorPrefs(store: store);
    addTearDown(prefs.dispose);
    final watched = prefs.watch(_waves);

    final loading = prefs.load();
    await store.reading.future;
    // A module remembering a toggle as it registers, while the store is
    // read: what the read gives is older.
    await prefs.set(_waves, true);
    store.gate.complete();
    await loading;

    expect(prefs.get(_waves), isTrue, reason: 'newer than what was read');
    expect(watched.value, isTrue);
    expect(store.values['test.showWaves'], 'true');
  });

  test('the store is read once to load', () async {
    final storage = _CountingStorage()
      ..values['test.showWaves'] = 'true'
      ..values['editor.grid.size'] = '48';
    final store = OverlaySettingsStore(Future.value(storage));
    final prefs = EditorPrefs(store: store);
    addTearDown(prefs.dispose);
    await prefs.load();
    expect(storage.reads, 1);
    expect(prefs.get(_waves), isTrue);
  });
}
