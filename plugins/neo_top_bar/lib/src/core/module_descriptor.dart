/// Where a module sits along the bar's main axis.
///
/// The zones are ordered `start`, `center`, `end`. Within one zone, the order
/// is the user's saved order, falling back to the descriptor priority.
enum NeoZone {
  start,
  center,
  end;

  /// Human-readable name, shared by the settings panel and the drag preview so
  /// the two can never disagree about what a zone is called.
  String get label => switch (this) {
    NeoZone.start => '左侧',
    NeoZone.center => '中间',
    NeoZone.end => '右侧',
  };

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
class NeoModuleDescriptor {
  const NeoModuleDescriptor({
    required this.id,
    required this.label,
    required this.description,
    required this.zone,
    this.defaultEnabled = true,
    this.priority = 0,
  });

  final String id;
  final String label;
  final String description;
  final NeoZone zone;

  /// Whether a fresh configuration starts with this module enabled. Optional or
  /// data-hungry modules default off so the first run stays close to stock.
  final bool defaultEnabled;

  /// Fallback order inside [zone] while the user has not saved an explicit one.
  final int priority;
}
