import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../scope/editor_scope.dart';
import 'asset_index.dart';
import 'audio_drop.dart';
import '../view/ray_entity_picker.dart';

/// What a file is, as far as the editor cares: how the asset browser draws
/// it, what it can be filtered by, and what dropping it on the viewport
/// makes.
///
/// The editor knows its own ([values]); a module adds more
/// (`EditorModule.assetKinds`) — a 3-D model, say — matched by how the file
/// name ends.
final class AssetKind {
  /// A kind for files whose name ends with one of [endings] (lower case,
  /// with the dot: `.glb`, `.scene.json`).
  const AssetKind(
    this.id,
    this.label, {
    required this.icon,
    this.color,
    this.endings = const [],
    this.filterable = false,
    this.preview,
    this.drop,
    this.dropsIn = jge.Dimensions.both,
  });

  /// Names it: `image`, `model`.
  final String id;

  /// What the browser calls a group of them: `Images`, `Models`.
  final String label;

  /// Drawn for it where there is no picture of it.
  final IconData icon;

  /// Its colour in the browser, or null for the theme's muted text colour.
  final Color? color;

  /// How the names of its files end.
  final List<String> endings;

  /// Whether the browser offers it as a filter.
  final bool filterable;

  /// Builds a picture of `entry`, `size` logical pixels square, for the
  /// browser, or null to show the [icon]. A 3-D model's renders it.
  final Widget? Function(
    BuildContext context,
    AssetIndex index,
    AssetEntry entry,
    double size,
  )?
  preview;

  /// What dropping one on the viewport makes, or null when it cannot be
  /// dropped there. See [AssetDrop].
  final jge.Entity? Function(AssetDrop drop)? drop;

  /// The scenes [drop] makes something in: in a scene of another mode the
  /// viewport turns the file away, saying where it goes. A model's is 3-D.
  final jge.Dimensions dropsIn;

  /// Whether one dropped on the viewport of a scene of [mode] makes
  /// something.
  bool dropsInto(jge.SceneMode mode) => drop != null && dropsIn.allows(mode);

  /// Whether [path] (any case) is one of these.
  bool matches(String path) {
    final p = path.toLowerCase();
    for (final ending in endings) {
      if (p.endsWith(ending)) return true;
    }
    return false;
  }

  /// A folder: what [AssetKinds.of] says of any directory, whatever its
  /// name.
  static const AssetKind folder = AssetKind(
    'folder',
    'Folders',
    icon: Icons.folder_rounded,
    color: Color(0xFFFFC86B),
  );

  /// A picture: `.png`, `.jpg`, `.webp`, `.gif`, `.bmp`.
  static const AssetKind image = AssetKind(
    'image',
    'Images',
    icon: Icons.image_outlined,
    color: Color(0xFF7DD8E0),
    endings: ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'],
    filterable: true,
  );

  /// A sprite project: `.jsprite`, or an Aseprite file.
  static const AssetKind sprite = AssetKind(
    'sprite',
    'Sprites',
    icon: Icons.brush_outlined,
    color: Color(0xFF7DD8E0),
    endings: ['.jsprite', '.aseprite', '.ase'],
    filterable: true,
  );

  /// A scene the editor saves: `.scene.json`.
  static const AssetKind scene = AssetKind(
    'scene',
    'Scenes',
    icon: Icons.map_outlined,
    color: Color(0xFF7DE6B1),
    endings: ['.scene.json'],
    filterable: true,
  );

  /// An animator graph: `.animator.json`.
  static const AssetKind animator = AssetKind(
    'animator',
    'Animators',
    icon: Icons.account_tree_outlined,
    color: Color(0xFFFFCA28),
    endings: ['.animator.json'],
  );

  /// A tileset the editor saves: `.tileset.json`.
  static const AssetKind tileset = AssetKind(
    'tileset',
    'Tilesets',
    icon: Icons.grid_view,
    color: Color(0xFF9CCC65),
    endings: ['.tileset.json'],
    filterable: true,
  );

  /// A level map the editor saves: `.map.json`, or `.tilemap.json`.
  static const AssetKind levelMap = AssetKind(
    'levelMap',
    'Maps',
    icon: Icons.grid_on,
    color: Color(0xFF9CCC65),
    endings: ['.map.json', '.tilemap.json'],
    filterable: true,
  );

  /// A Tiled map or tileset: `.tmx`, `.tmj`, `.tsx`, `.tsj`.
  static const AssetKind tiled = AssetKind(
    'tiled',
    'Tiled files',
    icon: Icons.layers_outlined,
    color: Color(0xFF80CBC4),
    endings: ['.tmx', '.tmj', '.tsx', '.tsj'],
  );

