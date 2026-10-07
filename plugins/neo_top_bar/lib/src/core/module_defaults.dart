/// Canonical metadata for every built-in module.
///
/// This is the single source of truth for a module's id, label, description,
/// default zone and priority. The module implementations, the registry and the
/// default-layout tests all read these constants, so what the bar actually shows
/// by default can never drift from what the tests assert.
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
  label: '工作区胶囊',
  description: '显示工作区数量、当前工作区与占用状态，点击切换',
  zone: NeoZone.start,
  priority: 10,
);

/// Centre zone: the launcher entry point.
const NeoModuleDescriptor launcherModule = NeoModuleDescriptor(
  id: NeoModuleIds.launcher,
  label: '应用启动器',
  description: '中间的启动器入口，点击打开应用列表与搜索',
  zone: NeoZone.center,
  priority: 20,
);

/// Right zone, ordered outward from the centre: tray, status, clock.
const NeoModuleDescriptor trayModule = NeoModuleDescriptor(
  id: NeoModuleIds.tray,
  label: '系统托盘',
  description: 'StatusNotifier 图标，菜单与激活由宿主管理',
  zone: NeoZone.end,
  priority: 10,
);

const NeoModuleDescriptor notificationsModule = NeoModuleDescriptor(
  id: NeoModuleIds.notifications,
  label: '通知',
  description: '未读徽章与通知历史面板，可逐条忽略或全部清除',
  zone: NeoZone.end,
  priority: 20,
);

const NeoModuleDescriptor mediaModule = NeoModuleDescriptor(
  id: NeoModuleIds.media,
  label: '媒体播放',
  description: '当前播放曲目与上一首/播放暂停/下一首按钮',
  zone: NeoZone.end,
  priority: 30,
  defaultEnabled: false,
);

const NeoModuleDescriptor batteryModule = NeoModuleDescriptor(
  id: NeoModuleIds.battery,
  label: '电池与电源',
  description: '电量与充电状态，点击打开电源设置',
  zone: NeoZone.end,
  priority: 40,
);

/// The control centre sits just inside the clock, where a status menu is looked
/// for: it is the pill that opens the panel, and it carries the at-a-glance
/// readouts (volume, Wi-Fi, Bluetooth, battery) that the panels below expand on.
const NeoModuleDescriptor controlCenterModule = NeoModuleDescriptor(
  id: NeoModuleIds.controlCenter,
  label: '控制中心',
  description: '音量、亮度、Wi-Fi、蓝牙、深浅模式与开关机的弹出面板',
  zone: NeoZone.end,
  priority: 85,
);

const NeoModuleDescriptor cpuModule = NeoModuleDescriptor(
  id: NeoModuleIds.cpu,
  label: 'CPU 负载',
  description: 'CPU 使用率折线、百分比与温度',
  zone: NeoZone.end,
  priority: 50,
  defaultEnabled: false,
);

const NeoModuleDescriptor gpuModule = NeoModuleDescriptor(
  id: NeoModuleIds.gpu,
  label: 'GPU 负载',
  description: '每块显卡的使用率折线与温度',
  zone: NeoZone.end,
  priority: 60,
  defaultEnabled: false,
);

/// The clock is the outermost pill on the trailing side.
const NeoModuleDescriptor clockModule = NeoModuleDescriptor(
  id: NeoModuleIds.clock,
  label: '时钟与日期',
  description: '日期加时钟，点击打开日历面板',
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
