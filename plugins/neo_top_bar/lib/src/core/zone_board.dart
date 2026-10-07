/// Pure rules behind the settings panel's zone board.
///
/// The panel shows one list per zone: draggable module cards, and an "add"
/// button underneath. Two things about that are easy to get subtly wrong and are
/// therefore decided here, away from the widget tree:
///
/// - **what a drop means.** A reorderable list reports the index the item landed
///   at after it was lifted out, and the configuration wants "the id this one now
///   sits in front of". Converting one into the other is where off-by-one bugs
///   live, so [neoBeforeIdAfterReorder] owns the conversion and its tests pin the
///   four interesting cases (front, back, middle, no move).
/// - **what the add list offers.** A module already on this zone is not a
///   candidate; one on another zone is a move; one that is switched off is an
///   add. [neoAddCandidates] answers that, so the button and the label agree.
///
/// Kept free of Flutter so it is unit-testable — see `neo_top_bar_logic.dart`.
library;

import 'config.dart';
import 'module_descriptor.dart';

/// One entry of a zone's add list: a module kind, and how many copies of it are
/// already on the bar.
class NeoAddCandidate {
  const NeoAddCandidate({required this.descriptor, required this.existing});

  final NeoModuleDescriptor descriptor;

  /// Copies of this module that are currently on the bar, anywhere.
  ///
  /// The list offers every kind regardless — the point of instances is that any
  /// module can be added any number of times, to any zone — so the count is what
  /// tells the user what they are about to create.
  final int existing;

  @override
  String toString() => 'NeoAddCandidate(${descriptor.id}, existing: $existing)';
}

/// What the add list should offer, in descriptor order.
///
/// Deliberately unfiltered: a module already on the bar is still offered,
/// because a second copy is a legitimate thing to want (two clocks, one per
/// time zone, say). The count is carried so the button can say which copy is
/// about to be created.
List<NeoAddCandidate> neoAddCandidates({
  required Iterable<NeoModuleDescriptor> descriptors,
  required Iterable<NeoModulePlacement> placements,
}) {
  final counts = <String, int>{};
  for (final placement in placements) {
    if (!placement.enabled) continue;
    counts[placement.moduleId] = (counts[placement.moduleId] ?? 0) + 1;
  }
  return List<NeoAddCandidate>.unmodifiable(<NeoAddCandidate>[
    for (final descriptor in descriptors)
      NeoAddCandidate(
        descriptor: descriptor,
        existing: counts[descriptor.id] ?? 0,
      ),
  ]);
}

/// The `beforeId` for a drop that landed at [newIndex], given the zone's ids in
/// the order the list was built with.
///
/// [ids] must still contain the dragged id at [oldIndex], which is what a
/// reorderable list hands its callback; [newIndex] is the index **after** the
/// item was lifted out, which is what Flutter's `onReorderItem` reports.
///
/// Returns null when the item now sits last, because the configuration expresses
/// "at the end of this zone" as "in front of nothing".
String? neoBeforeIdAfterReorder(List<String> ids, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= ids.length) return null;
  final remaining = <String>[...ids]..removeAt(oldIndex);
  if (newIndex <= 0) return remaining.isEmpty ? null : remaining.first;
  if (newIndex >= remaining.length) return null;
  return remaining[newIndex];
}
