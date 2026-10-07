/// Tests for the settings panel's zone board rules.
///
/// Both rules exist because getting them wrong is easy and invisible: a drop
/// that lands one place off, and an add menu that offers what is already there.
library;

import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

const _descriptors = <NeoModuleDescriptor>[
  NeoModuleDescriptor(id: 'a', zone: NeoZone.start, priority: 10),
  NeoModuleDescriptor(id: 'b', zone: NeoZone.start, priority: 20),
  NeoModuleDescriptor(id: 'c', zone: NeoZone.end, priority: 10),
  NeoModuleDescriptor(
    id: 'd',
    zone: NeoZone.end,
    priority: 20,
    defaultEnabled: false,
  ),
];

List<NeoModulePlacement> placements() =>
    resolvePlacements(descriptors: _descriptors, config: NeoTopBarConfig.empty);

void main() {
  group('neoBeforeIdAfterReorder', () {
    // Flutter's `onReorderItem` reports the index *after* the item was lifted
    // out, so these are the four shapes a drop can take.
    const ids = <String>['a', 'b', 'c'];

    test('dropping at the front lands in front of the old first', () {
      expect(neoBeforeIdAfterReorder(ids, 2, 0), 'a');
    });

    test('dropping in the middle lands in front of the right neighbour', () {
      // 'b' moves down one slot: after removal the list is [a, c], and index 1
      // is 'c', so 'b' goes in front of 'c'.
      expect(neoBeforeIdAfterReorder(ids, 1, 1), 'c');
    });

    test('dropping at the end appends', () {
      expect(neoBeforeIdAfterReorder(ids, 0, 2), isNull);
      expect(neoBeforeIdAfterReorder(ids, 0, 99), isNull);
    });

    test('a one-item zone drops to nothing to sit in front of', () {
      expect(neoBeforeIdAfterReorder(const <String>['a'], 0, 0), isNull);
    });

    test('an out-of-range index is not a crash', () {
      expect(neoBeforeIdAfterReorder(ids, 5, 0), isNull);
      expect(neoBeforeIdAfterReorder(ids, -1, 0), isNull);
    });
  });

  group('neoCardKeyName', () {
    test('two copies of one module are two different cards', () {
      // Keying by module id gave both copies the same key, and a reorderable
      // list treats a duplicate key as the same child: the board drew one card
      // and dragged the wrong one.
      expect(
        neoCardKeyName('workspaces'),
        isNot(neoCardKeyName('workspaces#2')),
      );
    });
  });

  group('neoAddCandidates', () {
    test('offers every module, including ones already on the bar', () {
      // The list used to skip whatever was already on the zone, which is what
      // made adding a second copy move the first one instead.
      expect(
        neoAddCandidates(_descriptors).map((descriptor) => descriptor.id),
        <String>['a', 'b', 'c', 'd'],
      );
    });
  });
}
