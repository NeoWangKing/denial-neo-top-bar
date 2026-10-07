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

  /// Enables or disables one module and persists the result.
  Future<void> setEnabled(String id, {required bool enabled}) => _update(
    _config.withPreference(id, NeoModulePreference(enabled: enabled)),
  );

  /// Moves one module to another zone and persists the result.
  Future<void> setZone(
    String id, {
    required NeoZone zone,
    NeoZone? defaultZone,
  }) {
    final preference = _config.modules[id];
    return _update(
      _config.withPreference(
        id,
        NeoModulePreference(
          enabled: preference?.enabled,
          // Storing the default zone as an explicit value is harmless but makes
          // the file drift; drop the override when it matches the default.
          zone: zone == defaultZone ? null : zone,
        ),
      ),
    );
  }

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
      moduleId: id,
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
      moduleId: id,
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
