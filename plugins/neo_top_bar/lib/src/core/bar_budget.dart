/// When the bar runs out of room, and what it gives up about it.
///
/// Two separate concerns live here, both pure so they can be unit-tested:
///
/// - **how much** a set of pills needs ([neoRunExtent]), by the same rules the
///   layouts use, so nothing can disagree about what "fits" means;
/// - **how much the bar gives up** ([NeoBarBudget]), one step at a time, with the
///   memory that keeps that decision from oscillating.
///
/// Kept free of Flutter so it is unit-testable — see `neo_top_bar_logic.dart`.
library;

import 'dart:math' as math;

/// How many tray icons survive on the bar itself once the tray gives way.
///
/// Three, like the workspace cells: enough to read at a glance, few enough that
/// the tray cannot be what pushes the clock off the strip. The rest stay one
/// click away in the tray panel.
const int neoTrayCompactLimit = 3;

/// Slack a bar must gain back before it takes a step *back* down the ladder.
///
/// Without it, a bar that barely fits after giving something up would take it
/// back on the next frame, stop fitting, give it up again, and flip forever.
const double neoCompactSlack = 32;

/// What the bar gives up when it runs out of room, in the order it gives it up.
///
/// A ladder rather than a switch: each step is worth a different amount of room,
/// so the bar takes one step at a time and stops as soon as it fits. Giving up
/// everything at once is what made a bar that was 20px short look like it had
/// thrown away the date, the track title and the window icons to buy room it
/// never needed.
///
/// The order is "who minds least", and each entry names the module that gives
/// way — a module reads `NeoModuleContext.concession` and compares it with the
/// step that is about to take something away from it.
abstract final class NeoConcession {
  /// Nothing given up.
  static const int none = 0;

  /// The tray keeps [neoTrayCompactLimit] icons and counts the rest in a `+N`.
  static const int tray = 1;

  /// The media pill drops the track title.
  static const int mediaTitle = 2;

  /// The clock drops the date.
  static const int clockDate = 3;

  /// The launcher drops its window strip.
  static const int launcherStrip = 4;

  /// The workspace pill drops the per-window icons and goes back to dots.
  static const int workspaceIcons = 5;

  /// The last step: after this there is nothing left to give up.
  static const int max = workspaceIcons;
}

/// The bar's place on the concession ladder, as it moves from frame to frame.
///
/// A plain comparison of "what the pills took" against "what the strip has"
/// cannot hold on to a decision, because giving something up *changes* what the
/// pills take: the measured bar always fits the moment it gave way, so the next
/// frame would take the concession back, find itself over budget again, and flip
/// forever — the twitch (and the pills positioned with each other's sizes) the
/// user sees.
///
/// So the bar remembers what each step was worth when it took it, and only that
/// remembered number may take a step back:
///
/// - [level] is where the bar is on [NeoConcession]'s ladder;
/// - [savingOf] is what a step was measured to save — the need one step up minus
///   the need at that step, which is knowable on exactly one frame: the one after
///   the step was taken.
///
/// Measurements arrive one frame behind the frame that renders them, so the
/// ladder answers for the *next* frame; see [observe].
class NeoBarBudget {
  int _level = NeoConcession.none;

  /// What each step was worth the last time the bar took it, in logical pixels.
  ///
  /// Every step the bar has climbed was measured as it climbed it, which is what
  /// makes the way back down possible: the estimate of the step below is
  /// `needed + savingOf(level)`, and it moves with the content, because a media
  /// pill that stops playing takes its width away from every step.
  final Map<int, double> _saving = <int, double>{};

  /// The need measured on the previous frame, one step up from this one.
  double _lastNeed = 0;

  /// The step whose arrival still has to be measured, if any.
  ///
  /// Set when the bar climbs into a step, cleared the frame after — the only
  /// frame on which both sides of that step exist.
  int? _measureArrival;

  /// Where the bar is on [NeoConcession]'s ladder.
  int get level => _level;

  /// What the step into [step] was worth the last time the bar took it.
  ///
  /// Zero until it has been taken, which reads as "this step buys nothing" and
  /// so never blocks the way back down on its own.
  double savingOf(int step) => _saving[step] ?? 0;

  /// Folds one frame's measurement in and returns the step to render next.
  ///
  /// [needed] is what the visible pills took along the main axis at the step the
  /// frame that measured them was rendering, and [available] is the room the
  /// strip has.
  ///
  /// Over budget climbs one step immediately — content is being pushed off the
  /// screen. Room to spare only steps back down when the *estimate* of the step
  /// below fits with [neoCompactSlack]: deciding from this step's own measurement
  /// would step back down every frame, because giving something up always makes
  /// the bar fit the moment it happens.
  int observe({required double available, required double needed}) {
    // A strip that cannot be measured says nothing about the pills either, so
    // this frame leaves the ladder — and its numbers — exactly as they were.
    if (!available.isFinite || available <= 0) return _level;

    final measured = _level;
    if (measured > 0 && _measureArrival == measured) {
      _saving[measured] = math.max(0, _lastNeed - needed);
      _measureArrival = null;
    }
    _lastNeed = needed;

    if (needed > available) {
      // One step per frame, deliberately: the frame after a step is the only one
      // that can measure what it bought, and a bar that jumped to the end of the
      // ladder would know nothing about the steps it skipped — including how to
      // find its way back down them.
      _level = math.min(measured + 1, NeoConcession.max);
      if (_level != measured) _measureArrival = _level;
      return _level;
    }
    if (measured == 0) return _level;
    if (needed + savingOf(measured) <= available - neoCompactSlack) {
      _level = measured - 1;
    }
    return _level;
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
