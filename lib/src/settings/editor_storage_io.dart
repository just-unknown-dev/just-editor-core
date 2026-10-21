/// The editor's store on desktop: a file of its own — not exported.
///
/// Imports `dart:io` (and `package:path_provider`); `editor_storage.dart`
/// reaches it only through a conditional import on `dart.library.io`, so
/// web builds never see it.
library;

import 'dart:io';

import 'package:just_storage/just_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'editor_storage.dart';

/// The folder, in the app's support directory, that holds the editor's
/// `just_storage.json`.
const String editorStorageFolder = 'just_game_editor';

/// `<application support>/just_game_editor/just_storage.json`, with what an
/// editor left in the shared store moved into it.
Future<JustStandardStorage> openEditorStorage() async {
  final support = await getApplicationSupportDirectory();
  final own = await JustStorage.standard(
    Directory('${support.path}${Platform.pathSeparator}$editorStorageFolder'),
  );
  await moveEditorKeys(shared: () => JustStorage.standard(support), own: own);
  return own;
}
