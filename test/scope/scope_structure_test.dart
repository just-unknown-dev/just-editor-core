// The scope as a kernel with features on top: a service is made once, on
// first ask, and goes with the scope; a scope with no modules is what a
// rebuilt one is; the services follow the settings whichever comes first;
// a module's mistake is told one way; the project's folder is one root.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_debugger/just_debugger.dart' show DebuggerLogLevel;
import 'package:just_editor_core/host.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../support/memory_settings_store.dart';

class _Counter {
  int disposed = 0;
}

class _Ticking extends EditorModule {
  @override
  String get id => 'ticking';
  @override
  String get name => 'Ticking';
  @override
  void onUpdate(double deltaTime) => throw StateError('a bug in onUpdate');
}

void main() {
  EditorScope scopeOf({
    List<EditorModule> modules = const [],
    MemorySettingsStore? store,
    String? projectRoot,
    String? scenesRoot,
  }) {
    final scope = EditorScope(
      world: World()..initialize(),
      modules: modules,
      settingsStore: store ?? MemorySettingsStore(),
      projectRoot: projectRoot,
      scenesRoot: scenesRoot,
    );
    addTearDown(() {
      if (!scope.isDisposed) scope.dispose();
    });
    return scope;
  }

  group('service', () {
    test('is made once, on first ask, and disposed with the scope', () {
      final scope = scopeOf();
      var made = 0;
      _Counter make() {
        made++;
        return _Counter();
      }

      expect(made, 0);
      final first = scope.service(make, dispose: (c) => c.disposed++);
      final second = scope.service(make, dispose: (c) => c.disposed++);
      expect(made, 1);
      expect(second, same(first));
      expect(scope.get<_Counter>(), same(first));

      scope.dispose();
      expect(first.disposed, 1);
    });

    test('a stand-in registered ahead of it is used instead', () {
      final scope = scopeOf();
      final standIn = _Counter();
      scope.container.registerSingleton<_Counter>(standIn);
      expect(scope.service<_Counter>(_Counter.new), same(standIn));
    });
  });

  test('a scope with no modules is what a rebuilt one is', () {
    final scope = scopeOf();
    final layers = [for (final l in scope.layers.all) l.id];
    final commands = scope.commands;
    expect(layers, [for (final l in LayerPresetRegistry.builtIn) l.id]);
    expect(scope.grid, isA<SquareGrid>());
    expect(scope.builtInDesignerParts, isEmpty);

    scope.reload();

    expect([for (final l in scope.layers.all) l.id], layers);
    expect(scope.commands, same(commands));
    expect(scope.grid, isA<SquareGrid>());
    expect(scope.docks, isEmpty);
    expect(scope.workspaces, isEmpty);
  });

  test('the services follow the settings, made before or after them', () {
    final store = MemorySettingsStore()
      ..saved = const OverlayUiSettings.defaults().copyWith(
        undoLimit: 40,
        consoleMaxEntries: 300,
      );
    final scope = scopeOf(store: store);
    // History made before the settings are read; the log after.
    final history = scope.history;
    expect(history.capacity, isNot(40));

    final prefs = scope.prefs;
    return prefs.load().then((_) {
      expect(scope.history.capacity, 40);
      expect(scope.log.maxEntries, 300);
      prefs.update(prefs.settings.value.copyWith(undoLimit: 25));
      expect(scope.history.capacity, 25);
    });
  });

  test("a module's mistake in a lifecycle call is in the log, as one in "
      'what it adds is', () {
    final scope = scopeOf(modules: [_Ticking()]);
    scope.modules.notifyUpdate(1 / 60);
    final said = [
      for (final e in scope.log.entries.value)
        if (e.level == DebuggerLogLevel.error && e.category == 'modules')
          e.message,
    ];
    expect(said, [
      'The module "ticking" failed (updating), so the editor goes on '
          'without it there: Bad state: a bug in onUpdate',
    ]);
  });

  group('the project folder', () {
    test('is the working folder, with forward slashes, when none is given', () {
      final scope = scopeOf();
      expect(scope.projectRoot, Directory.current.path.replaceAll(r'\', '/'));
      expect(scope.assetIndex.projectRoot, scope.projectRoot);
    });

    test('given one, the scenes and the project files are under it', () {
      final scope = scopeOf(projectRoot: r'C:\games\demo');
      expect(scope.projectRoot, 'C:/games/demo');
      expect(scope.scenes.scenesRoot, 'C:/games/demo/assets/scenes');
      expect(scope.tags.path, 'C:/games/demo/${TagLibrary.defaultPath}');
      expect(
        scope.physicsLayers.path,
        'C:/games/demo/${PhysicsLayers.defaultPath}',
      );
      expect(scope.colors.path, 'C:/games/demo/${ProjectColors.defaultPath}');
    });

    test('a scenes folder given, a test\'s, keeps them there as before', () {
      final scope = scopeOf(projectRoot: '/p', scenesRoot: '/t');
      expect(scope.scenes.scenesRoot, '/t');
      expect(scope.tags.path, '/t/tags.json');
    });
  });

  test('an audio file dropped makes a source as the scene it lands in is', () {
    final scope = scopeOf();
    List<Component> placed = const [];
    AssetDrop drop(SceneMode mode) => AssetDrop(
      scope: scope,
      path: 'assets/audio/hum.wav',
      at: Vector3(1, 0, 4),
      mode: mode,
      place: (components, name) {
        placed = components;
        return scope.world.createEntityWithComponents(components);
      },
    );

    AudioDrop.place(drop(SceneMode.threeD));
    expect(placed.whereType<AudioSourceComponent>().single.is3D, isTrue);
    expect(placed.whereType<TransformComponent>().single.position.y, -1);

    AudioDrop.place(drop(SceneMode.twoD));
    expect(placed.whereType<AudioSourceComponent>().single.is3D, isFalse);
  });
}

extension on EditorScope {
  List<Object> get builtInDesignerParts => [
    ...prefabCategories,
    ...statusControls,
    ...designerPanels,
    ...prefabs.all,
  ];
}
