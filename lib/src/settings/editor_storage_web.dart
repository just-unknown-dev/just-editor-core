/// The editor's store on the web — not exported.
///
/// The editor never starts on the web; this is here so that a game whose
/// debug entry point imports the editor still compiles there. Browser
/// storage keeps each value under a key of its own and never rewrites a
/// whole file, so the standard store is safe to share.
library;

import 'package:just_storage/just_storage.dart';

/// The standard browser store.
Future<JustStandardStorage> openEditorStorage() => JustStorage.standard();
