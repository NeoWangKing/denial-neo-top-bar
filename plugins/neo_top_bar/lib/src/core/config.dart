/// Serializable user configuration for the bar.
///
/// The file is a sparse overlay over the built-in defaults, not a full
/// snapshot: it records only the *instances* the user changed, their chosen
/// order and the ones the user removed. Anything absent falls back to the
/// registry, so a new built-in module appears with its own default instead of
/// being silently enabled or disabled by an old file.
///
/// A bar is built from **instances**, not from modules: the same kind of module
/// may appear several times, in one zone or in several. An instance id is the
/// module id for the first one and `moduleId#2`, `moduleId#3`… after that, which
/// is what makes a second copy addressable for ordering, settings and removal
/// ([neoInstanceId]).
library;

import 'module_descriptor.dart';

/// Current persisted schema.
///
/// v1 stored one preference per *module*; v2 stores one per *instance*. The two
/// are the same shape for the first instance of each module, so a v1 file is
/// read as v2 with no rewriting and is upgraded in place on the next save.
/// A file from a newer build is rejected rather than guessed at.
const int neoTopBarConfigSchema = 2;

/// The persisted id of the [number]-th instance of [moduleId].
///
/// The first instance keeps the bare module id. That is what makes an old file
/// already valid, and it keeps the common case — one of each module — free of
/// numbering noise.
String neoInstanceId(String moduleId, int number) =>
    number <= 1 ? moduleId : '$moduleId#$number';

/// The number [instanceId] encodes for [moduleId], or 0 when it is not an
/// instance of that module.
int neoInstanceNumber(String instanceId, String moduleId) {
  if (instanceId == moduleId) return 1;
  final prefix = '$moduleId#';
  if (!instanceId.startsWith(prefix)) return 0;
  final number = int.tryParse(instanceId.substring(prefix.length));
  return number != null && number >= 2 ? number : 0;
}

/// The lowest unused instance id of [moduleId] given the ids already on the bar.
///
/// Lowest rather than next-highest: removing the second of three copies and
/// adding another should produce "2" again, not "4", or the numbers the user
/// reads on the cards would drift upwards forever.
String neoNextInstanceId(String moduleId, Iterable<String> taken) {
  final used = taken.toSet();
  for (var number = 1; ; number++) {
    final id = neoInstanceId(moduleId, number);
    if (!used.contains(id)) return id;
  }
}

/// The title a settings card shows for the [number]-th instance of [label].
String neoInstanceLabel(String label, int number) =>
    number <= 1 ? label : '$label $number';

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

/// One instance's user decision.
class NeoModuleInstancePreference {
  const NeoModuleInstancePreference({
    required this.moduleId,
    this.enabled,
    this.zone,
    this.options = const <String, Object?>{},
  });

  /// The module kind this instance is a copy of.
  ///
  /// Stored even for the first instance, whose id already implies it: an
  /// explicit field is what lets a future id scheme change without a migration,
  /// and it makes the file readable on its own.
  final String moduleId;

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

  /// Whether no decision has been made at all.
  bool get isEmpty => enabled == null && zone == null && options.isEmpty;

  /// Whether storing this under [instanceId] would say nothing the defaults do
  /// not already say, and can therefore be left out of the file.
  ///
  /// Only the *first* instance can be redundant: a copy exists precisely because
  /// of its entry, so an entry for `clock#2` that only names its module is the
  /// whole point of that line and has to be written.
  bool isRedundant(String instanceId) => instanceId == moduleId && isEmpty;

  /// This preference with the enabled flag replaced, keeping everything else.
  ///
  /// Every mutator goes through one of these, because building a fresh
  /// preference from scratch silently drops the fields the caller did not
  /// mention: toggling a module used to forget the zone the user had moved it
  /// to, and would now forget its own settings as well.
  NeoModuleInstancePreference withEnabled(bool value) =>
      NeoModuleInstancePreference(
        moduleId: moduleId,
        enabled: value,
        zone: zone,
        options: options,
      );

