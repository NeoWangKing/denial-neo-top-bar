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

  for (final zone in NeoZone.values) {
    final inZone = <NeoPillBox>[
      for (final pill in pills)
        if (pill.zone == zone) pill,
    ];
    if (inZone.isEmpty) continue;

    // Only the pills that occupy room take part in the run: gaps are counted
    // between *these*, not between every placement.
    final sized = <NeoPillBox>[
      for (final pill in inZone)
        if (pill.extent > 0) pill,
    ];

    var total = 0.0;
    for (final pill in sized) {
      total += pill.extent;
    }
    if (sized.length > 1) total += gap * (sized.length - 1);

    final start = switch (zone) {
      // The bar spreads its zones with spaceBetween, so the centre zone is
      // centred inside the same padded box the flex layout uses, which is the
      // same thing as centring it in the strip.
      NeoZone.start => mainPadding,
      NeoZone.center => (mainExtent - total) / 2,
      NeoZone.end => mainExtent - mainPadding - total,
    };

    var cursor = start;
    for (final pill in sized) {
      placed[pill.id] = NeoPlacedPill(
        main: cursor,
        cross: crossPadding,
        extent: pill.extent,
        crossExtent: crossSize,
      );
      cursor += pill.extent + gap;
    }
    for (final pill in inZone) {
      if (pill.extent > 0) continue;
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
/// the scrolling one for a set of pills that fits.
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
