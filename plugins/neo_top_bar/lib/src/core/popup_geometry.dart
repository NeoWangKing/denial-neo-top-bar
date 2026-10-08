/// Geometry for placing a popup card inside one output.
///
/// The shell's Flutter scene spans every monitor, so centering a panel in the
/// scene puts it between outputs when more than one is attached. A panel must
/// center inside the output its bar belongs to instead. Denial's SDK documents
/// exactly this: `monitorBounds(monitorId)` exists to "constrain overlays to
/// their output rather than the whole multi-monitor scene".
///
/// This file deliberately avoids `dart:ui` (and therefore Flutter): `dart:ui`
/// only exists inside the Flutter engine, so importing it here would make the
/// whole pure-logic barrel unloadable on the plain Dart VM and break every unit
/// test. The widget layer converts [NeoSceneRect] to and from `Rect`.
library;

/// A rectangle in shell-scene coordinates, independent of Flutter.
class NeoSceneRect {
  const NeoSceneRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool get isEmpty => width <= 0 || height <= 0;

  bool get isFinite =>
      left.isFinite && top.isFinite && width.isFinite && height.isFinite;

  @override
  bool operator ==(Object other) =>
      other is NeoSceneRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'NeoSceneRect($left, $top, $width, $height)';
}

/// Insets that shrink one rectangle down to another.
class NeoPopupInsets {
  const NeoPopupInsets({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  static const NeoPopupInsets zero = NeoPopupInsets(
    left: 0,
    top: 0,
    right: 0,
    bottom: 0,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is NeoPopupInsets &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'NeoPopupInsets($left, $top, $right, $bottom)';
}

/// The area a panel should center inside, in scene coordinates.
///
/// Falls back to [scene] when no usable monitor rectangle is known, so a missing
/// or stale bounds value degrades to whole-scene centering rather than to an
/// empty area.
NeoSceneRect neoPopupTargetRect({
  required NeoSceneRect scene,
  NeoSceneRect? monitor,
}) {
  if (scene.isEmpty) return scene;
  if (monitor == null || monitor.isEmpty || !monitor.isFinite) return scene;
  final left = monitor.left.clamp(scene.left, scene.right);
  final top = monitor.top.clamp(scene.top, scene.bottom);
  final right = monitor.right.clamp(scene.left, scene.right);
  final bottom = monitor.bottom.clamp(scene.top, scene.bottom);
  if (right <= left || bottom <= top) return scene;
  return NeoSceneRect(
    left: left,
    top: top,
    width: right - left,
    height: bottom - top,
  );
}

/// Insets that shrink [scene] down to [target].
///
/// [target] is expected to come from [neoPopupTargetRect], so every inset is
/// non-negative. Values are clamped anyway: a negative inset would be a layout
/// error, not a silent offset.
NeoPopupInsets neoPopupTargetPadding({
  required NeoSceneRect scene,
  required NeoSceneRect target,
}) => NeoPopupInsets(
  left: (target.left - scene.left).clamp(0.0, double.infinity),
  top: (target.top - scene.top).clamp(0.0, double.infinity),
  right: (scene.right - target.right).clamp(0.0, double.infinity),
  bottom: (scene.bottom - target.bottom).clamp(0.0, double.infinity),
);

/// Where a panel sits when it is attached to the control that opened it.
class NeoPopupPlacement {
  const NeoPopupPlacement({
    required this.left,
    required this.width,
    required this.top,
    required this.bottom,
    required this.maxHeight,
    required this.opensDownwards,
  });

  /// Distance from the scene's left edge.
  final double left;

  /// Fixed card width, so horizontal clamping is exact.
  final double width;

  /// Distance from the scene's top edge when [opensDownwards]; else null.
  final double? top;

  /// Distance from the scene's bottom edge when opening upwards; else null.
  final double? bottom;

  /// Largest height the card may take without leaving the output.
  final double maxHeight;

  final bool opensDownwards;

  @override
  String toString() =>
      'NeoPopupPlacement(left: $left, width: $width, top: $top, '
      'bottom: $bottom, maxHeight: $maxHeight, '
      'opensDownwards: $opensDownwards)';
}

/// Places a popup at the pointer, inside its output.
///
/// Different from [neoAnchoredPopupPlacement] on purpose: a menu or a
/// per-control card that was asked for *at the cursor* belongs where the click
/// happened, not centered under a widget. Its leading corner — with a small
/// [gap] so the cursor does not sit on the card — is the pointer, and it only
/// flips to the other side of the pointer when that would carry it past the
/// output's edge. The flip is what keeps a menu on a bar at the bottom edge, or
/// at the right edge, fully visible.
///
/// Returns null when the inputs are unusable or when neither side of the pointer
/// has room for a usable card; callers then fall back to a centered card.
NeoPopupPlacement? neoPointerPopupPlacement({
  required NeoSceneRect scene,
  required NeoSceneRect output,
  required double x,
  required double y,
  required double width,
  double maxHeight = 620,
  double gap = 4,
  double margin = 8,
  double minimumHeight = 96,
}) {
  if (scene.isEmpty || output.isEmpty) return null;
  if (!scene.isFinite || !output.isFinite) return null;
  if (!x.isFinite || !y.isFinite) return null;

  final usableWidth = output.width - margin * 2;
  if (usableWidth <= 0) return null;
  final cardWidth = width.clamp(0.0, usableWidth);

  // Right of the pointer when it fits; otherwise left of it. Clamped either way,
  // so a pointer near an edge still gets a card that is fully on screen.
  final minLeft = output.left + margin;
  final maxLeft = output.right - margin - cardWidth;
  var left = x + gap;
  if (left + cardWidth > output.right - margin) left = x - gap - cardWidth;
  if (maxLeft < minLeft) {
    left = minLeft;
  } else {
    left = left.clamp(minLeft, maxLeft);
  }

  // Open towards whichever side of the pointer has more room, so a right-click
  // near the bottom of a bottom bar still opens a card that fits.
  final below = (output.bottom - margin) - (y + gap);
  final above = (y - gap) - (output.top + margin);
  final opensDownwards = below >= above;
  final available = opensDownwards ? below : above;
  if (available < minimumHeight) return null;
  final cardMaxHeight = available.clamp(0.0, maxHeight);
  if (cardMaxHeight < minimumHeight) return null;

  return NeoPopupPlacement(
    left: left,
    width: cardWidth,
    top: opensDownwards ? y + gap : null,
    bottom: opensDownwards ? null : scene.bottom - (y - gap),
    maxHeight: cardMaxHeight,
    opensDownwards: opensDownwards,
  );
}

/// Attaches a panel to the control that opened it, inside its own output.
///
/// The panel hangs directly below the control, horizontally centered on it, and
/// only slides sideways when that would carry it past the output's edge — a
/// trailing-zone icon such as the clock, whose panel therefore makes way. The
/// vertical direction follows the nearer output edge, so a top bar and a bottom
/// bar both work without the caller saying which.
///
/// Returns null when the inputs are unusable or when there is not enough room
/// left to show a usable panel; callers then fall back to a centered card.
NeoPopupPlacement? neoAnchoredPopupPlacement({
  required NeoSceneRect scene,
  required NeoSceneRect output,
  required NeoSceneRect anchor,
  required double width,
  double maxHeight = 620,
  double gap = 8,
  double margin = 8,
  double minimumHeight = 160,
}) {
  if (scene.isEmpty || output.isEmpty) return null;
  if (!scene.isFinite || !output.isFinite || !anchor.isFinite) return null;
  if (anchor.width < 0 || anchor.height < 0) return null;

  final usableWidth = output.width - margin * 2;
  if (usableWidth <= 0) return null;
  final cardWidth = width.clamp(0.0, usableWidth);

  // Center the panel on the control: its horizontal midpoint lines up with the
  // control's, so it hangs straight below the icon. It only slides sideways when
  // that would carry it past the output's edge, which is what happens for a
  // control that already sits near that edge (the clock, typically).
  final minLeft = output.left + margin;
  final maxLeft = output.right - margin - cardWidth;
  final anchorMiddle = anchor.left + anchor.width / 2;
  var left = anchorMiddle - cardWidth / 2;
  if (left > maxLeft) left = maxLeft;
  if (left < minLeft) left = minLeft;
  if (maxLeft < minLeft) left = minLeft;

  // Open away from the nearer horizontal edge.
  final outputMiddle = output.top + output.height / 2;
  final opensDownwards = anchor.top + anchor.height / 2 <= outputMiddle;

  final available = opensDownwards
      ? (output.bottom - margin) - (anchor.bottom + gap)
      : (anchor.top - gap) - (output.top + margin);
  if (available < minimumHeight) return null;
  final cardMaxHeight = available.clamp(0.0, maxHeight);
  if (cardMaxHeight < minimumHeight) return null;

  return NeoPopupPlacement(
    left: left,
    width: cardWidth,
    top: opensDownwards ? anchor.bottom + gap : null,
    bottom: opensDownwards ? null : scene.bottom - (anchor.top - gap),
    maxHeight: cardMaxHeight,
    opensDownwards: opensDownwards,
  );
}
