import 'package:just_game_engine/just_game_engine.dart' as jge;

import 'level_tool.dart';

/// The tools available in the designer's left-hand palette.
///
/// Mirrors [PrefabRegistry] and [OverlayRegistry] so every kind of designer
/// extension is registered the same way.
class ToolRegistry {
  ToolRegistry();

  // By id, each id's tools for the modes they cover: one id may name a 2-D
  // tool and a 3-D one — Select is both — so whatever switches to it by id
  // finds the one for the scene in hand.
  final Map<String, List<LevelToolHandler>> _tools = {};
  final Map<String, ToolGroup> _groups = {
    for (final g in ToolGroups.builtIn) g.id: g,
  };

  /// The mode of the scene being edited; tools that do not belong in it are
  /// left out of [all], [byId] and [byShortcut]. Null offers everything.
  jge.SceneMode Function()? modeOf;

  bool _offered(LevelToolHandler tool) {
    final mode = modeOf?.call();
    return mode == null || tool.dimensions.allows(mode);
  }

  Iterable<LevelToolHandler> get _registered => _tools.values.expand((t) => t);

  /// The registered tools for the scene's mode, in palette order: by group,
  /// then within it.
  List<LevelToolHandler> get all {
    final sorted = _registered.where(_offered).toList()
      ..sort((a, b) {
        final byGroup = groupOf(
          a.group,
        ).order.compareTo(groupOf(b.group).order);
        if (byGroup != 0) return byGroup;
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.label.compareTo(b.label);
      });
    return List.unmodifiable(sorted);
  }

  /// The tools under each group's caption, top to bottom. Groups with no
  /// tools are left out.
  List<(ToolGroup, List<LevelToolHandler>)> get grouped {
    final out = <(ToolGroup, List<LevelToolHandler>)>[];
    for (final tool in all) {
      final group = groupOf(tool.group);
      if (out.isEmpty || out.last.$1.id != group.id) out.add((group, []));
      out.last.$2.add(tool);
    }
    return out;
  }

  /// The group called [id]; one nobody registered is captioned with its id.
  ToolGroup groupOf(String id) =>
      _groups[id] ?? ToolGroup(id: id, label: id.toUpperCase(), order: 50);

  /// Registers [group], replacing any of the same id.
  void registerGroup(ToolGroup group) => _groups[group.id] = group;

  /// The tool called [id] for the scene's mode: null when there is none,
  /// or only one for the other mode.
  LevelToolHandler? byId(String id) {
    for (final tool in _tools[id] ?? const <LevelToolHandler>[]) {
      if (_offered(tool)) return tool;
    }
    return null;
  }

  /// The tool bound to [shortcut], if any.
  LevelToolHandler? byShortcut(String shortcut) {
    final wanted = shortcut.toUpperCase();
    for (final tool in _registered) {
      if (!_offered(tool)) continue;
      if (tool.shortcut?.toUpperCase() == wanted) return tool;
    }
    return null;
  }

  /// Registers [tool], replacing any of the same id for the same modes: a
  /// 3-D tool beside a 2-D one of its id leaves that one be.
  void register(LevelToolHandler tool) {
    final same = _tools.putIfAbsent(tool.id, () => []);
    same.removeWhere((t) => _overlap(t.dimensions, tool.dimensions));
    same.add(tool);
  }

  static bool _overlap(jge.Dimensions a, jge.Dimensions b) =>
      a == b || a == jge.Dimensions.both || b == jge.Dimensions.both;

  /// Registers several tools.
  void registerAll(Iterable<LevelToolHandler> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  /// Removes every registration, ahead of rebuilding from extensions. The
  /// editor's own groups stay.
  void clear() {
    _tools.clear();
    _groups
      ..clear()
      ..addEntries([for (final g in ToolGroups.builtIn) MapEntry(g.id, g)]);
  }
}

/// Ids of the tools the editor itself provides.
///
/// A project can replace one by registering its own tool with the same id —
/// the same override path definitions already use.
abstract final class BuiltInTools {
  /// Select, marquee and manipulate.
  static const String select = 'select';

  /// Drag out a rectangle to place the active prefab.
  static const String draw = 'draw';

  /// In 3-D: click to place the active prefab on what is under the pointer.
  static const String place = 'place';

  /// Brush, rectangle fill and eraser on the grid.
  static const String paint = 'paint';

  /// Measure a distance in world units.
  static const String measure = 'measure';

  /// Sample an entity as the thing to draw and paint.
  static const String eyedropper = 'eyedropper';

  /// Edits the track of the selected dolly camera.
  static const String dolly = 'camera.dolly';
}
