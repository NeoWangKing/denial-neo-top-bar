/// Serializable user configuration for the bar.
///
/// The file is a sparse overlay over the built-in defaults, not a full
/// snapshot: it records only the modules the user changed, their chosen order
/// and the module ids the user explicitly removed. Anything absent falls back
/// to the registry, so a new built-in module appears with its own default
/// instead of being silently enabled or disabled by an old file.
library;

import 'module_descriptor.dart';

/// Current persisted schema. Unknown/newer versions are rejected by callers so
/// a future file is never silently downgraded.
const int neoTopBarConfigSchema = 1;

/// Spacing scale for the whole bar.
///
/// This is a deliberate top-level option rather than a per-module one: the
/// common complaint about a system bar is that it feels too wide or too airy,
/// and that is a property of the strip, not of one pill.
enum NeoDensity {
  compact(0.8),
  regular(1.0),
  comfortable(1.25);

  const NeoDensity(this.scale);

  /// Multiplier applied to card padding and inter-card gaps.
  final double scale;

  static NeoDensity parse(Object? value) {
    if (value is! String) return NeoDensity.regular;
    for (final density in NeoDensity.values) {
      if (density.name == value) return density;
    }
    return NeoDensity.regular;
  }
}

/// One module's user decision.
class NeoModulePreference {
  const NeoModulePreference({
    this.enabled,
    this.zone,
    this.options = const <String, Object?>{},
  });

  /// Null means "use the descriptor default".
  final bool? enabled;

  /// Null means "use the descriptor zone".
  final NeoZone? zone;

  /// Module-specific settings, keyed by a name the module itself defines.
  ///
  /// Deliberately opaque here: the config layer stores and prunes what a module
  /// asks it to store and never interprets the values. A module that grows a
  /// setting therefore does not need a config schema change, and an option left
  /// behind by an older build is harmless — the module simply reads a value it
  /// does not know and ignores it.
  final Map<String, Object?> options;

  bool get isEmpty => enabled == null && zone == null && options.isEmpty;

  /// This preference with the enabled flag replaced, keeping everything else.
  ///
  /// Every mutator goes through one of these two, because building a fresh
  /// `NeoModulePreference` from scratch silently drops the fields the caller did
  /// not mention: toggling a module used to forget the zone the user had moved
  /// it to, and would now forget its own settings as well.
  NeoModulePreference withEnabled(bool value) =>
      NeoModulePreference(enabled: value, zone: zone, options: options);

  /// This preference with the zone replaced, keeping everything else.
  NeoModulePreference withZone(NeoZone? value) =>
      NeoModulePreference(enabled: enabled, zone: value, options: options);

