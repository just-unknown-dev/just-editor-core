import 'editor_module.dart';
import 'module_failure_reporter.dart';

/// The modules registered with one editor, and how their contributions reach
/// the editor's registries.
///
/// Owned by an [EditorScope]; there is no process-wide list. The scope's
/// `reload` rebuilds every scope-level registry from scratch — built-ins first, then
/// each module in registration order — so a module can replace a built-in by
/// reusing its id, and nothing a module *stopped* contributing lingers.
class ModuleRegistry {
  /// An empty registry, telling of a module's mistakes through [failures]:
  /// as Flutter errors, unless given a reporter with the editor's log, as a
  /// scope's is.
  ModuleRegistry({
    ModuleFailureReporter failures = const ModuleFailureReporter(),
  }) : _failures = failures;

  final ModuleFailureReporter _failures;

  final Map<String, EditorModule> _modules = {};
  final Set<String> _builtIn = {};

  /// The modules whose [EditorModule.onUpdate] threw and was reported —
  /// said once, not once a frame, until it runs cleanly again.
  final Set<String> _failingUpdate = {};

  /// Reports what [module] threw while the editor called it [doing], and
  /// goes on: one module's mistake must not stop the others, or the
  /// editor's own tick.
  void _report(
    EditorModule module,
    String doing,
    Object error,
    StackTrace stack,
  ) => _failures.report(module, doing, error, stack);

  /// Disposes [old] when [next] takes its place and is another instance.
  void _replaced(EditorModule? old, EditorModule next) {
    if (old == null || identical(old, next)) return;
    try {
      old.dispose();
    } catch (error, stack) {
      _report(old, 'disposing it', error, stack);
    }
  }

  /// The modules registered with the editor, in registration order — not
  /// the [builtIns], which come ahead of them.
  List<EditorModule> get all => [
    for (final m in _modules.values)
      if (!_builtIn.contains(m.id)) m,
  ];

  /// The [builtIns], then [all]: every module whose contributions the
  /// editor reads.
  List<EditorModule> get withBuiltIns => List.unmodifiable(_modules.values);

  /// The modules the editor brings itself — its own tools, arriving the way
  /// a module's would — ahead of every other. Their Level Designer
  /// contributions are live whichever designer is chosen.
  List<EditorModule> get builtIns => [
    for (final m in _modules.values)
      if (_builtIn.contains(m.id)) m,
  ];

  /// Whether [module] is one of the [builtIns].
  bool isBuiltIn(EditorModule module) => _builtIn.contains(module.id);

  /// Looks up a module by id.
  EditorModule? byId(String id) => _modules[id];

  /// Registers [module], replacing — and disposing — any other one with
  /// the same id.
  void register(EditorModule module) {
    final old = _modules[module.id];
    _modules[module.id] = module;
    _replaced(old, module);
  }

  /// Registers [module] as one of the [builtIns]: after the built-ins
  /// already there, ahead of every other module.
  void registerBuiltIn(EditorModule module) {
    final old = _modules[module.id];
    final others = {
      for (final e in _modules.entries)
        if (!_builtIn.contains(e.key) && e.key != module.id) e.key: e.value,
    };
    _modules.removeWhere((id, _) => others.containsKey(id) || id == module.id);
    _modules[module.id] = module;
    _modules.addAll(others);
    _builtIn.add(module.id);
    _replaced(old, module);
  }

  /// Registers several modules.
  void registerAll(Iterable<EditorModule> modules) => modules.forEach(register);

  /// Removes a module.
  void unregister(String id) {
    _builtIn.remove(id);
    _failingUpdate.remove(id);
    final gone = _modules.remove(id);
    if (gone == null) return;
    try {
      gone.dispose();
    } catch (error, stack) {
      _report(gone, 'disposing it', error, stack);
    }
  }

  /// Every component group declared by a module, in registration order.
  List<String> get componentGroups => [
    for (final m in _modules.values) ...m.componentGroups,
  ];

  /// Forwards a scene load. A module that throws is reported, and the
  /// others still hear of it.
  void notifySceneOpened(String sceneName) {
    for (final m in _modules.values.toList()) {
      try {
        m.onSceneOpened(sceneName);
      } catch (error, stack) {
        _report(m, 'opening scene "$sceneName"', error, stack);
      }
    }
  }

  /// Forwards a scene save to every module, in turn; what each threw, by
  /// module id.
  ///
  /// Over the modules registered when the save began: one registered while
  /// another is saving (a hot reload) misses this save rather than breaking
  /// it, and one that went in the meantime is not told.
  Future<Map<String, Object>> notifySceneSaving(String sceneName) async {
    final failed = <String, Object>{};
    for (final MapEntry(key: id, value: m) in _modules.entries.toList()) {
      if (!identical(_modules[id], m)) continue;
      try {
        await m.onSceneSaving(sceneName);
      } on Object catch (error) {
        failed[id] = error;
      }
    }
    return failed;
  }

  /// Forwards an editor tick. A module that throws is reported — once,
  /// not every frame — and the others still tick.
  void notifyUpdate(double deltaTime) {
    for (final m in _modules.values.toList()) {
      try {
        m.onUpdate(deltaTime);
        _failingUpdate.remove(m.id);
      } catch (error, stack) {
        if (_failingUpdate.add(m.id)) _report(m, 'updating', error, stack);
      }
    }
  }

  /// Disposes every module and forgets them. One that throws is reported;
  /// the rest are still disposed.
  void disposeAll() {
    for (final m in _modules.values.toList()) {
      try {
        m.dispose();
      } catch (error, stack) {
        _report(m, 'disposing it', error, stack);
      }
    }
    _modules.clear();
    _builtIn.clear();
    _failingUpdate.clear();
  }
}
