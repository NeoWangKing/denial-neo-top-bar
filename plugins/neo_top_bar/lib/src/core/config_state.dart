/// Runtime holder for the persisted configuration.
///
/// The bar owns one of these per output instance. It applies changes in memory
/// immediately so a toggle is felt at once, then persists in the background.
/// A read failure surfaces to the settings panel instead of silently reverting
/// what the user just chose.
library;

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'module_descriptor.dart';
import 'preferences.dart';

class NeoTopBarConfigState extends ChangeNotifier {
  NeoTopBarConfigState._({
    required this.store,
    required NeoTopBarConfig config,
    this.loadError,
  }) {
    _config = config;
  }

  final NeoTopBarPreferencesStore store;
  late NeoTopBarConfig _config;

  /// Set when the on-disk file could not be read. The bar keeps running on
  /// defaults; the settings panel shows this so the user knows why.
  final String? loadError;

  /// Set when the most recent save failed.
  String? saveError;

  NeoTopBarConfig get config => _config;

  /// Loads the configuration, falling back to defaults on an unreadable file.
  static Future<NeoTopBarConfigState> load(
    NeoTopBarPreferencesStore store,
  ) async {
    try {
      final config = await store.read();
      return NeoTopBarConfigState._(store: store, config: config);
    } catch (error) {
      return NeoTopBarConfigState._(
        store: store,
        config: NeoTopBarConfig.empty,
        loadError: '$error',
      );
    }
  }

  /// Changes the bar's spacing scale and persists the result.
  Future<void> setDensity(NeoDensity density) =>
      _update(_config.copyWith(density: density));

  /// Puts one instance on the bar or takes it off, and persists the result.
  ///
  /// Every instance has an explicit `enabled` once it has been touched: a copy
  /// the user added is only hidden this way, and hiding the *first* instance has
  /// to be recorded too, or [resolvePlacements] would synthesize it again from
  /// its descriptor.
  Future<void> setEnabled(String id, {required bool enabled}) => _update(
    _config.withInstance(
      id,
      (_config.instanceEntry(id) ?? NeoModuleInstancePreference(moduleId: id))
          .withEnabled(enabled),
    ),
  );

  /// Adds another copy of [moduleId] to [zone] and persists the result.
  ///
  /// The copy is appended to the zone and switched on, as one action: three
  /// changes the user made by pressing one button, so they are saved once and
  /// one rebuild follows.
  Future<void> addInstance(
    String moduleId, {
    required NeoZone zone,
    required Iterable<NeoModuleDescriptor> descriptors,
    NeoZone? defaultZone,
  }) {
    final placements = resolvePlacements(
      descriptors: descriptors,
      config: _config,
    );
    // Only the instances that are *on the bar* occupy a number: a copy the user
    // removed is free to be reused, which keeps the numbers on the cards from
    // climbing every time something is removed and added again.
    final taken = <String>[
      for (final placement in placements)
        if (placement.enabled) placement.id,
    ];
    final id = neoNextInstanceId(moduleId, taken);
    final preference =
        (_config.instanceEntry(id) ??
                NeoModuleInstancePreference(moduleId: moduleId))
            .withEnabled(true)
            .withZone(zone == defaultZone ? null : zone);
    return _update(
      moveModuleToSlot(
        config: _config.withInstance(id, preference),
        descriptors: descriptors,
        instanceId: id,
        targetZone: zone,
        beforeId: null,
      ),
    );
  }

  /// Takes one instance off the bar, forgetting the copy entirely.
  ///
  /// The first instance of a module can only be switched off: forgetting it would
  /// make [resolvePlacements] synthesize it again from its descriptor.
  Future<void> removeInstance(
    String id, {
    required Iterable<NeoModuleDescriptor> descriptors,
  }) {
    final placement = resolvePlacements(
      descriptors: descriptors,
      config: _config,
    ).where((entry) => entry.id == id).firstOrNull;
    if (placement == null) return Future<void>.value();
    if (placement.number <= 1) return setEnabled(id, enabled: false);
    return _update(_config.withoutInstance(id));
  }

  /// Changes one of an instance's own settings and persists the result.
  ///
  /// The value is stored opaquely; only the module knows what it means. Passing
  /// null removes the setting so the module falls back to its default.
  Future<void> setOption(String id, String key, Object? value) =>
      _update(_config.withOption(id, key, value));

  /// Moves one instance to another zone and persists the result.
  Future<void> setZone(
    String id, {
    required NeoZone zone,
    NeoZone? defaultZone,
  }) => _update(
    _config.withInstance(
      id,
      (_config.instanceEntry(id) ?? NeoModuleInstancePreference(moduleId: id))
          .withZone(zone == defaultZone ? null : zone),
    ),
  );

  /// Moves one module [offset] places inside its own zone and persists it.
  ///
  /// Delegates to [moveModuleInZone], which materializes the zone's effective
  /// order first, so this is well defined even before the user has ordered
  /// anything. Moving past either end is a no-op, so the caller's buttons stay
  /// honest at the boundaries.
  Future<void> move(
    String id, {
    required int offset,
    required Iterable<NeoModuleDescriptor> descriptors,
  }) => _update(
    moveModuleInZone(
      config: _config,
      descriptors: descriptors,
      instanceId: id,
      offset: offset,
    ),
  );

  /// Drops [id] into the gap before [beforeId], joining [targetZone] when that
  /// gap belongs to another zone, and persists it.
  ///
  /// This is the drag-and-drop operation on the bar itself: the drop gap alone
  /// decides both position and zone.
  Future<void> moveToSlot(
    String id, {
    required NeoZone targetZone,
    required String? beforeId,
    required Iterable<NeoModuleDescriptor> descriptors,
  }) => _update(
    moveModuleToSlot(
      config: _config,
      descriptors: descriptors,
      instanceId: id,
      targetZone: targetZone,
      beforeId: beforeId,
    ),
  );

  /// Drops ids the running build no longer knows about.
  Future<void> prune(Iterable<NeoModuleDescriptor> descriptors) async {
    final pruned = _config.prune(descriptors);
    _config = pruned;
    saveError = null;
    notifyListeners();
    try {
      await store.save(pruned);
    } catch (error) {
      saveError = '$error';
      notifyListeners();
    }
  }

  Future<void> _update(NeoTopBarConfig next) async {
    _config = next;
    saveError = null;
    notifyListeners();
    try {
      await store.save(next);
    } catch (error) {
      saveError = '$error';
      notifyListeners();
    }
  }
}
