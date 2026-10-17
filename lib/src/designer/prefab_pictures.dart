import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../settings/editor_prefs.dart';
import 'prefab_registry.dart';

/// Draws [prefab]'s picture for the palette — a shape seen from above at
/// an angle, a model's thumbnail — [size] pixels square; null when it has
/// none, and the palette shows its icon (see `EditorModule.prefabPictures`).
typedef PrefabPicture = Widget? Function(PrefabDefinition prefab, double size);

/// The prefabs an author has marked as favourites, listed first in the
/// palette. Per user, kept in the editor's preferences, by prefab id.
abstract final class PrefabFavourites {
  /// Where they are kept.
  static final SettingPref<Set<String>> pref = SettingPref(
    'editor.designer.favouritePrefabs',
    defaultValue: const {},
    encode: (ids) => ids.join('\n'),
    decode: (raw) => {
      for (final id in raw.split('\n'))
        if (id.isNotEmpty) id,
    },
  );

  /// The favourites, to rebuild on a change.
  static ValueListenable<Set<String>> watch(EditorPrefs prefs) =>
      prefs.watch(pref);

  /// Marks [id] a favourite, or no longer one.
  static Future<void> toggle(EditorPrefs prefs, String id) {
    final ids = {...prefs.get(pref)};
    if (!ids.remove(id)) ids.add(id);
    return prefs.set(pref, ids);
  }
}
