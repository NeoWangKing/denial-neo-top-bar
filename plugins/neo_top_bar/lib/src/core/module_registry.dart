/// The built-in module registry.
///
/// Module metadata lives in `module_defaults.dart`. This file only wires each
/// descriptor id to its implementation and derives [NeoTopBarModules.all] from
/// that authoritative list, so the registry can never disagree with the
/// default layout the tests assert.
///
/// Adding a module means adding its descriptor to `module_defaults.dart` and its
/// instance to [_factories] here. A descriptor without an implementation throws
/// on first use instead of silently dropping a pill.
library;

import 'module.dart';
import 'module_defaults.dart';
import 'module_descriptor.dart';
import '../modules/battery_module.dart';
import '../modules/clock_module.dart';
import '../modules/launcher_module.dart';
import '../modules/load_module.dart';
import '../modules/media_module.dart';
import '../modules/notifications_module.dart';
import '../modules/tray_module.dart';
import '../modules/workspace_module.dart';

/// Re-exported so callers can reach module ids from the registry import.
export 'module_defaults.dart' show NeoModuleIds;

abstract final class NeoTopBarModules {
  static const Map<String, NeoModule> _factories = <String, NeoModule>{
    NeoModuleIds.workspaces: WorkspaceModule(),
    NeoModuleIds.launcher: LauncherModule(),
    NeoModuleIds.tray: TrayModule(),
    NeoModuleIds.notifications: NotificationsModule(),
    NeoModuleIds.media: MediaModule(),
    NeoModuleIds.battery: BatteryModule(),
    NeoModuleIds.cpu: CpuModule(),
    NeoModuleIds.gpu: GpuModule(),
    NeoModuleIds.clock: ClockModule(),
  };

  /// Every module, in [neoTopBarDefaultModules] order.
  ///
  /// Throws if a descriptor has no implementation, because a missing pill is
  /// much harder to notice than a failed lookup.
  static final List<NeoModule> all = List<NeoModule>.unmodifiable(<NeoModule>[
    for (final descriptor in neoTopBarDefaultModules)
      _factories[descriptor.id] ??
          (throw StateError(
            'Module "${descriptor.id}" is declared in module_defaults.dart '
            'but has no implementation in NeoTopBarModules._factories.',
          )),
  ]);

  static final Map<String, NeoModule> _byId = <String, NeoModule>{
    for (final module in all) module.descriptor.id: module,
  };

  /// All descriptors, in registry order.
  static List<NeoModuleDescriptor> get descriptors =>
      List<NeoModuleDescriptor>.unmodifiable(
        all.map((module) => module.descriptor),
      );

  static NeoModule? byId(String id) => _byId[id];

  static NeoModuleDescriptor? descriptorOf(String id) => _byId[id]?.descriptor;
}
