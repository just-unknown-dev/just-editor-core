import '../scope/editor_scope.dart';
import 'asset_index.dart';
import 'asset_kind.dart';

/// The project's asset files on an [EditorScope]: the kinds of file it
/// knows, and the index of them every panel that lists files shares.
extension ScopeAssets on EditorScope {
  /// The kinds of file this editor knows — its modules' (a 3-D model), then
  /// its own — for the asset browser, its filters and drops on the
  /// viewport. The same object for the scope's life, brought up to date as
  /// modules come and go, so an [AssetIndex] can be handed it once.
  AssetKinds get assetKinds => service<AssetKinds>(AssetKinds.new);

  /// The project's asset files, under [EditorScope.projectRoot]: scanned
  /// the first time it is asked for, then following the disk. Shared by
  /// the Assets dock, every panel that lists files and a module's own.
  AssetIndex get assetIndex => service<AssetIndex>(
    () => AssetIndex(projectRoot: projectRoot, kinds: assetKinds)
      ..scan()
      ..startWatching(),
    dispose: (index) => index.dispose(),
  );
}
