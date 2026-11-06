/// The `dart:io` seam: `dart:io` itself where the platform has it, the web's
/// stand-ins with the same names where it does not. Exported by `io.dart`;
/// a file of this package imports this barrel, never `dart:io`.
library;

export 'io_native.dart' if (dart.library.js_interop) 'io_web.dart';
