import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

void main() {
  group('neoShouldCompact', () {
    test('a bar with room to spare is not compact', () {
      expect(
        neoShouldCompact(compact: false, available: 1000, needed: 700),
        isFalse,
      );
    });

    test('a bar that is over budget goes compact immediately', () {
      expect(
        neoShouldCompact(compact: false, available: 1000, needed: 1001),
        isTrue,
      );
      expect(
        neoShouldCompact(compact: false, available: 1000, needed: 1000),
        isFalse,
        reason: 'exactly fitting is fitting',
      );
    });

    test('leaving the compact form needs slack, so it cannot oscillate', () {
      // Compacting makes every module narrower, so a bar that only just fits
      // after compacting must stay compact — otherwise it would expand again on
      // the next frame and flip back forever.
      expect(
        neoShouldCompact(compact: true, available: 1000, needed: 980),
        isTrue,
      );
      expect(
        neoShouldCompact(compact: true, available: 1000, needed: 960),
        isFalse,
      );
    });

    test('an unmeasurable bar keeps whatever it had', () {
      for (final available in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          neoShouldCompact(compact: false, available: available, needed: 10),
          isFalse,
          reason: '$available',
        );
        expect(
          neoShouldCompact(compact: true, available: available, needed: 10),
          isTrue,
          reason: '$available',
        );
      }
    });
  });

  group('neoRunExtent', () {
    test('sums the pills that take room, with gaps only between them', () {
      expect(neoRunExtent(extents: <double>[10, 20, 30], gap: 5), 70);
      expect(neoRunExtent(extents: <double>[10], gap: 5), 10);
      expect(neoRunExtent(extents: <double>[], gap: 5), 0);
    });

    test('a pill that renders nothing reserves neither room nor a gap', () {
      expect(neoRunExtent(extents: <double>[10, 0, 20], gap: 5), 35);
      expect(neoRunExtent(extents: <double>[0, 0], gap: 5), 0);
    });

    test('nonsense measurements do not poison the total', () {
      expect(neoRunExtent(extents: <double>[-5, double.nan, 10], gap: 5), 10);
    });
  });

  group('neoNeededExtent', () {
    test('adds the strip padding to every zone', () {
      expect(
        neoNeededExtent(
          zones: <List<double>>[
            <double>[100, 50],
            <double>[200],
            <double>[80],
          ],
          padding: 5,
          gap: 8,
        ),
        10 + (100 + 8 + 50) + 8 + 200 + 8 + 80,
      );
    });
  });

  group('tray collapse', () {
    test('the compact cap keeps the bar from being pushed off the screen', () {
      // Three is a deliberate number, like the workspace cells: the assertion is
      // here so changing it is a decision, not an accident.
      expect(neoTrayCompactLimit, 3);
    });
  });
}
