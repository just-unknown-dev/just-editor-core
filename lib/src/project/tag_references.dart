/// Where tags are used in saved files, and rewriting them.
library;

import 'package:just_game_engine/just_game_engine.dart' as jge;

/// Whether an entity carries the tag, or something points at it.
enum TagUseKind {
  /// In an entity's tag list.
  carried,

  /// Named by a field or a timeline binding: a camera following `#player`.
  reference,
}

/// One place a tag is used in a saved scene or timeline.
class TagUse {
  const TagUse({
    required this.tag,
    required this.kind,
    required this.owner,
    required this.where,
  });

  /// The tag's name, without the `#`.
  final String tag;

  /// Whether the tag is carried there or pointed at.
  final TagUseKind kind;

  /// The entity's name, or the timeline's file.
  final String owner;

  /// What uses it: `Tag`, `Virtual Camera › Follow`, `track binding`.
  final String where;

  @override
  String toString() => '$owner: $where (#$tag)';
}

/// Finds, renames and removes tags in saved scene, prefab and timeline JSON.
///
/// It knows nothing about particular components: a field is a tag if its
/// definition says so — a `tagList`, a `tagRef`, an `entityTarget` naming a
/// tag, or an item key of a list with those [jge.FieldHint.itemKinds] — and
/// a timeline track binding (`{"binding": {"tag": …}}`, or the short
/// `"#tag"`) is one wherever it sits, inline timelines included. So a
/// package's own components are covered the moment their fields use those
/// types.
///
/// A prefab file (`*.prefab.json`) lists its entities as a scene does, so
/// the scene calls ([inScene], [renameInScene], [removeFromScene]) take
/// one too; in either, an instance of a prefab is walked for what it
/// changes — the fields it overrides and the components it adds.
///
/// Rewrites happen in place, on JSON the caller owns.
class TagReferences {
  TagReferences(this.definitionByType);

  /// The definition saved under a component `type`, or null.
  final jge.ComponentDefinition? Function(String type) definitionByType;

  static const String _tagList = 'tagList';
  static const String _tagRef = 'tagRef';
  static const String _target = 'entityTarget';

  // ── Scenes ───────────────────────────────────────────────────────────────

  /// Every use of a tag in [scene] — of [tag] only, when given.
  List<TagUse> inScene(Map<String, dynamic> scene, {String? tag}) {
    final out = <TagUse>[];
    _visitScene(scene, (use, _) {
      if (tag == null || use.tag == tag) out.add(use);
      return null;
    });
    return out;
  }

  /// Renames [from] to [to] everywhere in [scene]. An entity that already
  /// carried [to] keeps one. Returns how many places changed.
  int renameInScene(Map<String, dynamic> scene, String from, String to) =>
      _visitScene(scene, (use, _) => use.tag == from ? to : null);

  /// Takes [tag] off every entity in [scene]. What points at it is left:
  /// the Problems dock lists it. Returns how many entities changed.
  int removeFromScene(Map<String, dynamic> scene, String tag) => _visitScene(
    scene,
    (use, _) => use.tag == tag && use.kind == TagUseKind.carried ? '' : null,
  );

  // ── Timelines ────────────────────────────────────────────────────────────

  /// Every track binding naming a tag in a timeline file.
  List<TagUse> inTimeline(
    Map<String, dynamic> timeline, {
    required String file,
    String? tag,
  }) {
    final out = <TagUse>[];
    _visitBindings(timeline, (value) {
      if (tag == null || value == tag) {
        out.add(
          TagUse(
            tag: value,
            kind: TagUseKind.reference,
            owner: file,
            where: 'track binding',
          ),
        );
      }
      return null;
    });
    return out;
  }

  /// Renames [from] to [to] in a timeline's bindings.
  int renameInTimeline(Map<String, dynamic> timeline, String from, String to) =>
      _visitBindings(timeline, (value) => value == from ? to : null);

  // ── One component ───────────────────────────────────────────────────────

  /// Every use in one component's saved `{type, fields}` JSON.
  List<TagUse> inComponent(Map component, {required String owner}) {
    final out = <TagUse>[];
    _visitComponent(component, owner, (use, _) {
      out.add(use);
      return null;
    });
    return out;
  }

  /// [renameInScene] for one component's saved JSON.
  int renameInComponent(Map component, String from, String to) =>
      _visitComponent(component, '', (use, _) => use.tag == from ? to : null);

  /// [removeFromScene] for one component's saved JSON.
  int removeFromComponent(Map component, String tag) => _visitComponent(
    component,
    '',
    (use, _) => use.tag == tag && use.kind == TagUseKind.carried ? '' : null,
  );

  // ── The walk ─────────────────────────────────────────────────────────────

  /// Calls [visit] for each use; a non-null answer replaces the tag there
  /// (empty removes it, where that is possible). Returns the replacements.
  ///
  /// Walks a scene's entities, and a prefab file's (`*.prefab.json`), which
  /// are listed the same way: each one's components, and — for an instance
  /// of a prefab — what the instance changes in it.
  int _visitScene(
    Map<String, dynamic> scene,
    String? Function(TagUse use, Object? json) visit,
  ) {
    var changed = 0;
    final entities = scene['entities'];
    if (entities is! List) return 0;
    for (final entity in entities.whereType<Map>()) {
      final owner = '${entity['name'] ?? '(unnamed)'}';
      final components = entity['components'];
      if (components is List) {
        for (final component in components.whereType<Map>()) {
          changed += _visitComponent(component, owner, visit);
        }
      }
      final block = entity['prefab'];
      if (block is Map) changed += _visitInstance(block, owner, visit);
    }
    return changed;
  }

