import '../scope/editor_scope.dart';
import '../view/editor_view.dart';
import 'editor_module.dart';
import 'editor_views.dart';
import 'module_registry.dart';
import 'scope_modules.dart';
import 'scope_wiring.dart';

/// What only the editor that hosts a scope does with it: rebuild its
/// registries, add its own tools, and connect what the scope asks of the
/// editor's windows. Exported by `host.dart`; a module never needs it.
extension ScopeHost on EditorScope {
  /// Adds the module [make] makes to the built-ins the editor brings
  /// ([ModuleRegistry.builtIns]), ahead of every other module, and
  /// rebuilds the registries — for a scope made before its host knew of
  /// it. When one with that id is there already, nothing changes, and the
  /// module just made is disposed unused.
  void addBuiltIn(EditorModule Function(EditorScope scope) make) =>
      ScopeWiring.of(this).addBuiltIn(make);

  /// After a hot reload: the editor's own presets made again, each module
  /// told ([EditorModule.onReassemble]), then every registry rebuilt from
  /// the code as it now is ([reload]), and the palette in use shown as it
  /// now is. `JustGameEditorPlugin.reassemble` calls this.
  void reassemble() => ScopeWiring.of(this).reassemble();

  /// Rebuilds every scope-level registry from scratch: built-ins, then each
  /// module's contributions in registration order. Idempotent, so it is safe
  /// on every hot reload — and nothing a module stopped contributing survives.
  /// A module's [EditorModule.onRegister] runs on its first pass only.
  void reload() => ScopeWiring.of(this).reload();

  /// A view standing in for [ScopeModules.editorView] while one pane of a
  /// split viewport is drawn or handled: everything that picks, places or
  /// paints through the editor's view then works in that pane. Null
  /// otherwise.
  EditorView? get viewOverride => EditorViews.of(this).viewOverride;
  set viewOverride(EditorView? view) =>
      EditorViews.of(this).viewOverride = view;

  /// What [ScopeModules.reloadAssets] calls: set by the editor plugin while
  /// it runs.
  void Function(Iterable<String> paths)? get assetReloader =>
      ScopeWiring.of(this).assetReloader;
  set assetReloader(void Function(Iterable<String> paths)? reload) =>
      ScopeWiring.of(this).assetReloader = reload;

  /// What [ScopeModules.openDock] calls: set by the editor.
  void Function(String id)? get dockOpener => ScopeWiring.of(this).dockOpener;
  set dockOpener(void Function(String id)? open) =>
      ScopeWiring.of(this).dockOpener = open;
}
