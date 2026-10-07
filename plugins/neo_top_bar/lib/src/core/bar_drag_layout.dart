/// Geometry for the drag preview.
///
/// While a pill is being dragged the bar stops using its normal flex layout and
/// places each pill at an explicit offset, so `AnimatedPositioned` can animate
/// the reflow when the drop target changes. The offsets therefore have to
/// reproduce the flex layout exactly — start hugs the leading edge, centre is
/// centred, end hugs the trailing edge — or pills would jump when a drag starts
/// and when it ends.
///
/// Main and cross are the bar's own axes, so the same rules serve a horizontal
/// bar and a vertical one. Kept free of `dart:ui` so it is unit-testable.
library;

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

  for (final zone in NeoZone.values) {
    final inZone = <NeoPillBox>[
      for (final pill in pills)
        if (pill.zone == zone) pill,
    ];
    if (inZone.isEmpty) continue;

    var total = 0.0;
    for (final pill in inZone) {
      total += pill.extent;
    }
    total += gap * (inZone.length - 1);

    final start = switch (zone) {
      // The bar spreads its zones with spaceBetween, so the centre zone is
      // centred inside the same padded box the flex layout uses, which is the
      // same thing as centring it in the strip.
      NeoZone.start => mainPadding,
      NeoZone.center => (mainExtent - total) / 2,
      NeoZone.end => mainExtent - mainPadding - total,
    };

    var cursor = start;
    for (final pill in inZone) {
      placed[pill.id] = NeoPlacedPill(
        main: cursor,
        cross: crossPadding,
        extent: pill.extent,
        crossExtent: crossSize,
      );
      cursor += pill.extent + gap;
    }
  }
  return placed;
}
