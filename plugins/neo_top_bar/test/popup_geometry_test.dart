import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

const scene = NeoSceneRect(left: 0, top: 0, width: 5120, height: 1440);
const leftOutput = NeoSceneRect(left: 0, top: 0, width: 2560, height: 1440);
const rightOutput = NeoSceneRect(left: 2560, top: 0, width: 2560, height: 1440);

void main() {
  group('neoPopupTargetRect', () {
    test('falls back to the whole scene without monitor bounds', () {
      expect(neoPopupTargetRect(scene: scene, monitor: null), scene);
      expect(
        neoPopupTargetRect(
          scene: scene,
          monitor: const NeoSceneRect(left: 0, top: 0, width: 0, height: 0),
        ),
        scene,
      );
    });

    test('uses one output instead of the whole multi-monitor scene', () {
      // Centering in the scene would put a card at x=2048, i.e. on the seam.
      expect(
        neoPopupTargetRect(scene: scene, monitor: rightOutput),
        rightOutput,
      );
      expect(neoPopupTargetRect(scene: scene, monitor: leftOutput), leftOutput);
    });

    test('keeps a portrait output beside a landscape one', () {
      // eDP-1 rotated 90 degrees, sitting to the right of DP-2.
      const portrait = NeoSceneRect(
        left: 2560,
        top: 0,
        width: 1536,
        height: 1440,
      );
      expect(neoPopupTargetRect(scene: scene, monitor: portrait), portrait);
    });

    test('clamps bounds that run past the scene', () {
      const smallScene = NeoSceneRect(
        left: 0,
        top: 0,
        width: 2560,
        height: 1440,
      );
      const oversized = NeoSceneRect(
        left: -200,
        top: -100,
        width: 3000,
        height: 1700,
      );
      expect(
        neoPopupTargetRect(scene: smallScene, monitor: oversized),
        smallScene,
      );
    });

    test('ignores a non-finite or degenerate rectangle', () {
      const smallScene = NeoSceneRect(
        left: 0,
        top: 0,
        width: 2560,
        height: 1440,
      );
      expect(
        neoPopupTargetRect(
          scene: smallScene,
          monitor: const NeoSceneRect(
            left: 0,
            top: 0,
            width: double.infinity,
            height: 100,
          ),
        ),
        smallScene,
      );
      expect(
        neoPopupTargetRect(
          scene: smallScene,
          monitor: const NeoSceneRect(left: 0, top: 0, width: 0, height: 100),
        ),
        smallScene,
      );
    });
  });

  group('neoPopupTargetPadding', () {
    test('is empty when the target is the whole scene', () {
      expect(
        neoPopupTargetPadding(scene: scene, target: scene),
        NeoPopupInsets.zero,
      );
    });

    test('insets the far output of a side-by-side pair', () {
      // The right output keeps the scene's full height and right edge and is
      // inset 2560 from the left, so a card centers over that output only.
      expect(
        neoPopupTargetPadding(scene: scene, target: rightOutput),
        const NeoPopupInsets(left: 2560, top: 0, right: 0, bottom: 0),
      );
    });

    test('insets a tall output placed above the main one', () {
      const stacked = NeoSceneRect(
        left: 0,
        top: -1440,
        width: 2560,
        height: 2880,
      );
      const lower = NeoSceneRect(left: 0, top: 0, width: 2560, height: 1440);
      expect(
        neoPopupTargetPadding(scene: stacked, target: lower),
        const NeoPopupInsets(left: 0, top: 1440, right: 0, bottom: 0),
      );
    });
  });

  const dp2 = NeoSceneRect(left: 0, top: 0, width: 2560, height: 1440);

  group('neoAnchoredPopupPlacement', () {
    // A 35px-tall pill in the trailing zone of a 55px top bar.
    const clockPill = NeoSceneRect(left: 2380, top: 10, width: 150, height: 35);

    test('hangs below the control and lines up its trailing edge', () {
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: clockPill,
        width: 340,
      )!;
      expect(placement.opensDownwards, isTrue);
      expect(placement.top, clockPill.bottom + 8);
      // The clock sits near the output's trailing edge, so its panel is the one
      // case that makes way: 2560 - 8 margin - 340 width.
      expect(placement.left, closeTo(2560 - 8 - 340, 0.001));
      expect(placement.bottom, isNull);
    });

    test('centers a mid-bar panel on the control', () {
      const bellPill = NeoSceneRect(
        left: 1900,
        top: 10,
        width: 150,
        height: 35,
      );
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: bellPill,
        width: 340,
      )!;
      // Horizontal midpoints line up, so the card hangs straight below the icon.
      final cardMiddle = placement.left + placement.width / 2;
      expect(cardMiddle, closeTo(bellPill.left + bellPill.width / 2, 0.001));
    });

    test('a wider panel still centers while it fits', () {
      const bellPill = NeoSceneRect(
        left: 1900,
        top: 10,
        width: 150,
        height: 35,
      );
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: bellPill,
        width: 420,
      )!;
      // 1900 + 75 is the control's middle; half of 420 goes either side.
      expect(placement.left, closeTo(1975 - 210, 0.001));
    });

    test('slides left by only as much as the trailing edge requires', () {
      const nearEdge = NeoSceneRect(
        left: 2380,
        top: 10,
        width: 150,
        height: 35,
      );
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: nearEdge,
        width: 340,
      )!;
      expect(placement.left, lessThan(nearEdge.left));
      expect(placement.left + 340, closeTo(2560 - 8, 0.001));
    });

    test('clamps a control that starts inside the leading margin', () {
      const leftPill = NeoSceneRect(left: 2, top: 10, width: 120, height: 35);
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: leftPill,
        width: 340,
      )!;
      expect(placement.left, 8);
    });

    test('opens upwards from a bar in the lower half of the output', () {
      const lowerPill = NeoSceneRect(
        left: 2380,
        top: 1395,
        width: 150,
        height: 35,
      );
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: lowerPill,
        width: 340,
      )!;
      expect(placement.opensDownwards, isFalse);
      expect(placement.top, isNull);
      // Distance from the scene's bottom edge to the panel's bottom edge.
      expect(placement.bottom, dp2.bottom - (lowerPill.top - 8));
    });

    test('keeps the caller cap when the output is tall enough', () {
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: clockPill,
        width: 340,
        maxHeight: 620,
      )!;
      // 1440 - 8 - (45 + 8) = 1379 available, so the cap wins.
      expect(placement.maxHeight, 620);
    });

    test('caps the height when the output is short', () {
      const short = NeoSceneRect(left: 0, top: 0, width: 2560, height: 600);
      final placement = neoAnchoredPopupPlacement(
        scene: short,
        output: short,
        anchor: clockPill,
        width: 340,
      )!;
      expect(placement.maxHeight, closeTo(600 - 8 - 53, 0.001));
    });

    test('gives up instead of hanging a panel with no room', () {
      const tiny = NeoSceneRect(left: 0, top: 0, width: 2560, height: 90);
      expect(
        neoAnchoredPopupPlacement(
          scene: tiny,
          output: tiny,
          anchor: const NeoSceneRect(
            left: 2380,
            top: 10,
            width: 150,
            height: 35,
          ),
          width: 340,
        ),
        isNull,
      );
    });

    test('rejects unusable inputs', () {
      expect(
        neoAnchoredPopupPlacement(
          scene: dp2,
          output: const NeoSceneRect(left: 0, top: 0, width: 0, height: 0),
          anchor: clockPill,
          width: 340,
        ),
        isNull,
      );
      expect(
        neoAnchoredPopupPlacement(
          scene: dp2,
          output: dp2,
          anchor: const NeoSceneRect(
            left: 0,
            top: 0,
            width: double.nan,
            height: 10,
          ),
          width: 340,
        ),
        isNull,
      );
    });

    test('shrink-wraps a panel wider than the output', () {
      const narrow = NeoSceneRect(left: 0, top: 0, width: 300, height: 900);
      final placement = neoAnchoredPopupPlacement(
        scene: narrow,
        output: narrow,
        anchor: const NeoSceneRect(left: 100, top: 4, width: 100, height: 30),
        width: 420,
      )!;
      expect(placement.width, 300 - 16);
    });

    test('accepts a zero-size anchor, as a context-menu point would be', () {
      const point = NeoSceneRect(left: 1200, top: 40, width: 0, height: 0);
      final placement = neoAnchoredPopupPlacement(
        scene: dp2,
        output: dp2,
        anchor: point,
        width: 340,
      )!;
      expect(placement.top, 48);
      // A click point centers the card on that x position.
      expect(placement.left, closeTo(1200 - 340 / 2, 0.001));
    });
  });
}
