/// Where a module sits along the bar's main axis.
///
/// The zones are ordered `start`, `center`, `end`. Within one zone, the order
/// is the user's saved order, falling back to the descriptor priority.
enum NeoZone {
  start,
  center,
  end;

  static NeoZone? parse(Object? value) {
    if (value is! String) return null;
    for (final zone in NeoZone.values) {
      if (zone.name == value) return zone;
    }
    return null;
  }
}

/// Immutable, user-facing identity of one bar module.
///
/// [id] is persisted, so it must stay stable across releases. Renaming an id
/// silently drops the user's choice for it.
///
/// A module's name and description are *not* here: they are words, so they live in
/// the string catalogue (`l10n.dart`) and are looked up by [id]. A descriptor then
/// stays a pure fact about layout, which no translation can disagree with, and the
/// zone's own name is looked up the same way.
class NeoModuleDescriptor {
  const NeoModuleDescriptor({
    required this.id,
    required this.zone,
    this.defaultEnabled = true,
    this.priority = 0,
  });

  final String id;
  final NeoZone zone;

  /// Whether a fresh configuration starts with this module enabled. Optional or
  /// data-hungry modules default off so the first run stays close to stock.
  final bool defaultEnabled;

  /// Fallback order inside [zone] while the user has not saved an explicit one.
  final int priority;
}
