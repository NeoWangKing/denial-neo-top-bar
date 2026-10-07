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

/// What dropping a module on a zone would do to it.
enum NeoAddEffect {
  /// The module is switched off and becomes visible here.
  add,

  /// The module is visible on another zone and moves here.
  move,
}

/// One entry of a zone's add list.
class NeoAddCandidate {
  const NeoAddCandidate({
    required this.descriptor,
    required this.effect,
    required this.currentZone,
  });

  final NeoModuleDescriptor descriptor;

  final NeoAddEffect effect;

  /// The zone the module is on right now; null when it is switched off.
  final NeoZone? currentZone;

  @override
  String toString() =>
      'NeoAddCandidate(${descriptor.id}, ${effect.name}, $currentZone)';
}

/// What the add list for [zone] should offer.
///
/// Modules already enabled on [zone] are left out: offering to add what is
/// already on screen is how a menu ends up with dead entries. Modules on another
/// zone are offered as a move, and switched-off modules as an add, in descriptor
/// order so the list does not depend on what the user has dragged where.
List<NeoAddCandidate> neoAddCandidates({
  required Iterable<NeoModulePlacement> placements,
  required NeoZone zone,
}) {
  final candidates = <NeoAddCandidate>[];
  for (final placement in placements) {
    if (placement.enabled && placement.zone == zone) continue;
    candidates.add(
      NeoAddCandidate(
        descriptor: placement.descriptor,
        effect: placement.enabled ? NeoAddEffect.move : NeoAddEffect.add,
        currentZone: placement.enabled ? placement.zone : null,
      ),
    );
  }
  return List<NeoAddCandidate>.unmodifiable(candidates);
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
