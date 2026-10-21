// The web's stand-ins for the dart:io names io_native.dart exports: the same
// classes and members with the same types, so the editor compiles for the
// web and wasm. Nothing here reads or writes anything — the editor never
// starts on the web (it edits files on disk) — so every call that would
// touch a file or a process throws an UnsupportedError saying so, and
// Platform answers as a platform that is none of the desktops.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

Never _unsupported(String what) => throw UnsupportedError(
  '$what needs dart:io, which the web does not have. The editor edits the '
  'project files on disk and runs on a desktop: Windows, macOS or Linux.',
);

/// The id of this process. The web has none to give: reading it throws.
int get pid => _unsupported('pid');

/// The platform the program runs on. On the web: none of them.
abstract final class Platform {
  /// False: the web is not Windows.
  static bool get isWindows => false;

  /// False: the web is not macOS.
  static bool get isMacOS => false;

  /// False: the web is not Linux.
  static bool get isLinux => false;

  /// False: the web is not Android.
  static bool get isAndroid => false;

  /// False: the web is not iOS.
  static bool get isIOS => false;

  /// False: the web is not Fuchsia.
  static bool get isFuchsia => false;

  /// `'web'`.
  static String get operatingSystem => 'web';

  /// `'/'`, as in a URL.
  static String get pathSeparator => '/';

  /// No environment variables.
  static Map<String, String> get environment => const {};
}

/// How a file is opened for writing.
final class FileMode {
  const FileMode._(this._mode);

  final int _mode;

  /// Read only.
  static const read = FileMode._(0);

  /// Read and write, the file emptied first.
  static const write = FileMode._(1);

  /// Read and write, added at the end.
  static const append = FileMode._(2);

  /// Write only, the file emptied first.
  static const writeOnly = FileMode._(3);

  /// Write only, added at the end.
  static const writeOnlyAppend = FileMode._(4);

  @override
  String toString() => 'FileMode($_mode)';
}

/// What a path is on disk.
final class FileSystemEntityType {
  const FileSystemEntityType._(this._name);

  final String _name;

  /// A file.
  static const file = FileSystemEntityType._('file');

  /// A directory.
  static const directory = FileSystemEntityType._('directory');

  /// A link.
  static const link = FileSystemEntityType._('link');

  /// A Unix domain socket.
  static const unixDomainSock = FileSystemEntityType._('unixDomainSock');

  /// A pipe.
  static const pipe = FileSystemEntityType._('pipe');

  /// Nothing there.
  static const notFound = FileSystemEntityType._('notFound');

  @override
  String toString() => _name;
}

/// What the operating system said when a call failed.
class OSError implements Exception {
  /// The system's [message] and [errorCode].
  const OSError([this.message = '', this.errorCode = noErrorCode]);

  /// No error code was given.
  static const int noErrorCode = -1;

  /// What the system said.
  final String message;

  /// The system's code for it.
  final int errorCode;

  @override
  String toString() => 'OS Error: $message, errno = $errorCode';
}

/// A failed file operation.
class FileSystemException implements Exception {
  /// A failure with [message] about [path], and what the system said.
  const FileSystemException([this.message = '', this.path = '', this.osError]);

  /// What went wrong.
  final String message;

  /// The path it went wrong at, if any.
  final String? path;

  /// What the operating system said, if it said anything.
  final OSError? osError;

  @override
  String toString() => 'FileSystemException: $message, path = \'$path\'';
}

/// A change to a watched file or directory.
class FileSystemEvent {
  FileSystemEvent._(this.type, this.path, this.isDirectory);

  /// A file or directory was made.
  static const int create = 1 << 0;

  /// A file's contents or attributes changed.
  static const int modify = 1 << 1;

  /// A file or directory was deleted.
  static const int delete = 1 << 2;

  /// A file or directory was moved.
  static const int move = 1 << 3;

  /// Every kind of change.
  static const int all = create | modify | delete | move;

  /// Which kind of change: [create], [modify], [delete] or [move].
  final int type;

  /// Where it happened.
  final String path;

  /// Whether [path] is a directory.
  final bool isDirectory;
}

/// What a file system entry's metadata says.
class FileStat {
  FileStat._();

  /// The metadata of [path]; throws on the web.
  static Future<FileStat> stat(String path) async =>
      _unsupported('FileStat.stat');

  /// The metadata of [path]; throws on the web.
  static FileStat statSync(String path) => _unsupported('FileStat.statSync');

  /// When it last changed.
  DateTime get changed => _unsupported('FileStat.changed');

  /// When it was last written.
  DateTime get modified => _unsupported('FileStat.modified');

  /// When it was last read.
  DateTime get accessed => _unsupported('FileStat.accessed');

  /// What it is.
  FileSystemEntityType get type => _unsupported('FileStat.type');

  /// Its permission bits.
  int get mode => _unsupported('FileStat.mode');

  /// Its size in bytes.
  int get size => _unsupported('FileStat.size');
}

/// A place in the file system: a [File] or a [Directory].
abstract class FileSystemEntity {
  FileSystemEntity._(this.path);

