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

import 'module_descriptor.dart';

/// What the add list offers: every module kind, in descriptor order.
///
/// Deliberately unfiltered. The list used to skip modules that were already on
/// the zone — a leftover from when a module could only exist once — and that is
/// exactly what made "add a workspaces pill to the centre" *move* the one on the
/// right instead of creating a second. With instances, a second copy is a
/// legitimate thing to want, so nothing here is filtered out and there is no
/// count to report: the board already shows what is on the bar.
List<NeoModuleDescriptor> neoAddCandidates(
  Iterable<NeoModuleDescriptor> descriptors,
) => List<NeoModuleDescriptor>.unmodifiable(descriptors);

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