  /// This preference with the zone replaced, keeping everything else.
  NeoModuleInstancePreference withZone(NeoZone? value) =>
      NeoModuleInstancePreference(
        moduleId: moduleId,
        enabled: enabled,
        zone: value,
        options: options,
      );

  /// This preference with [key] set to [value], or removed when null.
  NeoModuleInstancePreference withOption(String key, Object? value) {
    final next = Map<String, Object?>.of(options);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return NeoModuleInstancePreference(
      moduleId: moduleId,
      enabled: enabled,
      zone: zone,
      // Frozen so nothing can reach into a preference and edit it in place; the
      // const constructor cannot do this itself, which is why only the mutators
      // go through here.
      options: Map<String, Object?>.unmodifiable(next),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'module': moduleId,
    if (enabled != null) 'enabled': enabled,
    if (zone != null) 'zone': zone!.name,
    if (options.isNotEmpty)
      'options': <String, Object?>{
        for (final entry in options.entries)
          if (entry.value != null) entry.key: entry.value,
      },
  };

  /// Reads one stored instance, or null when the entry is unusable.
  ///
  /// [instanceId] is only used for the schema-1 shape, where the key *was* the
  /// module id; a schema-2 entry names its module explicitly.
  static NeoModuleInstancePreference? fromJson(
    String instanceId,
    Object? value, {
    required bool keyIsModuleId,
  }) {
    if (value is! Map) return null;
    final moduleId = keyIsModuleId
        ? instanceId
        : (value['module'] is String && (value['module']! as String).isNotEmpty
              ? value['module']! as String
              : null);
    if (moduleId == null) return null;
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
    return NeoModuleInstancePreference(
      moduleId: moduleId,
      enabled: enabled is bool ? enabled : null,
      zone: NeoZone.parse(value['zone']),
      options: options,
    );
  }
}

/// Whether [value] is something the writer can round-trip.
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
    Map<String, NeoModuleInstancePreference>? instances,
    Map<NeoZone, List<String>>? order,
  }) : instances = Map.unmodifiable(instances ?? const {}),
       order = Map<NeoZone, List<String>>.unmodifiable({
         for (final entry in (order ?? const {}).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  final int schema;

  /// Spacing scale for every card and gap on the bar.
  final NeoDensity density;

  /// Per-instance decisions, keyed by instance id.
  ///
  /// Sparse: the first instance of a module the user never changed has no entry
  /// at all, and is synthesized from its descriptor by [resolvePlacements].
  final Map<String, NeoModuleInstancePreference> instances;

  /// Saved left-to-right order per zone. Ids not listed here keep their
  /// registry priority and are appended after the listed ones.
  final Map<NeoZone, List<String>> order;

  static final NeoTopBarConfig empty = NeoTopBarConfig();

  NeoTopBarConfig copyWith({
    Map<String, NeoModuleInstancePreference>? instances,
    Map<NeoZone, List<String>>? order,
    NeoDensity? density,
  }) => NeoTopBarConfig(
    schema: schema,
    density: density ?? this.density,
    instances: instances ?? this.instances,
    order: order ?? this.order,
  );

  /// Fills in an entry for [instanceId], creating one when missing.
  NeoTopBarConfig withInstance(
    String instanceId,
    NeoModuleInstancePreference preference,
  ) {
    final next = Map<String, NeoModuleInstancePreference>.of(instances);
    if (preference.isRedundant(instanceId)) {
      next.remove(instanceId);
    } else {
      next[instanceId] = preference;
    }
    return copyWith(instances: next);
  }

  /// Forgets [instanceId] entirely, including its place in every zone.
  ///
  /// Used for the copies the user added: the first instance of a module cannot
  /// be forgotten, because [resolvePlacements] would synthesize it again from its
  /// descriptor — hiding it means storing `enabled: false` instead.
  NeoTopBarConfig withoutInstance(String instanceId) {
    final next = Map<String, NeoModuleInstancePreference>.of(instances)
      ..remove(instanceId);
    final order = <NeoZone, List<String>>{};
    for (final entry in this.order.entries) {
      final kept = <String>[
        for (final id in entry.value)
          if (id != instanceId) id,
      ];
      if (kept.isNotEmpty) order[entry.key] = kept;
    }
    return copyWith(instances: next, order: order);
  }

  /// The stored entry for [instanceId], when the user changed it.
  NeoModuleInstancePreference? instanceEntry(String instanceId) =>
      instances[instanceId];

  /// Stored settings for [instanceId]; empty when the user never changed any.
  Map<String, Object?> optionsOf(String instanceId) =>
      instances[instanceId]?.options ?? const <String, Object?>{};

  /// Sets one of [instanceId]'s own settings, dropping the entry entirely when
  /// nothing is left to store so the file does not accumulate empty objects.
  NeoTopBarConfig withOption(String instanceId, String key, Object? value) {
    final existing =
        instances[instanceId] ??
        NeoModuleInstancePreference(
          moduleId: instanceId,
          // A missing entry means the module sits at its descriptor default, so
          // writing a setting has to make that explicit only when it differs.
          zone: null,
        );
    return withInstance(instanceId, existing.withOption(key, value));
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    if (density != NeoDensity.regular) 'density': density.name,
    'instances': <String, Object?>{
      for (final entry in instances.entries)
        if (!entry.value.isRedundant(entry.key))
          entry.key: entry.value.toJson(),
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
    // Schema 1 stored one entry per module under `modules`; schema 2 stores one
    // per instance under `instances`. For the first instance of a module the two
    // are the same thing — its id *is* the module id — so a v1 entry is read as
    // the v2 instance of the same name and nothing else has to change.
    final legacy = schema < 2;
    final raw = legacy ? value['modules'] : value['instances'];
    final entries = <String, NeoModuleInstancePreference>{};
    if (raw case final Map<Object?, Object?> rawEntries) {
      for (final entry in rawEntries.entries) {
        final key = entry.key;
        if (key is! String || key.isEmpty) continue;
        final preference = NeoModuleInstancePreference.fromJson(
          key,
          entry.value,
          keyIsModuleId: legacy,
        );
        if (preference == null || preference.isRedundant(key)) continue;
        entries[key] = preference;
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
      instances: entries,
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
    // An instance survives while the *module* it copies is still installed; its
    // own id is whatever it was named.
    final nextInstances = <String, NeoModuleInstancePreference>{
      for (final entry in instances.entries)
        if (known.contains(entry.value.moduleId)) entry.key: entry.value,
    };
    final live = <String>{
      for (final placement in resolvePlacements(
        descriptors: available,
        config: copyWith(instances: nextInstances),
      ))
        placement.id,
    };
    final nextOrder = <NeoZone, List<String>>{};
    for (final entry in order.entries) {
      final ids = <String>[];
      final seen = <String>{};
      for (final id in entry.value) {
        if (!live.contains(id) || !seen.add(id)) continue;
        ids.add(id);
      }
      if (ids.isNotEmpty) nextOrder[entry.key] = ids;
    }
    return NeoTopBarConfig(
      schema: schema,
      density: density,
      instances: nextInstances,
      order: nextOrder,
    );
  }
}

/// One module resolved for rendering: which zone it belongs to, in what order,
/// and whether it is currently enabled.
class NeoModulePlacement {
  const NeoModulePlacement({
    required this.id,
    required this.moduleId,
    required this.descriptor,
    required this.zone,
    required this.enabled,
    this.options = const <String, Object?>{},
  });

  /// Instance id: the module id for the first copy, `moduleId#2` and up after
  /// that. This is what the bar keys pills, drag state and settings by.
  final String id;

  /// Module kind, i.e. which implementation draws this instance.
  final String moduleId;

  final NeoModuleDescriptor descriptor;
  final NeoZone zone;
  final bool enabled;

  /// This instance's own settings.
  final Map<String, Object?> options;

  /// The number shown on this instance's card: 1 for the first copy.
  int get number => neoInstanceNumber(id, moduleId);

  /// The title a card shows for this instance.
  String get label => neoInstanceLabel(descriptor.label, number);

  @override
  String toString() =>
      'NeoModulePlacement($id, ${zone.name}, enabled: $enabled)';
}

/// One instance the bar should have, before its zone and order are settled.
class _InstanceSeed {
  const _InstanceSeed({
    required this.id,
    required this.moduleId,
    required this.descriptor,
    required this.number,
    required this.enabled,
    required this.zone,
    required this.options,
  });

  final String id;
  final String moduleId;
  final NeoModuleDescriptor descriptor;
  final int number;
  final bool enabled;
  final NeoZone zone;
  final Map<String, Object?> options;
}

/// Resolves the effective instances: which copies exist, their zone, their order
/// and whether they are on the bar.
///
/// Every module always has its first instance ([neoInstanceId] with 1), whether
/// or not the file mentions it, so a newly installed module appears with its
/// descriptor's defaults. Copies beyond the first exist only because the user
/// added them, and are read from the file.
///
/// Disabled instances are still returned so the settings card can list and remove
/// them. Ordering is deterministic: saved order first (in the user's sequence),
/// then the rest by priority, then by instance number, then by id.
List<NeoModulePlacement> resolvePlacements({
  required Iterable<NeoModuleDescriptor> descriptors,
  required NeoTopBarConfig config,
}) {
  final byModuleId = <String, NeoModuleDescriptor>{
    for (final descriptor in descriptors) descriptor.id: descriptor,
  };
  final seeds = <_InstanceSeed>[];

  for (final descriptor in descriptors) {
    final entry = config.instances[descriptor.id];
    seeds.add(
      _InstanceSeed(
        id: descriptor.id,
        moduleId: descriptor.id,
        descriptor: descriptor,
        number: 1,
        enabled: entry?.enabled ?? descriptor.defaultEnabled,
        zone: entry?.zone ?? descriptor.zone,
        options: entry?.options ?? const <String, Object?>{},
      ),
    );
  }
  for (final entry in config.instances.entries) {
    final preference = entry.value;
    final descriptor = byModuleId[preference.moduleId];
    if (descriptor == null) continue;
    final number = neoInstanceNumber(entry.key, preference.moduleId);
    // Number 1 is the implicit first instance above; 0 means the key is not an
    // instance of the module it claims.
    if (number <= 1) continue;
    seeds.add(
      _InstanceSeed(
        id: entry.key,
        moduleId: preference.moduleId,
        descriptor: descriptor,
        number: number,
        enabled: preference.enabled ?? true,
        zone: preference.zone ?? descriptor.zone,
        options: preference.options,
      ),
    );
  }

  int byPriority(_InstanceSeed left, _InstanceSeed right) {
    final byDescriptorPriority = left.descriptor.priority.compareTo(
      right.descriptor.priority,
    );
    if (byDescriptorPriority != 0) return byDescriptorPriority;
    final byNumber = left.number.compareTo(right.number);
    if (byNumber != 0) return byNumber;
    return left.id.compareTo(right.id);
  }

  final placements = <NeoModulePlacement>[];
  for (final zone in NeoZone.values) {
    final inZone = <_InstanceSeed>[
      for (final seed in seeds)
        if (seed.zone == zone) seed,
    ]..sort(byPriority);
    final byId = <String, _InstanceSeed>{
      for (final seed in inZone) seed.id: seed,
    };

    // Relative order: instances the user saved first, in the saved sequence, then
    // the rest in the base priority order. Unlisted instances therefore keep a
    // deterministic place without a second comparison against an arbitrary
    // insertion sequence.
    final saved = <_InstanceSeed>[];
    for (final id in config.order[zone] ?? const <String>[]) {
      final seed = byId[id];
      // A saved id whose instance moved to another zone is not part of this
      // zone; the zone wins so no placement is dropped.
      if (seed == null || saved.contains(seed)) continue;
      saved.add(seed);
    }
    for (final seed in <_InstanceSeed>[...saved, ...inZone]) {
      if (saved.contains(seed) && placements.any((p) => p.id == seed.id)) {
        continue;
      }
      placements.add(
        NeoModulePlacement(
          id: seed.id,
          moduleId: seed.moduleId,
          descriptor: seed.descriptor,
          zone: zone,
          enabled: seed.enabled,
          options: seed.options,
        ),
      );
    }
  }
  return List.unmodifiable(placements);
}

/// Returns a configuration in which one instance moved [offset] places inside
/// its own zone.
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
  required String instanceId,
  required int offset,
}) {
  if (offset == 0) return config;
  final placements = resolvePlacements(
    descriptors: descriptors,
    config: config,
  );

  NeoZone? zone;
  for (final placement in placements) {
    if (placement.id == instanceId) {
      zone = placement.zone;
      break;
    }
  }
  if (zone == null) return config;

  final ids = <String>[
    for (final placement in placements)
      if (placement.zone == zone) placement.id,
  ];
  final index = ids.indexOf(instanceId);
  final destination = index + offset;
  if (index < 0 || destination < 0 || destination >= ids.length) return config;

  ids.removeAt(index);
  ids.insert(destination, instanceId);

  final order = <NeoZone, List<String>>{...config.order, zone: ids};
  return config.copyWith(order: order);
}

/// Returns a configuration in which one instance sits immediately before
/// [beforeId] on the bar, joining [targetZone] when that gap belongs to another
/// zone.
///
/// A null [beforeId] appends to the end of [targetZone]. This is what drag and
/// drop on the bar needs: one operation that both reorders and re-zones, where
/// the drop gap alone decides the result.
NeoTopBarConfig moveModuleToSlot({
  required NeoTopBarConfig config,
  required Iterable<NeoModuleDescriptor> descriptors,
  required String instanceId,
  required NeoZone targetZone,
  String? beforeId,
}) {
  final placements = resolvePlacements(
    descriptors: descriptors,
    config: config,
  );
  final placementById = <String, NeoModulePlacement>{
    for (final placement in placements) placement.id: placement,
  };
  final placement = placementById[instanceId];
  if (placement == null) return config;
  if (beforeId != null && !placementById.containsKey(beforeId)) return config;
  if (beforeId == instanceId) return config;

  // The target zone's effective order, without the moving instance: resolving
  // first is what makes a drop well defined before the user has ordered
  // anything, and excluding it here keeps a cross-zone move from duplicating it.
  final targetIds = <String>[
    for (final other in placements)
      if (other.zone == targetZone && other.id != instanceId) other.id,
  ];
  final insertAt = beforeId == null
      ? targetIds.length
      : targetIds.indexOf(beforeId);
  if (insertAt < 0) return config;
  targetIds.insert(insertAt, instanceId);

  // Every other zone must forget the instance. Stale ids are ignored by
  // [resolvePlacements], but leaving them behind makes the file lie about the
  // order the user sees.
  final order = <NeoZone, List<String>>{};
  for (final entry in config.order.entries) {
    if (entry.key == targetZone) continue;
    final kept = <String>[
      for (final id in entry.value)
        if (id != instanceId) id,
    ];
    if (kept.isNotEmpty) order[entry.key] = kept;
  }
  order[targetZone] = targetIds;

  final existing =
      config.instances[instanceId] ??
      NeoModuleInstancePreference(moduleId: placement.moduleId);
  final moved = existing.withZone(
    // Storing the descriptor's own zone as an override would only make the file
    // drift, so it is dropped when the instance lands back in its default zone.
    targetZone == placement.descriptor.zone ? null : targetZone,
  );
  // The instance is on the bar now: moving it there is how the add button
  // places a new copy, and how a removed copy comes back.
  final restored = moved.withEnabled(true);
  return config.copyWith(
    order: order,
    instances: <String, NeoModuleInstancePreference>{
      ...config.instances,
      instanceId: restored,
    },
  );
}