  /// Where it is.
  final String path;

  /// Whether changes can be watched: never on the web.
  static bool get isWatchSupported => false;

  /// What [path] is; throws on the web.
  static Future<FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) async => _unsupported('FileSystemEntity.type');

  /// What [path] is; throws on the web.
  static FileSystemEntityType typeSync(
    String path, {
    bool followLinks = true,
  }) => _unsupported('FileSystemEntity.typeSync');

  /// Whether [path] is a directory; throws on the web.
  static Future<bool> isDirectory(String path) async =>
      _unsupported('FileSystemEntity.isDirectory');

  /// Whether [path] is a directory; throws on the web.
  static bool isDirectorySync(String path) =>
      _unsupported('FileSystemEntity.isDirectorySync');

  /// Whether [path] is a file; throws on the web.
  static Future<bool> isFile(String path) async =>
      _unsupported('FileSystemEntity.isFile');

  /// Whether [path] is a file; throws on the web.
  static bool isFileSync(String path) =>
      _unsupported('FileSystemEntity.isFileSync');

  /// Whether [path1] and [path2] are the same entry; throws on the web.
  static Future<bool> identical(String path1, String path2) async =>
      _unsupported('FileSystemEntity.identical');

  /// Whether [path1] and [path2] are the same entry; throws on the web.
  static bool identicalSync(String path1, String path2) =>
      _unsupported('FileSystemEntity.identicalSync');

  /// The directory part of [path].
  static String parentOf(String path) {
    final at = path.lastIndexOf('/');
    return at <= 0 ? (at == 0 ? '/' : '.') : path.substring(0, at);
  }

  /// [path] as a file URI.
  Uri get uri => Uri.file(path);

  /// Whether [path] is absolute.
  bool get isAbsolute => path.startsWith('/');

  /// The directory it is in.
  Directory get parent => Directory(parentOf(path));

  /// It with an absolute path; throws on the web.
  FileSystemEntity get absolute;

  /// Whether it is there; throws on the web.
  Future<bool> exists() async => _unsupported('$runtimeType.exists');

  /// Whether it is there; throws on the web.
  bool existsSync() => _unsupported('$runtimeType.existsSync');

  /// It moved to [newPath]; throws on the web.
  Future<FileSystemEntity> rename(String newPath);

  /// It moved to [newPath]; throws on the web.
  FileSystemEntity renameSync(String newPath);

  /// Deletes it; throws on the web.
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      _unsupported('$runtimeType.delete');

  /// Deletes it; throws on the web.
  void deleteSync({bool recursive = false}) =>
      _unsupported('$runtimeType.deleteSync');

  /// Its metadata; throws on the web.
  Future<FileStat> stat() => FileStat.stat(path);

  /// Its metadata; throws on the web.
  FileStat statSync() => FileStat.statSync(path);

  /// The real path, links followed; throws on the web.
  Future<String> resolveSymbolicLinks() async =>
      _unsupported('$runtimeType.resolveSymbolicLinks');

  /// The real path, links followed; throws on the web.
  String resolveSymbolicLinksSync() =>
      _unsupported('$runtimeType.resolveSymbolicLinksSync');

  /// Its changes as they happen; on the web, a stream that fails at once.
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) => Stream.error(UnsupportedError('$runtimeType.watch needs dart:io'));
}

/// Where written bytes go: a file opened with [File.openWrite].
abstract class IOSink implements StreamSink<List<int>>, StringSink {
  /// How strings are turned into bytes.
  Encoding get encoding;
  set encoding(Encoding value);

  /// Waits until what was written is written.
  Future<void> flush();
}

/// A file opened with [File.open].
abstract class RandomAccessFile {
  /// Closes it.
  Future<void> close();
}

/// A file on disk; on the web, every operation throws.
class File extends FileSystemEntity {
  /// The file at [path].
  File(super.path) : super._();

  /// The file at [uri].
  factory File.fromUri(Uri uri) => File(uri.path);

  @override
  File get absolute => File(path);

  /// Makes the file; throws on the web.
  Future<File> create({bool recursive = false, bool exclusive = false}) async =>
      _unsupported('File.create');

  /// Makes the file; throws on the web.
  void createSync({bool recursive = false, bool exclusive = false}) =>
      _unsupported('File.createSync');

  @override
  Future<File> rename(String newPath) async => _unsupported('File.rename');

  @override
  File renameSync(String newPath) => _unsupported('File.renameSync');

  /// Copies it to [newPath]; throws on the web.
  Future<File> copy(String newPath) async => _unsupported('File.copy');

  /// Copies it to [newPath]; throws on the web.
  File copySync(String newPath) => _unsupported('File.copySync');

  /// Its size; throws on the web.
  Future<int> length() async => _unsupported('File.length');

  /// Its size; throws on the web.
  int lengthSync() => _unsupported('File.lengthSync');

  /// When it was last written; throws on the web.
  Future<DateTime> lastModified() async => _unsupported('File.lastModified');