  /// An instance's `prefab` block: the fields it changes (its `overrides`,
  /// each one field of one component) and the components it adds. What the
  /// prefab itself carries is in the prefab's file, walked on its own.
  int _visitInstance(
    Map block,
    String owner,
    String? Function(TagUse use, Object? json) visit,
  ) {
    var changed = 0;
    final overrides = block['overrides'];
    if (overrides is List) {
      for (final change in overrides.whereType<Map>()) {
        final type = change['component'];
        final field = change['field'];
        if (type is! String || field is! String) continue;
        // The one field, as the component it belongs to would hold it.
        final fields = <String, dynamic>{field: change['value']};
        final n = _visitComponent(
          {'type': type, 'fields': fields},
          owner,
          visit,
        );
        if (n == 0) continue;
        change['value'] = fields[field];
        changed += n;
      }
    }
    final added = block['addedComponents'];
    if (added is List) {
      for (final entry in added.whereType<Map>()) {
        final component = entry['component'];
        if (component is Map) {
          changed += _visitComponent(component, owner, visit);
        }
      }
    }
    return changed;
  }

  int _visitComponent(
    Map component,
    String owner,
    String? Function(TagUse use, Object? json) visit,
  ) {
    var changed = 0;
    final fields = component['fields'];
    if (fields is! Map) return 0;
    final type = '${component['type']}';
    final definition = definitionByType(type);
    final label = definition?.hints.name ?? type;
    if (definition != null) {
      for (final field in definition.fields) {
        final hint = definition.hints.fields[field.name];
        final where = '$label › ${hint?.label ?? field.name}';
        changed += _visitField(
          fields,
          field.name,
          field.kind.id,
          owner,
          where,
          visit,
        );
        final itemKinds = hint?.itemKinds;
        final items = fields[field.name];
        if (itemKinds != null && items is List) {
          for (final item in items.whereType<Map>()) {
            for (final e in itemKinds.entries) {
              changed += _visitField(
                item,
                e.key,
                e.value.id,
                owner,
                '$where › ${e.key}',
                visit,
              );
            }
          }
        }
      }
    }
    // Inline timelines, and anything else that binds tracks.
    changed += _visitBindings(fields, (value) {
      return visit(
        TagUse(
          tag: value,
          kind: TagUseKind.reference,
          owner: owner,
          where: '$label › track binding',
        ),
        null,
      );
    });
    return changed;
  }

  int _visitField(
    Map fields,
    String key,
    String kind,
    String owner,
    String where,
    String? Function(TagUse use, Object? json) visit,
  ) {
    final value = fields[key];
    switch (kind) {
      case _tagList:
        if (value is! List) return 0;
        var changed = 0;
        final next = <String>[];
        for (final t in value.whereType<String>()) {
          final replacement = visit(
            TagUse(
              tag: t,
              kind: TagUseKind.carried,
              owner: owner,
              where: where,
            ),
            value,
          );
          if (replacement != null) changed++;
          final kept = replacement ?? t;
          if (kept.isNotEmpty && !next.contains(kept)) next.add(kept);
        }
        if (changed > 0) fields[key] = next;
        return changed;
      case _tagRef:
        if (value is! String || value.isEmpty) return 0;
        final replacement = visit(
          TagUse(
            tag: value,
            kind: TagUseKind.reference,
            owner: owner,
            where: where,
          ),
          value,
        );
        if (replacement == null) return 0;
        fields[key] = replacement;
        return 1;
      case _target:
        final tag = _tagOf(value);
        if (tag == null) return 0;
        final replacement = visit(
          TagUse(
            tag: tag,
            kind: TagUseKind.reference,
            owner: owner,
            where: where,
          ),
          value,
        );
        if (replacement == null) return 0;
        fields[key] = replacement.isEmpty
            ? null
            : _retagged(value, replacement);
        return 1;
    }
    return 0;
  }

  /// The tag a saved target or binding names, read as the engine reads it
  /// (`EntityTarget.fromJson`, `TrackBinding.fromJson`): `{tag: …}` — unless
  /// it names an entity too, which wins — or the short text `#tag` a
  /// hand-written file may hold. Null when it names no tag.
  static String? _tagOf(Object? value) {
    if (value is Map) {
      if (value['name'] is String) return null;
      final tag = value['tag'];
      return tag is String && tag.isNotEmpty ? tag : null;
    }
    if (value is String) {
      final text = value.trim();
      if (!text.startsWith('#')) return null;
      final tag = text.substring(1).trim();
      return tag.isEmpty ? null : tag;
    }
    return null;
  }

  /// [value] naming [tag] instead, in the form it was written in.
  static Object _retagged(Object? value, String tag) =>
      value is String ? '#$tag' : {'tag': tag};

  /// Every `binding: {tag: …}` (or `binding: "#tag"`) under [json], at any
  /// depth.
  static int _visitBindings(Object? json, String? Function(String tag) visit) {
    var changed = 0;
    if (json is Map) {
      for (final e in json.entries.toList()) {
        final value = e.value;
        final tag = e.key == 'binding' ? _tagOf(value) : null;
        if (tag != null) {
          final replacement = visit(tag);
          if (replacement != null && replacement.isNotEmpty) {
            json[e.key] = _retagged(value, replacement);
            changed++;
          }
        } else {
          changed += _visitBindings(value, visit);
        }
      }
    } else if (json is List) {
      for (final item in json) {
        changed += _visitBindings(item, visit);
      }
    }
    return changed;
  }
}
