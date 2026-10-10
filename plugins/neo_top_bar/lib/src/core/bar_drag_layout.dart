/// Geometry for the drag preview.
///
/// While a pill is being dragged the bar stops using its normal flex layout and
/// places each pill at an explicit offset, so `AnimatedPositioned` can animate
/// the reflow when the drop target changes. The offsets therefore have to
/// reproduce the flex layout exactly — start hugs the leading edge, the centre
/// zone is centred in the room the other two leave it, end hugs the trailing
/// edge — or pills would jump when a drag starts and when it ends.
///
/// Main and cross are the bar's own axes, so the same rules serve a horizontal
/// bar and a vertical one. Kept free of `dart:ui` so it is unit-testable.
library;

import 'dart:math' as math;

import 'module_descriptor.dart';

/// One pill to place, with its size along the bar's main axis.
class NeoPillBox {
  const NeoPillBox({
    required this.id,
    required this.zone,
    required this.extent,
  });

  final String id;
  final NeoZone zone;

  /// Size along the bar's main axis.
  final double extent;

  @override
  String toString() => 'NeoPillBox($id, ${zone.name}, $extent)';
}

/// Where one pill sits, in bar-local coordinates.
class NeoPlacedPill {
  const NeoPlacedPill({
    required this.main,
    required this.cross,
    required this.extent,
    required this.crossExtent,
  });

  /// Offset along the bar's main axis.
  final double main;

  /// Offset across the bar.
  final double cross;

  final double extent;
  final double crossExtent;

  @override
  String toString() =>
      'NeoPlacedPill(main: $main, cross: $cross, '
      'extent: $extent, crossExtent: $crossExtent)';
}

/// Places [pills] the way the bar's zones do.
///
/// Pills keep the order they appear in [pills]; a zone that ends up empty simply
/// places nothing, so the other zones keep their own edges.
///
/// The three zones are one row: the start zone against the leading edge, the end
/// zone against the trailing edge, and the centre zone centred in the room those
/// two leave it — not in the middle of the strip. That is the same row the flex
/// layout builds, down to the single [gap] between neighbouring zones, because
/// the bar switches between the two: it positions pills explicitly as soon as it
/// knows their sizes, and falls back to the flex layout in the frame a size
/// changes. Any disagreement between the two would move a pill for a frame, and
/// the centre zone is where it would show — a narrow start zone and a wide end
/// zone (or the other way round) put the middle of the strip nowhere near the
/// middle of the room the centre zone actually has.
///
/// A pill with a zero extent — a module that renders nothing right now, such as
/// the media pill with no player or an empty tray — is still *placed*, at the
/// zone's leading edge and with no width, but it reserves neither room nor a
/// gap. It has to stay in the tree: the bar learns that such a pill came back by
/// measuring it, so unmounting it would leave it unable to return. What it must
/// not do is hold open a hole where it used to be.
Map<String, NeoPlacedPill> neoDragLayout({
  required List<NeoPillBox> pills,
  required double mainExtent,
  required double crossExtent,
  required double mainPadding,
  required double crossPadding,
  required double gap,
}) {
  final placed = <String, NeoPlacedPill>{};
  final crossSize = crossExtent - crossPadding * 2;
  if (crossSize <= 0 || mainExtent <= 0) return placed;

  // Each zone's run along the main axis: only the pills that occupy room take
  // part in it, because gaps are counted between *these*, not between every
  // placement.
  final runs = <NeoZone, List<NeoPillBox>>{};
  final totals = <NeoZone, double>{};
  for (final zone in NeoZone.values) {
    final sized = <NeoPillBox>[
      for (final pill in pills)
        if (pill.zone == zone && pill.extent > 0) pill,
    ];
    if (sized.isEmpty) continue;
    var total = 0.0;
    for (final pill in sized) {
      total += pill.extent;
    }
    if (sized.length > 1) total += gap * (sized.length - 1);
    runs[zone] = sized;
    totals[zone] = total;
  }

  // The centre zone's slot: everything the start and end runs leave, one `gap`
  // away from each of them. That is exactly what the flex layout's `Expanded`
  // gets once the gaps are taken out.
  final startRun = totals[NeoZone.start] ?? 0;
  final endRun = totals[NeoZone.end] ?? 0;
  final centreLeft = mainPadding + (startRun > 0 ? startRun + gap : 0);
  final centreRight =
      mainExtent - mainPadding - (endRun > 0 ? endRun + gap : 0);
  final centreRoom = centreRight - centreLeft;
  final centreRun = totals[NeoZone.center] ?? 0;

  for (final zone in NeoZone.values) {
    final start = switch (zone) {
      NeoZone.start => mainPadding,
      // Clamped, not centred, when the zone's own run is wider than the slot:
      // the bar is over budget and the flex layout (which is the one that
      // scrolls) is the one on screen. Keeping the leading edge still beats
      // centring a pill into its neighbours' space.
      NeoZone.center => centreLeft + math.max(0, (centreRoom - centreRun) / 2),
      NeoZone.end => mainExtent - mainPadding - endRun,
    };
    final sized = runs[zone];
    var cursor = start;
    for (final pill in sized ?? const <NeoPillBox>[]) {
      placed[pill.id] = NeoPlacedPill(
        main: cursor,
        cross: crossPadding,
        extent: pill.extent,
        crossExtent: crossSize,
      );
      cursor += pill.extent + gap;
    }
    // The pills that render nothing keep their zone's leading edge, which is
    // where the bar places them so they can be measured back into existence.
    for (final pill in pills) {
      if (pill.zone != zone || pill.extent > 0) continue;
      placed[pill.id] = NeoPlacedPill(
        main: start,
        cross: crossPadding,
        extent: 0,
        crossExtent: crossSize,
      );
    }
  }
  return placed;
}

/// Whether [pills] fit in [mainExtent], by the same rules [neoDragLayout] lays
/// them out with: padding at both ends, [gap] between the pills that occupy
/// room, and zero-extent pills ignored entirely.
///
/// The two must agree, or the bar would flip between the explicit layout and
/// the scrolling one for a set of pills that fits. That total is exactly
/// [neoRunExtent] over the same extents plus the two paddings, which is the form
/// the bar itself uses — one number answering both "do the pills fit" and "do
/// the modules have to give something up", so the two can never disagree.
bool neoPillsFit({
  required List<NeoPillBox> pills,
  required double mainExtent,
  required double mainPadding,
  required double gap,
}) {
  var total = mainPadding * 2;
  var counted = 0;
  for (final pill in pills) {
    if (pill.extent <= 0) continue;
    total += pill.extent;
    if (counted > 0) total += gap;
    counted++;
  }
  return total <= mainExtent;
}