  /// This preference with [key] set to [value], or removed when null.
  NeoModulePreference withOption(String key, Object? value) {
    final next = Map<String, Object?>.of(options);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return NeoModulePreference(
      enabled: enabled,
      zone: zone,
      // Frozen so nothing can reach into a preference and edit it in place; the
      // const constructor cannot do this itself, which is why only the mutators
      // go through here.
      options: Map<String, Object?>.unmodifiable(next),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (enabled != null) 'enabled': enabled,
    if (zone != null) 'zone': zone!.name,
    if (options.isNotEmpty)
      'options': <String, Object?>{
        for (final entry in options.entries)
          if (entry.value != null) entry.key: entry.value,
      },
  };

  static NeoModulePreference fromJson(Object? value) {
    if (value is! Map) return NeoModulePreference();
    final enabled = value['enabled'];
    final options = <String, Object?>{};
    if (value['options'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries) {
        final key = entry.key;
        // Only JSON-shaped values are kept, so a hand-edited file cannot put a
        // value in here that the writer could not write back out. A value that
        // fails the check is dropped whole rather than partly repaired: a
        // module should never receive a half-filtered structure no writer could
        // have produced.
        if (key is! String || key.isEmpty) continue;
        if (!_isJsonValue(entry.value)) continue;
        options[key] = entry.value;
      }
    }
    return NeoModulePreference(
      enabled: enabled is bool ? enabled : null,
      zone: NeoZone.parse(value['zone']),
      options: options,
    );
  }
}

/// Whether [value] is something [NeoModulePreference.toJson] can round-trip.
bool _isJsonValue(Object? value) => switch (value) {
  null || bool() || num() || String() => true,
  List<Object?>() => value.every(_isJsonValue),
  Map<Object?, Object?>() => value.entries.every(
    (entry) => entry.key is String && _isJsonValue(entry.value),
  ),
  _ => false,
};

/// The complete persisted configuration.
class NeoTopBarConfig {
  NeoTopBarConfig({
    this.schema = neoTopBarConfigSchema,
    this.density = NeoDensity.regular,
    Map<String, NeoModulePreference>? modules,
    Map<NeoZone, List<String>>? order,
  }) : modules = Map.unmodifiable(modules ?? const {}),
       order = Map<NeoZone, List<String>>.unmodifiable({
         for (final entry in (order ?? const {}).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  final int schema;

  /// Spacing scale for every card and gap on the bar.
  final NeoDensity density;

  /// Per-module decisions, keyed by descriptor id.
  final Map<String, NeoModulePreference> modules;

  /// Saved left-to-right order per zone. Ids not listed here keep their
  /// registry priority and are appended after the listed ones.
  final Map<NeoZone, List<String>> order;

  static final NeoTopBarConfig empty = NeoTopBarConfig();

  NeoTopBarConfig copyWith({
    Map<String, NeoModulePreference>? modules,
    Map<NeoZone, List<String>>? order,
    NeoDensity? density,
  }) => NeoTopBarConfig(
    schema: schema,
    density: density ?? this.density,
    modules: modules ?? this.modules,
    order: order ?? this.order,
  );

  /// Fills in a preference entry for [id], creating one when missing.
  NeoTopBarConfig withPreference(String id, NeoModulePreference preference) {
    final next = Map<String, NeoModulePreference>.of(modules);
    if (preference.isEmpty) {
      next.remove(id);
    } else {
      next[id] = preference;
    }
    return copyWith(modules: next);
  }

  /// Effective enabled state for [descriptor].
  bool isEnabled(NeoModuleDescriptor descriptor) =>
      modules[descriptor.id]?.enabled ?? descriptor.defaultEnabled;

  /// Effective zone for [descriptor].
  NeoZone zoneOf(NeoModuleDescriptor descriptor) =>
      modules[descriptor.id]?.zone ?? descriptor.zone;

  /// Stored settings for [id]; empty when the user never changed any.
  Map<String, Object?> optionsOf(String id) =>
      modules[id]?.options ?? const <String, Object?>{};

  /// Sets one of [id]'s own settings, dropping the entry entirely when nothing
  /// is left to store so the file does not accumulate empty objects.
  NeoTopBarConfig withOption(String id, String key, Object? value) =>
      withPreference(
        id,
        (modules[id] ?? NeoModulePreference()).withOption(key, value),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    if (density != NeoDensity.regular) 'density': density.name,
    'modules': <String, Object?>{
      for (final entry in modules.entries)
        if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
    },
    'order': <String, Object?>{
      for (final entry in order.entries)
        if (entry.value.isNotEmpty)
          entry.key.name: List<String>.of(entry.value),
    },
  };

  static NeoTopBarConfig fromJson(Object? value) {
    if (value is! Map) return empty;
    final schema = value['schema'];
    if (schema is! int || schema > neoTopBarConfigSchema || schema < 1) {
      // A missing, non-integer or newer schema is treated as "no usable
      // configuration" rather than guessed at.
      return empty;
    }
    final modules = <String, NeoModulePreference>{};
    if (value['modules'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries) {
        final key = entry.key;
        if (key is! String || key.isEmpty) continue;
        final preference = NeoModulePreference.fromJson(entry.value);
        if (!preference.isEmpty) modules[key] = preference;
      }
    }
    final order = <NeoZone, List<String>>{};
    if (value['order'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries) {
        final zone = NeoZone.parse(entry.key);
        final ids = entry.value;
        if (zone == null || ids is! List) continue;
        final seen = <String>{};
        final normalized = <String>[];
        for (final id in ids) {
          if (id is! String || id.isEmpty || !seen.add(id)) continue;
          normalized.add(id);
        }
        if (normalized.isNotEmpty) order[zone] = normalized;
      }
    }
    return NeoTopBarConfig(
      density: NeoDensity.parse(value['density']),
      modules: modules,
      order: order,
    );
  }

  /// Drops ids the current build no longer knows about and de-duplicates the
  /// saved order, so an uninstalled module leaves no stale entries behind.
  ///
  /// This is intentionally separate from [fromJson]: parsing must never invent
  /// decisions, but the running bar should only hold live module ids.
  NeoTopBarConfig prune(Iterable<NeoModuleDescriptor> available) {
    final known = {for (final descriptor in available) descriptor.id};
    final nextModules = <String, NeoModulePreference>{
      for (final entry in modules.entries)
        if (known.contains(entry.key)) entry.key: entry.value,
    };
    final nextOrder = <NeoZone, List<String>>{};
    for (final entry in order.entries) {
      final ids = <String>[];
      final seen = <String>{};
      for (final id in entry.value) {
        if (!known.contains(id) || !seen.add(id)) continue;
        ids.add(id);
      }
      if (ids.isNotEmpty) nextOrder[entry.key] = ids;
    }
    return NeoTopBarConfig(
      schema: schema,
      density: density,
      modules: nextModules,
      order: nextOrder,
    );
  }
}

/// One module resolved for rendering: which zone it belongs to, in what order,
/// and whether it is currently enabled.
class NeoModulePlacement {
  const NeoModulePlacement({
    required this.descriptor,
    required this.zone,
    required this.enabled,
  });

  final NeoModuleDescriptor descriptor;
  final NeoZone zone;
  final bool enabled;
}

/// Resolves the effective zone and order for every [descriptor].
///
/// Disabled modules are still returned so the settings menu can list and
/// re-enable them. Ordering is deterministic: saved order first (in the user's
/// sequence), then remaining modules by priority, then by id.
List<NeoModulePlacement> resolvePlacements({
  required Iterable<NeoModuleDescriptor> descriptors,
  required NeoTopBarConfig config,
}) {
  final all = descriptors.toList()
    ..sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
    });
  final byId = {for (final descriptor in all) descriptor.id: descriptor};

  final placements = <NeoModulePlacement>[];
  for (final zone in NeoZone.values) {
    final inZone = <NeoModuleDescriptor>[
      for (final descriptor in all)
        if (config.zoneOf(descriptor) == zone) descriptor,
    ];
    // Relative order: modules the user saved first, in the saved sequence, then
    // the rest in the base priority/id order. `sortBy` is stable, and `all` is
    // already base-ordered, so unlisted modules keep a deterministic position
    // without a second comparison against an arbitrary insertion sequence.
    final saved = <NeoModuleDescriptor>[];
    final unsaved = <NeoModuleDescriptor>[];
    for (final id in config.order[zone] ?? const <String>[]) {
      final descriptor = byId[id];
      // A saved id whose module moved to another zone is not part of this zone;
      // the zone override wins so no placement is dropped.
      if (descriptor == null || config.zoneOf(descriptor) != zone) continue;
      if (!inZone.contains(descriptor) || saved.contains(descriptor)) continue;
      saved.add(descriptor);
    }
    for (final descriptor in inZone) {
      if (!saved.contains(descriptor)) unsaved.add(descriptor);
    }
    for (final descriptor in <NeoModuleDescriptor>[...saved, ...unsaved]) {
      placements.add(
        NeoModulePlacement(
          descriptor: descriptor,
          zone: zone,
          enabled: config.isEnabled(descriptor),
        ),
      );
    }
  }
  return List.unmodifiable(placements);
}

/// Returns a configuration in which [moduleId] moved [offset] places inside its
/// own zone.
///
/// The zone's **effective** order is materialized first, so a move is well
/// defined even when the user has never ordered that zone: without it there is no
/// list to reorder, since the saved order is a sparse overlay over the registry
/// defaults.
///
/// Moving past either end of the zone is a no-op, which keeps the caller's
/// up/down buttons honest at the boundaries. Modules in other zones are
/// untouched, and a module whose zone the user overrode moves within the zone it
/// currently occupies.
NeoTopBarConfig moveModuleInZone({
  required NeoTopBarConfig config,
  required Iterable<NeoModuleDescriptor> descriptors,
  required String moduleId,
  required int offset,
}) {
  if (offset == 0) return config;
  final placements = resolvePlacements(
    descriptors: descriptors,
    config: config,
  );

  NeoZone? zone;
  for (final placement in placements) {
    if (placement.descriptor.id == moduleId) {
      zone = placement.zone;
      break;
    }
  }
  if (zone == null) return config;

  final ids = <String>[
    for (final placement in placements)
      if (placement.zone == zone) placement.descriptor.id,
  ];
  final index = ids.indexOf(moduleId);
  final destination = index + offset;
  if (index < 0 || destination < 0 || destination >= ids.length) return config;

  ids.removeAt(index);
  ids.insert(destination, moduleId);

  final order = <NeoZone, List<String>>{...config.order, zone: ids};
  return config.copyWith(order: order);
}

/// Returns a configuration in which [moduleId] sits immediately before
/// [beforeId] on the bar, joining [targetZone] when that gap belongs to another
/// zone.
///
/// A null [beforeId] appends to the end of [targetZone]. This is what drag and
/// drop on the bar needs: one operation that both reorders and re-zones, where
/// the drop gap alone decides the result.
NeoTopBarConfig moveModuleToSlot({
  required NeoTopBarConfig config,
  required Iterable<NeoModuleDescriptor> descriptors,
  required String moduleId,
  required NeoZone targetZone,
  String? beforeId,
}) {
  final placements = resolvePlacements(
    descriptors: descriptors,
    config: config,
  );
  final descriptorById = <String, NeoModuleDescriptor>{
    for (final placement in placements)
      placement.descriptor.id: placement.descriptor,
  };
  final descriptor = descriptorById[moduleId];
  if (descriptor == null) return config;
  if (beforeId != null && !descriptorById.containsKey(beforeId)) return config;
  if (beforeId == moduleId) return config;

  // The target zone's effective order, without the moving module: resolving
  // first is what makes a drop well defined before the user has ordered
  // anything, and excluding it here keeps a cross-zone move from duplicating it.
  final targetIds = <String>[
    for (final placement in placements)
      if (placement.zone == targetZone && placement.descriptor.id != moduleId)
        placement.descriptor.id,
  ];
  final insertAt = beforeId == null
      ? targetIds.length
      : targetIds.indexOf(beforeId);
  if (insertAt < 0) return config;
  targetIds.insert(insertAt, moduleId);

  // Every other zone must forget the module. Stale ids are ignored by
  // [resolvePlacements], but leaving them behind makes the file lie about the
  // order the user sees.
  final order = <NeoZone, List<String>>{};
  for (final entry in config.order.entries) {
    if (entry.key == targetZone) continue;
    final kept = <String>[
      for (final id in entry.value)
        if (id != moduleId) id,
    ];
    if (kept.isNotEmpty) order[entry.key] = kept;
  }
  order[targetZone] = targetIds;

  final preference = config.modules[moduleId];
  final modules = Map<String, NeoModulePreference>.of(config.modules);
  final moved = NeoModulePreference(
    enabled: preference?.enabled,
    // Storing the descriptor's own zone as an override would only make the file
    // drift, so it is dropped when the module lands back in its default zone.
    zone: targetZone == descriptor.zone ? null : targetZone,
  );
  if (moved.isEmpty) {
    modules.remove(moduleId);
  } else {
    modules[moduleId] = moved;
  }

  return config.copyWith(order: order, modules: modules);
}