  /// When it was last written; throws on the web.
  DateTime lastModifiedSync() => _unsupported('File.lastModifiedSync');

  /// Sets when it was last written; throws on the web.
  Future<void> setLastModified(DateTime time) async =>
      _unsupported('File.setLastModified');

  /// Sets when it was last written; throws on the web.
  void setLastModifiedSync(DateTime time) =>
      _unsupported('File.setLastModifiedSync');

  /// Opens it; throws on the web.
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _unsupported('File.open');

  /// Its bytes as a stream; on the web, one that fails at once.
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream.error(UnsupportedError('File.openRead needs dart:io'));

  /// A sink writing to it; throws on the web.
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) => _unsupported('File.openWrite');

  /// Its bytes; throws on the web.
  Future<Uint8List> readAsBytes() async => _unsupported('File.readAsBytes');

  /// Its bytes; throws on the web.
  Uint8List readAsBytesSync() => _unsupported('File.readAsBytesSync');

  /// Its text; throws on the web.
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      _unsupported('File.readAsString');

  /// Its text; throws on the web.
  String readAsStringSync({Encoding encoding = utf8}) =>
      _unsupported('File.readAsStringSync');

  /// Its lines; throws on the web.
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async =>
      _unsupported('File.readAsLines');

  /// Its lines; throws on the web.
  List<String> readAsLinesSync({Encoding encoding = utf8}) =>
      _unsupported('File.readAsLinesSync');

  /// Writes [bytes] to it; throws on the web.
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async => _unsupported('File.writeAsBytes');

  /// Writes [bytes] to it; throws on the web.
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _unsupported('File.writeAsBytesSync');

  /// Writes [contents] to it; throws on the web.
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async => _unsupported('File.writeAsString');

  /// Writes [contents] to it; throws on the web.
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => _unsupported('File.writeAsStringSync');

  @override
  String toString() => "File: '$path'";
}

/// A directory on disk; on the web, every operation throws.
class Directory extends FileSystemEntity {
  /// The directory at [path].
  Directory(super.path) : super._();

  /// The directory at [uri].
  factory Directory.fromUri(Uri uri) => Directory(uri.path);

  /// The working directory; throws on the web.
  static Directory get current => _unsupported('Directory.current');

  /// Sets the working directory; throws on the web.
  static set current(dynamic path) => _unsupported('Directory.current');

  /// The system's temporary directory; throws on the web.
  static Directory get systemTemp => _unsupported('Directory.systemTemp');

  @override
  Directory get absolute => Directory(path);

  /// Makes the directory; throws on the web.
  Future<Directory> create({bool recursive = false}) async =>
      _unsupported('Directory.create');

  /// Makes the directory; throws on the web.
  void createSync({bool recursive = false}) =>
      _unsupported('Directory.createSync');

  /// Makes a new directory inside it; throws on the web.
  Future<Directory> createTemp([String? prefix]) async =>
      _unsupported('Directory.createTemp');

  /// Makes a new directory inside it; throws on the web.
  Directory createTempSync([String? prefix]) =>
      _unsupported('Directory.createTempSync');

  @override
  Future<Directory> rename(String newPath) async =>
      _unsupported('Directory.rename');

  @override
  Directory renameSync(String newPath) => _unsupported('Directory.renameSync');

  /// What it holds; on the web, a stream that fails at once.
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.error(UnsupportedError('Directory.list needs dart:io'));

  /// What it holds; throws on the web.
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => _unsupported('Directory.listSync');

  @override
  String toString() => "Directory: '$path'";
}

/// What a finished process left.
class ProcessResult {
  /// A result of process [pid].
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);

  /// The process's exit code.
  final int exitCode;

  /// What it wrote to standard output.
  final dynamic stdout;

  /// What it wrote to standard error.
  final dynamic stderr;

  /// The process's id.
  final int pid;
}

/// A process the program starts; on the web, starting one throws.
abstract class Process {
  /// Runs [executable] with [arguments] to the end; throws on the web.
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = _systemEncoding,
    Encoding? stderrEncoding = _systemEncoding,
  }) async => _unsupported('Process.run');

  /// Runs [executable] with [arguments] to the end; throws on the web.
  static ProcessResult runSync(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = _systemEncoding,
    Encoding? stderrEncoding = _systemEncoding,
  }) => _unsupported('Process.runSync');

  /// Asks the process [pid] to stop; throws on the web.
  static bool killPid(int pid) => _unsupported('Process.killPid');
}

// The system's text encoding: UTF-8 here.
const Encoding _systemEncoding = utf8;

/// The picture in the file at [path]: on the web there are no files, so it
/// fails to load and the [Image] shows its error.
ImageProvider fileImage(String path, {Object? version, double scale = 1}) =>
    _NoFileImage(path);

@immutable
final class _NoFileImage extends ImageProvider<_NoFileImage> {
  const _NoFileImage(this.path);

  final String path;

  @override
  Future<_NoFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _NoFileImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future.error(UnsupportedError('Reading $path needs dart:io')),
  );

  @override
  bool operator ==(Object other) => other is _NoFileImage && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
