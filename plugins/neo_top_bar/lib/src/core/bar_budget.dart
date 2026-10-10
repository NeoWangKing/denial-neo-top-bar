/// When the bar runs out of room, and what it does about it.
///
/// Two separate concerns live here, both pure so they can be unit-tested:
///
/// - **how much** a set of pills needs ([neoRunExtent]), by the same rules the
///   layouts use, so nothing can disagree about what "fits" means;
/// - **whether** the bar asks its modules for their compact form
///   ([NeoBarBudget]) — with the memory that keeps that decision from
///   oscillating, which is not the same thing as [neoShouldCompact] alone.
///
/// Kept free of Flutter so it is unit-testable — see `neo_top_bar_logic.dart`.
library;

import 'dart:math' as math;

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
/// [needed] is what the pills took in the presentation that was on screen,
/// [naturalNeeded] is what they would take if the bar were not compact — the
/// estimate [NeoBarBudget] keeps, not another measurement of the same thing.
///
/// Only the natural number may let the bar leave compact: with `needed` alone,
/// the compact presentation always "fits" the moment it compacted, so the bar
/// would expand again on the next frame and flip back forever.
///
/// Going compact is immediate (content is being pushed off the screen); leaving
/// it requires [slack] of headroom in the *natural* layout.
bool neoShouldCompact({
  required bool compact,
  required double available,
  required double needed,
  required double naturalNeeded,
  double slack = neoCompactSlack,
}) {
  if (!available.isFinite || available <= 0) return compact;
  if (needed > available) return true;
  if (compact && naturalNeeded > available - slack) return true;
  return false;
}

/// The bar's budget as it moves from frame to frame.
///
/// One decision, remembered: whether the modules give up their optional parts.
/// A plain comparison of "what the pills took" against "what the strip has"
/// cannot make that decision, because compacting *changes* what the pills take:
/// every compact module comes back narrower, so the compact pills fit by
/// construction. A bar that asked only that question would leave compact on the
/// next frame, find itself over budget again, compact, and flip forever — the
/// twitch (and the overlapping pills) the user sees when the two presentations
/// are laid out with each other's sizes.
///
/// So the bar keeps an *estimate* of what the pills would need if it were not
/// compact, and only that estimate decides whether it may leave compact:
///
/// - [compact] is what the bar is presenting;
/// - [naturalNeed] is the estimate, in logical pixels;
/// - [saving] is what compacting was measured to save, once both presentations
///   have been on screen (`needed + saving` is what the other one would take).
///
/// Measurements arrive one frame behind the frame that renders them, so a
/// budget answers for the *next* frame; see `observe`.
class NeoBarBudget {
  bool _compact = false;
  double _naturalNeed = 0;
  double _saving = 0;
  bool _savingKnown = false;

  /// Whether the bar is presenting its compact form.
  bool get compact => _compact;

  /// What the pills would need if the bar were not compact.
  ///
  /// An estimate, not a measurement, while the bar *is* compact: the natural
  /// presentation is not on screen to be measured.
  double get naturalNeed => _naturalNeed;

  /// What compacting saved, measured when both presentations were on screen.
  double get saving => _saving;

  /// Folds one frame's measurement in and returns whether to go compact.
  ///
  /// [needed] is what the visible pills took along the main axis in the
  /// presentation the frame that measured them was rendering, and [available] is
  /// the room the strip has.
  ///
  /// While the bar is *not* compact its measurement **is** the natural need, so
  /// that is recorded verbatim. While it *is* compact the estimate is
  /// `needed + saving`: content that moves — a media pill that stops playing,
  /// the tray losing an icon — moves both presentations, so it moves the
  /// estimate with it, and the bar can still find its way back out. A saving is
  /// only trusted from the episode that measured it, which is why leaving
  /// compact forgets it.
  bool observe({required double available, required double needed}) {
    if (_compact) {
      if (!_savingKnown && _naturalNeed > 0) {
        _saving = math.max(0, _naturalNeed - needed);
        _savingKnown = true;
      }
      _naturalNeed = needed + _saving;
    } else {
      _naturalNeed = needed;
      _savingKnown = false;
    }
    _compact = neoShouldCompact(
      compact: _compact,
      available: available,
      needed: needed,
      naturalNeeded: _naturalNeed,
    );
    return _compact;
  }
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
