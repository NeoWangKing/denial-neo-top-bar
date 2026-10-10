/// When the bar runs out of room, and what it does about it.
///
/// Two separate concerns live here, both pure so they can be unit-tested:
///
/// - **whether** the bar is over budget ([neoShouldCompact]) — with hysteresis,
///   because every compact module comes back *narrower*, which would otherwise
///   flip the decision back and make the bar oscillate every frame;
/// - **how much** a set of pills needs ([neoRunExtent]), by the same rules the
///   layout uses, so the two can never disagree about what "fits" means.
///
/// Kept free of Flutter so it is unit-testable — see `neo_top_bar_logic.dart`.
library;

/// How many tray icons survive on the bar itself when it is over budget.
///
/// Three, like the workspace cells: enough to read at a glance, few enough that
/// the tray cannot be what pushes the clock off the strip. The rest stay one
/// click away in the tray panel.
const int neoTrayCompactLimit = 3;

/// Slack a bar must gain back before it leaves the compact presentation.
///
/// Without it, a bar that barely fits after compacting would expand again on the
/// next frame, stop fitting, and flip back forever.
const double neoCompactSlack = 32;

/// Whether the bar should present its compact form.
///
/// [needed] is what the current pills want along the bar's main axis and
/// [available] is what the strip has. Going compact is immediate (content is
/// being pushed off the screen); leaving it requires [slack] of headroom.
bool neoShouldCompact({
  required bool compact,
  required double available,
  required double needed,
  double slack = neoCompactSlack,
}) {
  if (!available.isFinite || available <= 0) return compact;
  if (needed > available) return true;
  if (compact && needed > available - slack) return true;
  return false;
}

/// The main-axis extent a run of pills occupies: their sizes plus [gap] between
/// the ones that actually take room.
///
/// A zero-extent pill — a module rendering nothing right now — reserves neither
/// room nor a gap, exactly as `neoDragLayout` places it.
double neoRunExtent({required Iterable<double> extents, required double gap}) {
  var total = 0.0;
  var counted = 0;
  for (final extent in extents) {
    if (!extent.isFinite || extent <= 0) continue;
    total += extent;
    if (counted > 0) total += gap;
    counted++;
  }
  return total;
}

/// The extent every zone wants, plus the padding the strip keeps at its ends.
double neoNeededExtent({
  required Iterable<Iterable<double>> zones,
  required double padding,
  required double gap,
}) =>
    padding * 2 +
    neoRunExtent(
      extents: <double>[for (final zone in zones) ...zone],
      gap: gap,
    );
