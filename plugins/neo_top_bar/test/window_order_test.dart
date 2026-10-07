/// Tests for the launcher's stable window order.
///
/// The rule under test is what keeps the row of window icons from reshuffling:
/// the host reports windows in z-order, so a click that raises a window must not
/// move any icon. Pure logic, no Flutter — see `neo_top_bar_logic.dart`.
library;

import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

void main() {
  group('neoStableWindowOrder', () {
    test('takes the host order for windows never seen before', () {
      expect(
        neoStableWindowOrder(current: <int>[3, 1, 2], previous: const <int>[]),
        <int>[3, 1, 2],
      );
    });

    test('a host reorder does not move anything', () {
      // This is the bug: the host raises the clicked window to the front.
      expect(
        neoStableWindowOrder(
          current: <int>[2, 3, 1],
          previous: const <int>[1, 2, 3],
        ),
        <int>[1, 2, 3],
      );
    });

    test('the first frame after a click is stable in both directions', () {
      const remembered = <int>[1, 2, 3];
      expect(
        neoStableWindowOrder(current: <int>[3, 1, 2], previous: remembered),
        remembered,
      );
      expect(
        neoStableWindowOrder(current: <int>[1, 2, 3], previous: remembered),
        remembered,
      );
    });

    test('a closing window leaves a hole the others do not shuffle into', () {
      // 2 closes; 1 and 3 keep their relative order and 3 does not slide left
      // into 2's slot *relative to the others*, i.e. 3 is still after 1.
      expect(
        neoStableWindowOrder(
          current: <int>[3, 1],
          previous: const <int>[1, 2, 3],
        ),
        <int>[1, 3],
      );
    });

    test('a window that comes back rejoins at the end', () {
      final afterClose = neoStableWindowOrder(
        current: <int>[1],
        previous: const <int>[1, 2],
      );
      expect(afterClose, <int>[1]);
      // The id was forgotten while absent, so it is a new window again.
      expect(
        neoStableWindowOrder(current: <int>[2, 1], previous: afterClose),
        <int>[1, 2],
      );
    });

    test('a new window joins at the end', () {
      expect(
        neoStableWindowOrder(
          current: <int>[9, 1, 2],
          previous: const <int>[1, 2],
        ),
        <int>[1, 2, 9],
      );
    });

    test('several new windows keep the host order among themselves', () {
      expect(
        neoStableWindowOrder(
          current: <int>[8, 1, 9, 7],
          previous: const <int>[1],
        ),
        <int>[1, 8, 9, 7],
      );
    });

    test('an empty window list forgets everything', () {
      expect(
        neoStableWindowOrder(
          current: const <int>[],
          previous: const <int>[1, 2],
        ),
        isEmpty,
      );
      expect(
        neoStableWindowOrder(current: const <int>[1], previous: const <int>[]),
        <int>[1],
      );
    });

    test('remembered order is never longer than the current list', () {
      // Bounded memory: ids that disappeared are dropped for good.
      final order = neoStableWindowOrder(
        current: <int>[4],
        previous: const <int>[1, 2, 3],
      );
      expect(order, <int>[4]);
      expect(neoStableWindowOrder(current: <int>[4], previous: order), <int>[
        4,
      ]);
    });

    test('duplicate ids do not draw the same window twice', () {
      expect(
        neoStableWindowOrder(
          current: <int>[1, 1, 2],
          previous: const <int>[1, 1],
        ),
        <int>[1, 2],
      );
    });

    test('is idempotent once the set stops changing', () {
      var order = neoStableWindowOrder(
        current: <int>[2, 1],
        previous: const <int>[],
      );
      for (var frame = 0; frame < 5; frame++) {
        order = neoStableWindowOrder(current: <int>[1, 2], previous: order);
        expect(order, <int>[2, 1]);
      }
    });
  });
}
