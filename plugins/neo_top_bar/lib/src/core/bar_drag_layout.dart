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

import 'bar_budget.dart';
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

/// The main-axis run of each zone: what its pills take, plus one [gap] between
/// each neighbouring pair.
///
/// A zone that renders nothing at all has a run of zero, and takes neither room
/// nor a gap — the model every placement in this file shares.
class NeoZoneRuns {
  const NeoZoneRuns({
    required this.start,
    required this.centre,
    required this.end,
  });

  static const NeoZoneRuns none = NeoZoneRuns(start: 0, centre: 0, end: 0);

  final double start;
  final double centre;
  final double end;

  double runOf(NeoZone zone) => switch (zone) {
    NeoZone.start => start,
    NeoZone.center => centre,
    NeoZone.end => end,
  };

  @override
  String toString() => 'NeoZoneRuns(start: $start, centre: $centre, end: $end)';
}

/// Measures each zone's run from the pills the bar has already sized.
NeoZoneRuns neoZoneRuns({
  required List<NeoPillBox> pills,
  required double gap,
}) {
  double runOf(NeoZone zone) {
    final sized = <double>[
      for (final pill in pills)
        if (pill.zone == zone && pill.extent > 0) pill.extent,
    ];
    return neoRunExtent(extents: sized, gap: gap);
  }

  return NeoZoneRuns(
    start: runOf(NeoZone.start),
    centre: runOf(NeoZone.center),
    end: runOf(NeoZone.end),
  );
}

/// The room the start and end runs leave the centre zone, in strip coordinates.
///
/// One [gap] away from each of them, which is the gap `neoPillsFit` counts
/// between the last pill of one zone and the first pill of the next.
({double left, double right}) neoCentreRoom({
  required double mainExtent,
  required double mainPadding,
  required double gap,
  required NeoZoneRuns runs,
}) => (
  left: mainPadding + (runs.start > 0 ? runs.start + gap : 0),
  right: mainExtent - mainPadding - (runs.end > 0 ? runs.end + gap : 0),
);

/// Where the centre zone's run starts, in strip coordinates.
///
/// The **middle of the strip** is where the centre zone belongs: that is what a
/// user reads it as (the launcher sits between the workspaces and the clock, not
/// between the workspaces and the tray), and it does not wander when the two
/// other zones change width.
///
/// It is clamped into [neoCentreRoom] all the same. The middle of the strip can
/// land *inside* a neighbour's run when that neighbour takes more than half the
/// strip — the fit test only promises that the three runs add up, not that the
/// middle of the strip is free. Clamping is what keeps the centre zone from
/// being painted over its neighbours, and it is the same expression the flex
/// layout's alignment is derived from, so the two layouts cannot disagree.
double neoCentreOffset({
  required double mainExtent,
  required double mainPadding,
  required double gap,
  required NeoZoneRuns runs,
}) {
  final room = neoCentreRoom(
    mainExtent: mainExtent,
    mainPadding: mainPadding,
    gap: gap,
    runs: runs,
  );
  final middle = (mainExtent - runs.centre) / 2;
  final upper = math.max(room.left, room.right - runs.centre);
  return middle.clamp(room.left, upper);
}

/// The `Alignment` value that lands the centre zone on [offset] when the layout
/// can only place it *inside* its room.
///
/// The room is not centred on the strip when the start and end runs differ in
/// width — the normal case, a wide tray against a narrow workspace pill — so
/// getting the centre zone to the middle of the strip means aligning it off
/// centre within that room. [roomWidth] is the room the layout actually gave it
/// (not the measured one), and [roomLeft] is where that room starts, in the same
/// coordinates as [offset].
double neoCentreAlign({
  required double offset,
  required double roomLeft,
  required double roomWidth,
  required double centreRun,
}) {
  final span = roomWidth - centreRun;
  if (span <= 0) {
    // No room to slide in: the child fills its room, so the alignment cannot
    // move it anywhere.
    return 0;
  }
  return ((offset - roomLeft) / span * 2 - 1).clamp(-1.0, 1.0);
}

/// Places [pills] the way the bar's zones do.
///
/// Pills keep the order they appear in [pills]; a zone that ends up empty simply
/// places nothing, so the other zones keep their own edges.
///
/// The three zones are one row: the start zone against the leading edge, the end
/// zone against the trailing edge, and the centre zone at [neoCentreOffset] —
/// the middle of the strip whenever the middle is free, clamped into the room
/// the other two leave it otherwise. That is the same row the flex layout builds,
/// down to the single [gap] between neighbouring zones, because the bar switches
/// between the two: it positions pills explicitly as soon as it knows their
/// sizes, and falls back to the flex layout in the frame a size changes. Any
/// disagreement between the two would move a pill for a frame.
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
  for (final zone in NeoZone.values) {
    final sized = <NeoPillBox>[
      for (final pill in pills)
        if (pill.zone == zone && pill.extent > 0) pill,
    ];
    if (sized.isEmpty) continue;
    runs[zone] = sized;
  }
  final zoneRuns = neoZoneRuns(pills: pills, gap: gap);
  final centreStart = neoCentreOffset(
    mainExtent: mainExtent,
    mainPadding: mainPadding,
    gap: gap,
    runs: zoneRuns,
  );

  for (final zone in NeoZone.values) {
    final start = switch (zone) {
      NeoZone.start => mainPadding,
      NeoZone.center => centreStart,
      NeoZone.end => mainExtent - mainPadding - zoneRuns.end,
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