  /// Other data: `.json`, `.yaml`, `.txt`, `.csv`.
  static const AssetKind data = AssetKind(
    'data',
    'Data',
    icon: Icons.data_object_rounded,
    endings: ['.json', '.yaml', '.yml', '.txt', '.csv'],
  );

  /// A sound: `.wav`, `.mp3`, `.ogg`, `.flac`, `.m4a`. Dropped on the
  /// viewport it makes a looping source of it.
  static const AssetKind audio = AssetKind(
    'audio',
    'Audio',
    icon: Icons.graphic_eq_rounded,
    color: Color(0xFFD9A7FF),
    endings: ['.wav', '.mp3', '.ogg', '.flac', '.m4a'],
    filterable: true,
    // Dropped on the viewport: a looping source of it (3-D in a 3-D scene).
    drop: AudioDrop.place,
  );

  /// A font: `.ttf`, `.otf`.
  static const AssetKind font = AssetKind(
    'font',
    'Fonts',
    icon: Icons.font_download_outlined,
    endings: ['.ttf', '.otf'],
  );

  /// Anything no other kind matches.
  static const AssetKind other = AssetKind(
    'other',
    'Other',
    icon: Icons.insert_drive_file_outlined,
  );

  /// The editor's own, in the order they are tried: the longer endings
  /// (`.scene.json`) before the plain ones (`.json`).
  static const List<AssetKind> values = [
    folder,
    scene,
    animator,
    tileset,
    levelMap,
    sprite,
    image,
    tiled,
    audio,
    font,
    data,
    other,
  ];

  @override
  String toString() => 'AssetKind.$id';
}

/// The kinds of file one editor knows: the modules' first, newest first,
/// then the editor's own.
final class AssetKinds {
  /// The editor's kinds and [added].
  AssetKinds([Iterable<AssetKind> added = const []]) {
    added.forEach(add);
  }

  final List<AssetKind> _added = [];

  /// Adds [kind], in place of one with its id.
  void add(AssetKind kind) {
    _added
      ..removeWhere((k) => k.id == kind.id)
      ..add(kind);
  }

  /// Puts [added] in place of every kind added so far: an editor's scope
  /// does, each time it rebuilds its registries from its modules.
  void replaceAll(Iterable<AssetKind> added) {
    _added.clear();
    added.forEach(add);
  }

  /// Every kind: the added ones, then the editor's own.
  List<AssetKind> get all => [..._added.reversed, ...AssetKind.values];

  /// The ones the browser offers as filters, in order.
  List<AssetKind> get filters => [
    for (final kind in AssetKind.values)
      if (kind.filterable) kind,
    for (final kind in _added)
      if (kind.filterable) kind,
  ];

  /// What [path] is.
  AssetKind of(String path, {bool isDirectory = false}) {
    if (isDirectory) return AssetKind.folder;
    for (final kind in _added.reversed) {
      if (kind.matches(path)) return kind;
    }
    return editorKindOf(path);
  }

  /// What [path] is by the editor's own kinds alone ([AssetKind.values]).
  static AssetKind editorKindOf(String path, {bool isDirectory = false}) {
    if (isDirectory) return AssetKind.folder;
    for (final kind in AssetKind.values) {
      if (kind.matches(path)) return kind;
    }
    return AssetKind.other;
  }
}

/// A file dropped on the viewport, for [AssetKind.drop].
final class AssetDrop {
  /// A drop of [path] landing at [at].
  AssetDrop({
    required this.scope,
    required this.path,
    required this.at,
    this.surface,
    required jge.Entity Function(List<jge.Component> components, String? name)
    place,
  }) : _place = place;

  /// The editor it was dropped in.
  final EditorScope scope;

  /// The file, project-relative: `assets/models/crate.glb`.
  final String path;

  /// Where it landed in the world: on the ground (y = 0) in 3-D, on the
  /// view's plane in 2-D.
  final jge.Vector3 at;

  /// In 3-D, the surface it landed on — what is under the pointer, or the
  /// working plane — and which way that faces; null in 2-D. [at] is its
  /// point.
  final SurfacePoint? surface;

  final jge.Entity Function(List<jge.Component> components, String? name)
  _place;

  /// Makes an entity of [components] at [at] (unless they bring their own
  /// transform), named after the file unless [name] is given, selected, as
  /// one undo step.
  jge.Entity place(List<jge.Component> components, {String? name}) => _place([
    if (!components.any((c) => c is jge.TransformComponent))
      jge.TransformComponent(position: jge.Vector3.copy(at)),
    ...components,
  ], name);
}
