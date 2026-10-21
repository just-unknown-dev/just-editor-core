/// The project's files and the processes the editor starts, wherever the
/// package is compiled.
///
/// The editor reads and saves a project through `dart:io`, which the web
/// does not have. The editor's libraries, and a module's that touch files,
/// import this library instead of `dart:io`:
///
/// - on Windows, macOS, Linux, Android and iOS it is `dart:io`'s own
///   [File], [Directory], [Platform], [Process] and their kin, unchanged;
/// - on the web (JavaScript and WebAssembly) it is stand-ins with the same
///   members: [Platform] says it is none of the desktops, and every file or
///   process call throws an [UnsupportedError].
///
/// The editor never starts on the web — it edits the files on disk under the
/// project folder, so it needs a desktop — and so never calls a stand-in.
/// They exist so that a game which imports the editor in its debug entry
/// point still compiles for the web and wasm, where the game then runs on
/// its own.
library;

export 'src/io/io_native.dart'
    if (dart.library.js_interop) 'src/io/io_web.dart';
