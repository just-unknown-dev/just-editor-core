import 'dart:async';

/// Hands out entity names nothing else has.
///
/// Unique against the world *and* against every name already handed out.
/// Tools name a whole batch — a paint stroke's merged rectangles, a
/// multi-entity duplicate — before creating any of it, so checked against
/// the world alone, every entity in the batch would get the same name.
/// Parents are linked by name when a level loads, so a duplicate name is
/// not cosmetic.
///
/// The names in use are read once per run of the code asking — a Tiled
/// import naming two thousand objects reads them once, not two thousand
/// times — and again on the first call after it, in a later microtask. So
/// a name given to an entity in the same run *without* this namer is not
/// seen until then: name everything a batch makes through it.
class UniqueNamer {
  /// Avoids the names the given function returns — the world's entity
  /// names, say — asked again on the first call of each run.
  UniqueNamer(this._existingNames);

  final Iterable<String> Function() _existingNames;

  /// Every name handed out. Kept, not only the ones the world has: an
  /// entity whose creation was undone is not in the world, and its name
  /// must not go to another that its redo would then clash with.
  final Set<String> _issued = {};

  /// This run's names in use — the world's and every one handed out — or
  /// null between runs.
  Set<String>? _taken;

  /// This run's lowest index each prefix may still be free at.
  final Map<String, int> _next = {};

  /// A name of the form `prefix_N` that is not in use and has not been
  /// issued before: the lowest such N.
  String call(String prefix) {
    final taken = _taken ?? _startRun();
    var index = _next[prefix] ?? 0;
    var candidate = '${prefix}_$index';
    while (taken.contains(candidate)) {
      index++;
      candidate = '${prefix}_$index';
    }
    _next[prefix] = index + 1;
    taken.add(candidate);
    _issued.add(candidate);
    return candidate;
  }

  /// Reads the names in use for this run, and forgets them when it ends.
  Set<String> _startRun() {
    scheduleMicrotask(() {
      _taken = null;
      _next.clear();
    });
    return _taken = {..._existingNames(), ..._issued};
  }
}
