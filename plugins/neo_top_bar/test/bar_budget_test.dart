import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

void main() {
  group('NeoConcession', () {
    test('is a ladder, ordered by who minds least', () {
      // The order is a decision, not an accident: the assertion is here so
      // changing it is a decision too. It is the same table the README shows.
      expect(
        <int>[
          NeoConcession.none,
          NeoConcession.tray,
          NeoConcession.mediaTitle,
          NeoConcession.clockDate,
          NeoConcession.launcherStrip,
          NeoConcession.workspaceIcons,
        ],
        <int>[0, 1, 2, 3, 4, 5],
      );
      expect(NeoConcession.max, NeoConcession.workspaceIcons);
    });
  });

  group('NeoBarBudget', () {
    /// Feeds the ladder one frame at a time, the way the bar's layout does: what
    /// the next frame measures is whatever step the last frame decided to show.
    List<int> run(
      NeoBarBudget budget,
      List<double> needs, {
      double available = 1000,
    }) => <int>[
      for (final needed in needs)
        budget.observe(available: available, needed: needed),
    ];

    test('a bar with room to spare stays at the top of the ladder', () {
      final budget = NeoBarBudget();
      final levels = run(budget, List<double>.filled(20, 700));
      expect(levels, everyElement(NeoConcession.none));
    });

    test('over budget gives up one step per frame and then stops', () {
      // 1010 does not fit, 980 does. The measured bar always fits the moment it
      // gave something up, so a ladder that judged from that measurement would
      // climb back down on the next frame, find 1010 again, and flip for ever:
      // this is the twitch. The step's own measured saving is what stops it.
      final budget = NeoBarBudget();
      expect(budget.observe(available: 1000, needed: 1010), NeoConcession.tray);
      final levels = run(budget, List<double>.filled(20, 980));
      expect(levels, everyElement(NeoConcession.tray));
      expect(budget.savingOf(NeoConcession.tray), 30);
    });

    test('the verdict settles after one change and never comes back', () {
      const natural = 1010.0;
      const conceded = 980.0;
      final budget = NeoBarBudget();
      final levels = <int>[
        for (var frame = 0; frame < 12; frame++)
          budget.observe(
            available: 1000,
            needed: budget.level == NeoConcession.none ? natural : conceded,
          ),
      ];
      expect(levels, everyElement(NeoConcession.tray));
    });

    test('climbs one step at a time, measuring each arrival', () {
      // 1100 -> 1060 at the tray step, 900 at the media step: the bar has to
      // climb both, and each step has to be measured as the bar takes it, or
      // there is no way back down.
      final budget = NeoBarBudget();
      expect(budget.observe(available: 1000, needed: 1100), NeoConcession.tray);
      expect(
        budget.observe(available: 1000, needed: 1060),
        NeoConcession.mediaTitle,
      );
      expect(
        budget.observe(available: 1000, needed: 900),
        NeoConcession.mediaTitle,
      );
      expect(budget.savingOf(NeoConcession.tray), 40);
      expect(budget.savingOf(NeoConcession.mediaTitle), 160);
    });

    test('gives up the next step only when the current one is not enough', () {
      // The media step is what finally fits (990), so the bar stops on it: the
      // date is not taken as well just because the bar has conceded something.
      final budget = NeoBarBudget();
      final levels = run(budget, <double>[1100, 1060, 1001, 990, 990, 990]);
      expect(levels, <int>[
        NeoConcession.tray,
        NeoConcession.mediaTitle,
        NeoConcession.clockDate,
        NeoConcession.clockDate,
        NeoConcession.clockDate,
        NeoConcession.clockDate,
      ]);
      expect(budget.savingOf(NeoConcession.tray), 40);
      expect(budget.savingOf(NeoConcession.mediaTitle), 59);
      expect(budget.savingOf(NeoConcession.clockDate), 11);
    });

    test('a step that buys nothing cannot hold the ladder', () {
      // Over budget by one pixel, with steps that save nothing: the bar keeps
      // climbing (there is nothing else it can do), and it does not come back
      // down on the strength of a saving it never measured.
      final budget = NeoBarBudget();
      final levels = run(budget, List<double>.filled(8, 1001));
      expect(levels.last, NeoConcession.max);
    });

    test('a step back needs slack', () {
      final budget = NeoBarBudget();
      budget.observe(available: 1000, needed: 1010); // 50 worth of tray
      budget.observe(available: 1000, needed: 960);
      // 960 + 50 = 1010, which is more than the 968 the slack allows.
      expect(budget.observe(available: 1000, needed: 960), NeoConcession.tray);
      // 900 + 50 = 950: now the full bar would fit with room to spare.
      expect(budget.observe(available: 1000, needed: 900), NeoConcession.none);
      expect(budget.observe(available: 1000, needed: 900), NeoConcession.none);
    });

    test('walks back down every step it climbed', () {
      final budget = NeoBarBudget();
      budget.observe(available: 1000, needed: 1100);
      budget.observe(available: 1000, needed: 1060); // tray is worth 40
      budget.observe(available: 1000, needed: 900); // media is worth 160
      // The output got wide enough for the full bar: 700 + 160 = 860 fits at the
      // media step, so that step goes first, and then the tray step.
      expect(budget.observe(available: 1000, needed: 700), NeoConcession.tray);
      expect(budget.observe(available: 1000, needed: 700), NeoConcession.none);
    });

    test('content that shrinks while conceded brings the bar back', () {
      // A media pill that stops playing takes the same width away from every
      // step, so the estimate has to move with it — otherwise the bar would stay
      // conceded for ever on the strength of a size nothing has any more.
      final budget = NeoBarBudget();
      budget.observe(available: 1000, needed: 1010);
      budget.observe(available: 1000, needed: 980);
      expect(budget.savingOf(NeoConcession.tray), 30);
      expect(budget.observe(available: 1000, needed: 700), NeoConcession.none);
    });

    test('never climbs past the last step', () {
      final budget = NeoBarBudget();
      final levels = run(budget, List<double>.filled(12, 4000));
      expect(levels.last, NeoConcession.max);
      expect(levels, contains(NeoConcession.max));
    });

    test('an unmeasurable strip keeps the step it had', () {
      final budget = NeoBarBudget();
      expect(budget.observe(available: 0, needed: 10), NeoConcession.none);
      expect(
        budget.observe(available: double.nan, needed: 10),
        NeoConcession.none,
      );
      budget.observe(available: 1000, needed: 2000);
      expect(budget.observe(available: 0, needed: 10), NeoConcession.tray);
      expect(
        budget.observe(available: double.nan, needed: 10),
        NeoConcession.tray,
      );
      expect(
        budget.savingOf(NeoConcession.tray),
        0,
        reason: 'a measurement the strip cannot vouch for is not a measurement',
      );
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
