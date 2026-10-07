/// Stable ordering for the launcher's per-window icons.
///
/// `ShellWindowServices.windows` hands back the host's own order, which follows
/// the compositor's z-order: activating a window raises it, so the list — and
/// therefore the row of icons — reshuffled the moment one of them was clicked.
/// A row that rearranges itself under the pointer is unusable: the click you are
/// about to make next is never where the last one taught you it would be.
///
/// So the bar remembers the order windows were first seen in and only ever
/// appends. Three consequences, all deliberate:
///
/// - clicking a window changes the accent plate and nothing else — no icon ever
///   moves because of a click;
/// - a window that closes leaves a hole the others do *not* shuffle into, so
///   muscle memory survives closing a window too;
/// - a window that opens joins at the end, in the host's order among the windows
///   that are new in the same frame, so a batch of new windows still opens in a
///   readable order.
///
/// The host order is only ever consulted for windows never seen before, which is
/// what makes this robust: it does not depend on what the host's order *means*.
///
/// Memory is bounded by construction — ids that are no longer present are
/// dropped, so the remembered list is never longer than the current window list.
///
/// Kept free of Flutter imports so it is unit-testable.
library;

/// Merges the host's [current] window ids into the [previous] remembered order.
///
/// Returns the ids that are still present, in their remembered order, followed
/// by the ids that appear for the first time, in host order.
List<int> neoStableWindowOrder({
  required List<int> current,
  required List<int> previous,
}) {
  final present = current.toSet();
  final placed = <int>{};
  final order = <int>[];
  for (final id in previous) {
    // `placed` also de-duplicates: a repeated id in either list must not produce
    // a second entry, or the bar would draw the same window twice.
    if (present.contains(id) && placed.add(id)) order.add(id);
  }
  for (final id in current) {
    if (placed.add(id)) order.add(id);
  }
  return order;
}
