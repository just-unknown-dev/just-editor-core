// Waiting for real work — file reads and writes, a folder watcher — by its
// outcome rather than for a fixed time: how long the work takes depends on
// how busy the machine is, so a test that waits "long enough" passes alone
// and fails with other suites running beside it. These wait until what the
// test needs has happened, and fail — saying what they waited for — only
// after a bound far longer than the work ever takes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// How long the helpers wait before failing the test: far longer than the
/// work takes on a busy machine, so only work that never finishes fails.
const Duration ioTimeout = Duration(seconds: 10);

/// Waits on the real clock until [done] holds; fails the test, naming
/// [what], when it has not within [timeout].
Future<void> waitUntil(
  bool Function() done, {
  required String what,
  Duration timeout = ioTimeout,
}) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed > timeout) {
      fail('Waited ${timeout.inSeconds} s for $what, and it never happened.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Deletes [dir] and everything in it, trying again for up to [timeout]
/// while the system still holds something in it — on Windows a folder
/// watcher, or a read just finished, lets go a moment after it is closed.
Future<void> deleteWhenFree(
  Directory dir, {
  Duration timeout = ioTimeout,
}) async {
  final clock = Stopwatch()..start();
  while (true) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      if (clock.elapsed > timeout) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
