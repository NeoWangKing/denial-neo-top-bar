import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

void main() {
  group('neoShouldCompact', () {
    test('a bar with room to spare is not compact', () {
      expect(
        neoShouldCompact(
          compact: false,
          available: 1000,
          needed: 700,
          naturalNeeded: 700,
        ),
        isFalse,
      );
    });

    test('a bar that is over budget goes compact immediately', () {
      expect(
        neoShouldCompact(
          compact: false,
          available: 1000,
          needed: 1001,
          naturalNeeded: 1001,
        ),
        isTrue,
      );
      expect(
        neoShouldCompact(
          compact: false,
          available: 1000,
          needed: 1000,
          naturalNeeded: 1000,
        ),
        isFalse,
        reason: 'exactly fitting is fitting',
      );
    });

    test('leaving the compact form needs slack, so it cannot oscillate', () {
      // Compacting makes every module narrower, so a bar that only just fits
      // after compacting must stay compact — otherwise it would expand again on
      // the next frame and flip back forever.
      expect(
        neoShouldCompact(
          compact: true,
          available: 1000,
          needed: 980,
          naturalNeeded: 980,
        ),
        isTrue,
      );
      expect(
        neoShouldCompact(
          compact: true,
          available: 1000,
          needed: 960,
          naturalNeeded: 960,
        ),
        isFalse,
      );
    });

    test('the verdict follows the natural need, not the compact one', () {
      // The compact pills fit with room to spare, but the bar would not fit
      // again the moment it expanded: staying compact is the only stable answer.
      expect(
        neoShouldCompact(
          compact: true,
          available: 1000,
          needed: 700,
          naturalNeeded: 1010,
        ),
        isTrue,
      );
    });

    test('an unmeasurable bar keeps whatever it had', () {
      for (final available in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          neoShouldCompact(
            compact: false,
            available: available,
            needed: 10,
            naturalNeeded: 10,
          ),
          isFalse,
          reason: '$available',
        );
        expect(
          neoShouldCompact(
            compact: true,
            available: available,
            needed: 10,
            naturalNeeded: 10,
          ),
          isTrue,
          reason: '$available',
        );
      }
    });
  });

  group('NeoBarBudget', () {
    test('a bar that fits stays out of the compact form', () {
      final budget = NeoBarBudget();
      for (var frame = 0; frame < 20; frame++) {
        expect(budget.observe(available: 1000, needed: 700), isFalse);
      }
      expect(budget.naturalNeed, 700);
    });

    test('a compact bar does not expand into an overflow it cannot see', () {
      // The bar is over budget at 1010, so it compacts and comes back at 980 —
      // smaller, because every compact module drops something. The compact pills
      // fit, and the naive question ("does the compact need fit?") would expand
      // the bar on the very next frame, find 1010 again, compact, and flip for
      // ever. The estimate is what stops it: the saving is measured once and the
      // bar stays compact until the *natural* layout has room.
      final budget = NeoBarBudget();
      expect(budget.observe(available: 1000, needed: 1010), isTrue);
      for (var frame = 0; frame < 20; frame++) {
        expect(budget.observe(available: 1000, needed: 980), isTrue);
      }
      expect(budget.saving, 30);
      expect(budget.naturalNeed, 1010);
    });

    test('the verdict settles in one change and never comes back', () {
      // The same numbers, with the bar's own layout feeding the measurement
      // back: whichever presentation is on screen decides what the next frame
      // measures. A flip-flop here is the twitch the user sees.
      const natural = 1010.0;
      const compact = 980.0;
      final budget = NeoBarBudget();
      final states = <bool>[
        for (var frame = 0; frame < 12; frame++)
          budget.observe(
            available: 1000,
            needed: budget.compact ? compact : natural,
          ),
      ];
      expect(states, everyElement(isTrue));
      expect(states.first, isTrue, reason: 'and it is the first frame');
    });

    test('a bar with room again expands once the natural need fits', () {
      final budget = NeoBarBudget();
      expect(budget.observe(available: 1000, needed: 1010), isTrue);
      expect(budget.observe(available: 1000, needed: 980), isTrue);
      // The output got wider: 1010 fits with the slack to spare.
      expect(budget.observe(available: 1200, needed: 980), isFalse);
      expect(budget.naturalNeed, 1010);
    });

    test('content that shrinks while compact brings the bar back', () {
      // A media pill that stops playing takes the same width away from both
      // presentations, so the estimate has to move with it — otherwise the bar
      // would stay compact for ever on the strength of a size nothing has any
      // more.
      final budget = NeoBarBudget();
      expect(budget.observe(available: 1000, needed: 1010), isTrue);
      expect(budget.observe(available: 1000, needed: 980), isTrue);
      expect(budget.naturalNeed, 1010);
      // 800 fewer pixels of content, in the compact presentation.
      expect(budget.observe(available: 1000, needed: 180), isFalse);
      expect(budget.naturalNeed, 210);
    });

    test('a saving is only trusted from the episode that measured it', () {
      final budget = NeoBarBudget();
      expect(budget.observe(available: 1000, needed: 1010), isTrue);
      expect(budget.observe(available: 1000, needed: 980), isTrue);
      budget.observe(available: 1200, needed: 980); // leaves compact
      // Over budget again, and this time compacting saves nothing: the bar has
      // to keep its own measurement rather than the old episode's.
      expect(budget.observe(available: 1000, needed: 1010), isTrue);
      expect(budget.observe(available: 1000, needed: 1010), isTrue);
      expect(budget.saving, 0);
      expect(budget.naturalNeed, 1010);
    });

    test('an unmeasurable bar keeps its presentation', () {
      final budget = NeoBarBudget();
      expect(budget.observe(available: 0, needed: 10), isFalse);
      expect(budget.observe(available: double.nan, needed: 10), isFalse);
      final compactBudget = NeoBarBudget();
      expect(compactBudget.observe(available: 1000, needed: 2000), isTrue);
      expect(compactBudget.observe(available: 0, needed: 10), isTrue);
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

  group('the bar\'s fit verdict', () {
    test('is the same question as neoPillsFit', () {
      // The bar computes the budget itself, as `neoRunExtent` over the extents
      // it measured plus the strip's padding, and uses that one number both to
      // place the pills (`neoPillsFit`) and to decide whether the modules have
      // to give something up. If the two ever disagreed, the bar would either
      // place pills it thinks fit or leave room it thinks it needs.
      for (final extents in <List<double>>[
        <double>[],
        <double>[700],
        <double>[700, 0, 0],
        <double>[300, 120, 340, 200],
        <double>[100, 100],
        <double>[8, 16, 32, 64, 128, 256, 512],
      ]) {
        for (final mainExtent in <double>[200, 500, 994, 1000, 1001, 2000]) {
          final needed = neoRunExtent(extents: extents, gap: 6) + 8 * 2;
          expect(
            needed <= mainExtent,
            neoPillsFit(
              pills: <NeoPillBox>[
                for (var index = 0; index < extents.length; index++)
                  NeoPillBox(
                    id: 'p$index',
                    zone: NeoZone.start,
                    extent: extents[index],
                  ),
              ],
              mainExtent: mainExtent,
              mainPadding: 8,
              gap: 6,
            ),
            reason: '$extents in $mainExtent',
          );
        }
      }
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
