/// Where a dragged pill would land.
///
/// Two separate questions have to be answered in this order, and answering them
/// the other way round is a bug that was actually shipped:
///
/// 1. **Which zone is the pointer over.** Zones are separated by large stretches
///    of empty strip (the bar spreads them with `spaceBetween`), and a pill's
///    slot is only as wide as the pill. Deciding the zone from "the pill after
///    this gap" makes the answer flip the moment the pointer crosses the middle
///    of a zone's last pill, silently moving the module into the next zone.
/// 2. **Where inside that zone.** Only then does a gap matter, and only among
///    that zone's own pills.
///
/// Kept free of `dart:ui` so it stays unit-testable on the plain Dart VM.
library;

import 'module_descriptor.dart';

/// The main-axis extent of one zone's visible pills, in strip coordinates.
class NeoZoneExtent {
  const NeoZoneExtent({
    required this.zone,
    required this.start,
    required this.end,
  });

  final NeoZone zone;

  /// Leading edge along the bar's main axis.
  final double start;

  /// Trailing edge along the bar's main axis.
  final double end;

  @override
  String toString() => 'NeoZoneExtent(${zone.name}: $start..$end)';
}

/// The zone a drop at [mainAxisPosition] belongs to.
///
/// [zoneExtents] must list the visible zones in bar order. Empty stretches
/// between two zones belong to whichever is nearer: the boundary sits at the
/// midpoint of the gap, so a drop in the middle of the bar does not jump to the
/// far side. Positions outside every extent clamp to the nearest end zone.
NeoZone? neoDropZoneAt({
  required double mainAxisPosition,
  required List<NeoZoneExtent> zoneExtents,
}) {
  if (zoneExtents.isEmpty) return null;
  for (var index = 0; index < zoneExtents.length; index++) {
    final extent = zoneExtents[index];
    if (mainAxisPosition < extent.start) {
      if (index == 0) return extent.zone;
      final previous = zoneExtents[index - 1];
      final boundary = (previous.end + extent.start) / 2;
      return mainAxisPosition < boundary ? previous.zone : extent.zone;
    }
    if (mainAxisPosition <= extent.end) return extent.zone;
  }
  return zoneExtents.last.zone;
}
