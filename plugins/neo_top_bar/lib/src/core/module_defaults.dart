/// Canonical metadata for every built-in module.
///
/// This is the single source of truth for a module's id, default zone and
/// priority. The module implementations, the registry and the default-layout
/// tests all read these constants, so what the bar actually shows by default can
/// never drift from what the tests assert.
///
/// A module's name and description are looked up from its id in the string
/// catalogue instead, which is what lets the settings panel speak the language
/// Denial is running in.
///
/// Keep this file free of Flutter imports: the layout tests run on plain Dart.
library;

import 'module_descriptor.dart';

/// Stable module ids.
///
/// These strings are persisted in the user's configuration. Never rename one
/// without a migration, or the user's choice for that module is silently
/// dropped. The descriptors below and the registry both read these, so an id is
/// spelled exactly once.
abstract final class NeoModuleIds {
  static const String workspaces = 'workspaces';
  static const String launcher = 'launcher';
  static const String tray = 'tray';
  static const String notifications = 'notifications';
  static const String media = 'media';
  static const String battery = 'battery';
  static const String controlCenter = 'control_center';
  static const String cpu = 'cpu';
  static const String gpu = 'gpu';
  static const String clock = 'clock';
}

/// Left zone: workspaces.
const NeoModuleDescriptor workspacesModule = NeoModuleDescriptor(
  id: NeoModuleIds.workspaces,
  zone: NeoZone.start,
  priority: 10,
);

/// Centre zone: the launcher entry point.
const NeoModuleDescriptor launcherModule = NeoModuleDescriptor(
  id: NeoModuleIds.launcher,
  zone: NeoZone.center,
  priority: 20,
);

/// Right zone, ordered outward from the centre: tray, status, clock.
const NeoModuleDescriptor trayModule = NeoModuleDescriptor(
  id: NeoModuleIds.tray,
  zone: NeoZone.end,
  priority: 10,
);

const NeoModuleDescriptor notificationsModule = NeoModuleDescriptor(
  id: NeoModuleIds.notifications,
  zone: NeoZone.end,
  priority: 20,
);

const NeoModuleDescriptor mediaModule = NeoModuleDescriptor(
  id: NeoModuleIds.media,
  zone: NeoZone.end,
  priority: 30,
  defaultEnabled: false,
);

const NeoModuleDescriptor batteryModule = NeoModuleDescriptor(
  id: NeoModuleIds.battery,
  zone: NeoZone.end,
  priority: 40,
);

/// The control centre sits just inside the clock, where a status menu is looked
/// for: it is the pill that opens the panel, and it carries the at-a-glance
/// readouts (volume, Wi-Fi, Bluetooth, battery) that the panels below expand on.
const NeoModuleDescriptor controlCenterModule = NeoModuleDescriptor(
  id: NeoModuleIds.controlCenter,
  zone: NeoZone.end,
  priority: 85,
);

const NeoModuleDescriptor cpuModule = NeoModuleDescriptor(
  id: NeoModuleIds.cpu,
  zone: NeoZone.end,
  priority: 50,
  defaultEnabled: false,
);

const NeoModuleDescriptor gpuModule = NeoModuleDescriptor(
  id: NeoModuleIds.gpu,
  zone: NeoZone.end,
  priority: 60,
  defaultEnabled: false,
);

/// The clock is the outermost pill on the trailing side.
const NeoModuleDescriptor clockModule = NeoModuleDescriptor(
  id: NeoModuleIds.clock,
  zone: NeoZone.end,
  priority: 90,
);

/// Every built-in module, in registry order.
///
/// The sequence only settles ties between modules that share a zone and
/// priority; effective placement comes from the zone and priority.
const List<NeoModuleDescriptor> neoTopBarDefaultModules = <NeoModuleDescriptor>[
  workspacesModule,
  launcherModule,
  trayModule,
  notificationsModule,
  mediaModule,
  batteryModule,
  cpuModule,
  gpuModule,
  controlCenterModule,
  clockModule,
];
