import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/host.dart';

void main() {
  test('a batch named before any of it exists gets distinct names', () {
    // What a paint stroke or a multi-entity duplicate does: name everything,
    // then create everything. Checking only the world handed out one name.
    final world = <String>{'Platform_0'};
    final name = UniqueNamer(() => world);
    final batch = [for (var i = 0; i < 3; i++) name('Platform')];
    expect(batch.toSet(), hasLength(3));
    expect(batch, isNot(contains('Platform_0')));
  });

  test('an undone entity\'s name is not reused, so its redo cannot clash', () {
    final world = <String>{};
    final name = UniqueNamer(() => world);
    final first = name('Coin'); // created, then undone: gone from the world
    final second = name('Coin');
    expect(second, isNot(first));
  });

  test('a batch reads the names in use once, not once a name', () {
    // A Tiled import names every object, one after another: two thousand
    // reads of five thousand names each took a second.
    final world = {for (var i = 0; i < 5000; i++) 'thing_$i'};
    var reads = 0;
    final name = UniqueNamer(() {
      reads++;
      return world;
    });
    final batch = [for (var i = 0; i < 2000; i++) name('Object')];
    expect(reads, 1);
    expect(batch.toSet(), hasLength(2000));
    expect(batch.first, 'Object_0');
    expect(batch.last, 'Object_1999');
  });

  test('the next run reads the names in use again', () async {
    final world = <String>{};
    var reads = 0;
    final name = UniqueNamer(() {
      reads++;
      return world;
    });
    expect(name('Tile'), 'Tile_0');
    await Future<void>.delayed(Duration.zero);
    // Named outside the namer since: seen now.
    world.add('Tile_1');
    expect(name('Tile'), 'Tile_2');
    expect(reads, 2);
  });

  test('a name the world let go of, and this namer never gave, is the '
      'lowest again', () async {
    final world = {'Coin_0', 'Coin_1'};
    final name = UniqueNamer(() => world);
    expect(name('Coin'), 'Coin_2');
    await Future<void>.delayed(Duration.zero);
    world.remove('Coin_0');
    expect(name('Coin'), 'Coin_0');
    expect(name('Coin'), 'Coin_3', reason: 'Coin_2 was given already');
  });
}
