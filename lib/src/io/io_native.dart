// `dart:io`, where the platform has it. The web gets io_web.dart instead,
// with the same names; keep the two in step.
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

export 'dart:io'
    show
        Directory,
        File,
        FileMode,
        FileStat,
        FileSystemEntity,
        FileSystemEntityType,
        FileSystemEvent,
        FileSystemException,
        IOSink,
        OSError,
        Platform,
        Process,
        ProcessResult,
        RandomAccessFile,
        pid;

/// The picture in the file at [path], for an [Image].
///
/// [version] tells two readings of the same file apart — pass when it was
/// last changed, and a file saved again is read again rather than shown as
/// the picture cached the first time. On the web, where there are no files,
/// the picture fails to load and the [Image] shows its error.
ImageProvider fileImage(String path, {Object? version, double scale = 1}) =>
    _FileImageAt(File(path), version, scale: scale);

@immutable
final class _FileImageAt extends FileImage {
  const _FileImageAt(super.file, this.version, {super.scale});

  final Object? version;

  @override
  bool operator ==(Object other) =>
      other is _FileImageAt &&
      other.file.path == file.path &&
      other.scale == scale &&
      other.version == version;

  @override
  int get hashCode => Object.hash(file.path, scale, version);
}
