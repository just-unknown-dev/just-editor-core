import 'package:flutter/foundation.dart';
import 'package:just_signals/just_signals.dart';

import 'overlay_settings_store.dart';
import 'overlay_ui_settings.dart';

/// A preference a module keeps in the editor's settings store, typed.
///
/// ```dart
/// static SettingPref<bool> get showWaves =>
///     SettingPref.boolean('mygame.showWaves', true);
/// final on = scope.prefs.get(showWaves);
/// ```
class SettingPref<T> {
  /// A preference of any type, kept under [key] as the text [encode] makes
  /// of it and read back with [decode]. The static helpers below make the
  /// common ones.
  const SettingPref(
    this.key, {
    required this.defaultValue,
    required this.encode,
    required this.decode,
  });

  /// A true/false preference, stored as `true` or `false`; anything else
  /// reads as false.
  static SettingPref<bool> boolean(String key, bool defaultValue) =>
      SettingPref(
        key,
        defaultValue: defaultValue,
        encode: (v) => v.toString(),
        decode: (raw) => raw == 'true',
      );

  /// A whole-number preference; a stored value that is not one reads as
  /// [defaultValue].
  static SettingPref<int> integer(String key, int defaultValue) => SettingPref(
    key,
    defaultValue: defaultValue,
    encode: (v) => v.toString(),
    decode: (raw) => int.tryParse(raw) ?? defaultValue,
  );

  /// A number preference; a stored value that is not a number reads as
  /// [defaultValue].
  static SettingPref<double> decimal(String key, double defaultValue) =>
      SettingPref(
        key,
        defaultValue: defaultValue,
        encode: (v) => v.toString(),
        decode: (raw) => double.tryParse(raw) ?? defaultValue,
      );

  /// A text preference, stored as it is.
  static SettingPref<String> text(String key, String defaultValue) =>
      SettingPref(
        key,
        defaultValue: defaultValue,
        encode: (v) => v,
        decode: (raw) => raw,
      );

  /// Namespaced: `'mygame.showWaves'`.
  final String key;

  /// What [EditorPrefs.get] gives while nothing is stored under [key].
  final T defaultValue;

  /// The text a value is stored as.
  final String Function(T value) encode;

  /// The value stored text stands for. It is handed whatever is stored
  /// under [key], so it should give a fallback for text it cannot read.
  final T Function(String raw) decode;
}

/// One editor's persisted preferences: the built-in overlay settings, typed,
/// and an open set of keys for whatever a module wants to remember.
///
/// Owned by the scope. Reads [store] once, when [load] is first called;
/// until it has, [settings] starts at the defaults and [get] gives a
/// preference's default unless it has been set since.
class EditorPrefs {
  EditorPrefs({required this.store});

  /// Where the preferences are read from and written to: the editor's own
  /// key-value store.
  final OverlaySettingsStore store;

  /// The built-in overlay settings. Watch it to rebuild on a change.
  final Signal<OverlayUiSettings> settings = Signal(
    const OverlayUiSettings.defaults(),
    debugLabel: 'overlaySettings',
  );

  bool _loaded = false;
  Future<void>? _loading;
  final Map<String, String> _raw = {};
  final Map<String, Signal<Object?>> _watched = {};

  /// Whether [load] has completed (successfully or not).
  bool get loaded => _loaded;

  /// Reads everything from the store, once; later calls await the first.
  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _loadOnce();
  }

  /// A change made while [load] was still reading: it wins over what was
  /// read, which is older.
  bool _changedWhileLoading = false;

  Future<void> _loadOnce() async {
    try {
      final loaded = await store.loadSettings();
      if (!_changedWhileLoading) settings.value = loaded;
      _raw.addAll(await store.readAll());
      for (final entry in _watched.entries) {
        if (_raw.containsKey(entry.key)) {
          entry.value.value = _raw[entry.key];
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to load editor preferences: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _loaded = true;
    }
  }

  /// Applies and persists [next].
  Future<void> update(OverlayUiSettings next) async {
    if (!_loaded) _changedWhileLoading = true;
    settings.value = next;
    try {
      await store.saveSettings(next);
    } catch (error, stackTrace) {
      debugPrint('Failed to save overlay settings: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Applies and persists what [change] makes of the settings as they are.
  Future<void> change(OverlayUiSettings Function(OverlayUiSettings s) change) =>
      update(change(settings.value));

  /// The stored value of [pref], or its default.
  T get<T>(SettingPref<T> pref) {
    final raw = _raw[pref.key];
    return raw == null ? pref.defaultValue : pref.decode(raw);
  }

  /// Stores [value] for [pref] and tells anyone watching.
  Future<void> set<T>(SettingPref<T> pref, T value) async {
    final raw = pref.encode(value);
    _raw[pref.key] = raw;
    _watched[pref.key]?.value = raw;
    try {
      await store.writeRaw(pref.key, raw);
    } catch (error) {
      debugPrint('Failed to save preference ${pref.key}: $error');
    }
  }

  /// A listenable view of [pref]'s decoded value.
  ValueListenable<T> watch<T>(SettingPref<T> pref) {
    final raw = _watched.putIfAbsent(
      pref.key,
      () => Signal<Object?>(_raw[pref.key]),
    );
    return _DecodedListenable(raw, pref);
  }

  /// Disposes [settings] and every view [watch] handed out; the scope calls
  /// it when it is disposed.
  void dispose() {
    settings.dispose();
    for (final n in _watched.values) {
      n.dispose();
    }
  }
}

class _DecodedListenable<T> extends ValueListenable<T> {
  const _DecodedListenable(this._raw, this._pref);
  final Signal<Object?> _raw;
  final SettingPref<T> _pref;

  @override
  T get value {
    final raw = _raw.value;
    return raw is String ? _pref.decode(raw) : _pref.defaultValue;
  }

  @override
  void addListener(VoidCallback listener) => _raw.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _raw.removeListener(listener);
}
