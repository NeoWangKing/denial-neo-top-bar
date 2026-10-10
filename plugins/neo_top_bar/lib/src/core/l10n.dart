/// Every word this plugin says, in the language Denial is running in.
///
/// Denial localizes its own shell through `AppLocalizations`, and the locale the
/// shell resolved is readable from any widget below it. Plugin text is not part of
/// that catalogue, so this file is the plugin's own catalogue: one class, one
/// getter per phrase, Chinese and English side by side. Keeping both languages in
/// the same expression is deliberate — a translator sees what a phrase is used
/// for, and a phrase can never be added with only one language behind it.
///
/// Chinese is written first because it is what the plugin was written in and what
/// the fallback resolves to; English is the translation. The two supported
/// languages are exactly the two Denial ships, so nothing here needs a third.
///
/// Kept free of Flutter so the pure logic files can depend on it and still run
/// under plain `dart test`; the `BuildContext` half lives in `l10n_context.dart`.
library;

import 'clock_options.dart';
import 'control_center_model.dart';
import 'launcher_options.dart';
import 'module_descriptor.dart';
import 'module_defaults.dart';

/// The languages this plugin speaks.
enum NeoLanguage {
  /// Simplified Chinese, Denial's `zh` locale.
  zh,

  /// English, Denial's `en` locale and the fallback for anything else.
  en,
}

/// The language Denial has been configured to run in.
///
/// Anything that is not Chinese resolves to English: Denial only ships the two,
/// so a third locale means the user reads English rather than Chinese.
NeoLanguage neoLanguageFromCode(String? languageCode) {
  final code = (languageCode ?? '').toLowerCase();
  return code.startsWith('zh') ? NeoLanguage.zh : NeoLanguage.en;
}

/// What is used when no locale can be read at all.
///
/// Only reachable outside a `Localizations` scope — a bare widget test, or a
/// context above the shell's own scope. Chinese keeps the plugin's historic look
/// rather than silently flipping the whole UI to English.
const NeoLanguage neoFallbackLanguage = NeoLanguage.zh;

/// The catalogue for one language.
///
/// Construct one with [neoStringsFor] and read it through [neoStringsOf] inside a
/// widget. It is a value object: two instances of the same language are
/// interchangeable, so it is safe to build one per frame.
class NeoStrings {
  const NeoStrings(this.language);

  /// The language these phrases are written in.
  final NeoLanguage language;

  /// Whether Chinese is in use, read by nearly every getter below.
  bool get isZh => language == NeoLanguage.zh;

  /// Picks between the two languages, Chinese first like the rest of this file.
  String _t(String zh, String en) => isZh ? zh : en;

  // ---------------------------------------------------------------------------
  // Words shared by several panels.
  // ---------------------------------------------------------------------------

  String get close => _t('关闭', 'Close');
  String get cancel => _t('取消', 'Cancel');
  String get add => _t('添加', 'Add');
  String get mute => _t('静音', 'Mute');
  String get unmute => _t('取消静音', 'Unmute');

  /// The volume slider's caption while it is silent: a word, not a percentage.
  String get mutedCaption => _t('静音', 'Muted');

  /// A volume level as the panel writes it, or [mutedCaption] when it says
  /// nothing useful about the level.
  String volumeLabel(double level, {bool muted = false}) {
    final percent = (level.clamp(0.0, 1.0) * 100).round();
    if (muted || percent == 0) return mutedCaption;
    return '$percent%';
  }

  /// How this language writes before and after noon.
  ///
  /// Denial's own catalogue has no meridiem strings, so this is the one piece of
  /// wording the plugin supplies itself. Neither of Denial's languages uses the
  /// Latin markers, and no third language is reachable.
  ({String am, String pm}) get meridiem =>
      isZh ? (am: '上午', pm: '下午') : (am: 'AM', pm: 'PM');
  String get remove => _t('移除', 'Remove');
  String get clear => _t('清除', 'Clear');
  String get network => _t('网络', 'Network');
  String get bluetooth => _t('蓝牙', 'Bluetooth');
  String get volume => _t('音量', 'Volume');
  String get battery => _t('电量', 'Battery');
  String get notifications => _t('通知', 'Notifications');
  String get doNotDisturb => _t('免打扰', 'Do not disturb');
  String get appearance => _t('深浅模式', 'Light/dark mode');
  String get switchedOn => _t('已开启', 'On');
  String get switchedOff => _t('已关闭', 'Off');
  String get serviceUnavailable => _t('服务不可用', 'Service unavailable');
  String get notSupportedInSession => _t('当前会话不支持', 'Not supported here');
  String get toggle => _t('切换', 'Toggle');
  String get connect => _t('连接', 'Connect');
  String get connecting => _t('连接中…', 'Connecting…');
  String get scanning => _t('正在扫描…', 'Scanning…');

  // ---------------------------------------------------------------------------
  // Module names and descriptions, looked up by the descriptor's id.
  // ---------------------------------------------------------------------------

  /// The human name of the module [moduleId].
  ///
  /// Falls back to the id itself, so a module added without a translation shows
  /// something recognizable instead of an empty card.
  String moduleLabel(String moduleId) => switch (moduleId) {
    NeoModuleIds.workspaces => _t('工作区胶囊', 'Workspaces'),
    NeoModuleIds.launcher => _t('应用启动器', 'App launcher'),
    NeoModuleIds.tray => _t('系统托盘', 'System tray'),
    NeoModuleIds.notifications => notifications,
    NeoModuleIds.media => _t('媒体播放', 'Media'),
    NeoModuleIds.battery => _t('电池与电源', 'Battery and power'),
    NeoModuleIds.controlCenter => _t('控制中心', 'Control centre'),
    NeoModuleIds.cpu => _t('CPU 负载', 'CPU load'),
    NeoModuleIds.gpu => _t('GPU 负载', 'GPU load'),
    NeoModuleIds.clock => _t('时钟与日期', 'Clock and date'),
    _ => moduleId,
  };

  /// The one-line explanation of the module [moduleId], shown under its name.
  String moduleDescription(String moduleId) => switch (moduleId) {
    NeoModuleIds.workspaces => _t(
      '显示工作区数量、当前工作区与占用状态，点击切换',
      'How many workspaces exist and which are busy; click to switch',
    ),
    NeoModuleIds.launcher => _t(
      '中间的启动器入口，点击打开应用列表与搜索',
      'The centre entry point; opens the app list and search',
    ),
    NeoModuleIds.tray => _t(
      'StatusNotifier 图标，菜单与激活由宿主管理',
      'StatusNotifier icons, with menus and activation owned by the host',
    ),
    NeoModuleIds.notifications => _t(
      '未读徽章与通知历史面板，可逐条忽略或全部清除',
      'Unread badge and history panel; dismiss one item or clear them all',
    ),
    NeoModuleIds.media => _t(
      '当前播放曲目与上一首/播放暂停/下一首按钮',
      'The current track with previous, play/pause and next',
    ),
    NeoModuleIds.battery => _t(
      '电量与充电状态，点击打开电源设置',
      'Charge and charging state; click to open the power settings',
    ),
    NeoModuleIds.controlCenter => _t(
      '音量、亮度、Wi-Fi、蓝牙、深浅模式与开关机的弹出面板',
      'Pop-up panel for volume, brightness, Wi-Fi, Bluetooth, appearance and power',
    ),
    NeoModuleIds.cpu => _t(
      'CPU 使用率折线、百分比与温度',
      'CPU usage sparkline, percentage and temperature',
    ),
    NeoModuleIds.gpu => _t(
      '每块显卡的使用率折线与温度',
      'Usage sparkline and temperature for every GPU',
    ),
    NeoModuleIds.clock => _t(
      '日期加时钟，点击打开日历面板',
      'Date and time; click to open the calendar panel',
    ),
    _ => '',
  };

  /// The name of the bar zone [zone], used by the settings panel and by the drag
  /// preview, so the two can never disagree about what a zone is called.
  String zoneLabel(NeoZone zone) => switch (zone) {
    NeoZone.start => _t('左侧', 'Left'),
    NeoZone.center => _t('中间', 'Centre'),
    NeoZone.end => _t('右侧', 'Right'),
  };

  // ---------------------------------------------------------------------------
  // The settings panel around the modules.
  // ---------------------------------------------------------------------------

  String get settingsTitle => _t('顶栏组件设置', 'Top bar components');
  String get settingsTooltip => _t(
    '打开 Neo Top Bar 的组件开关、分区与排序面板',
    'Open Neo Top Bar\'s component, zone and ordering panel',
  );
  String get appearanceSettingsTitle => _t('顶栏组件', 'Top bar components');

  /// The way from one pill's own settings to the whole board.
  String get allModuleSettings => _t('全部组件设置', 'All component settings');

  /// Shown when a pill's settings card is open and that pill has left the bar.
  String get pillGone =>
      _t('这个组件已经不在栏上了', 'This component is no longer on the bar');

  /// Title of the expandable card for one module instance.
  String moduleSettingsTitle(String label) =>
      _t('「$label」设置', '$label settings');
  String get expandSettings => _t('展开设置', 'Show settings');
  String get collapseSettings => _t('收起设置', 'Hide settings');
  String get removeFromBar => _t('从顶栏移除', 'Remove from the bar');
  String get moduleHasNoSettings =>
      _t('这个组件暂时没有自己的设置。', 'This component has no settings of its own yet.');
  String get zoneEmpty => _t('这一段还没有组件。', 'Nothing in this zone yet.');
  String get addModule => _t('添加组件', 'Add a component');
  String get addModuleHint => _t(
    '「添加组件」可以把任何组件放进这一段，同一个组件想加几个就加几个。',
    '"Add a component" puts any component in this zone — add as many copies as you like.',
  );
  String get densityLabel => _t('间距', 'Spacing');
  String get densityCompact => _t('紧凑', 'Compact');
  String get densityStandard => _t('标准', 'Standard');
  String get densityRelaxed => _t('宽松', 'Relaxed');

  /// The card grip's tooltip.
  String get dragToReorderZone =>
      _t('拖动调整这一区内的顺序', 'Drag to reorder inside this zone');

  /// First half of the board's hint: what dragging a card does.
  String get boardHintReorder =>
      _t('拖动卡片调整同一区内的顺序', 'Drag cards to reorder them inside a zone');

  /// Second half of the board's hint, for the bar the user actually has: the
  /// card list always runs top to bottom, but that maps onto a different bar
  /// direction depending on which edge the bar sits on. The trailing separator
  /// belongs to this fragment so the pieces read as one sentence wherever they
  /// are concatenated.
  String boardHintAxis({required bool barIsVertical}) => barIsVertical
      ? _t('（越靠上，在竖栏上越靠上）；', ' (higher here is higher on the vertical bar); ')
      : _t('（越靠上，在横栏上越靠左）；', ' (higher here is further left on the bar); ');

  /// Third part of the board's hint: where a module's own options live.
  String get boardHintChevron => _t(
    '点卡片里的箭头展开它自己的选项；',
    'use the arrow on a card to open its own options;',
  );

  String loadFailed(Object error) => _t(
    '读取配置失败，正在使用默认值：$error',
    'Could not read the configuration, using defaults: $error',
  );
  String saveFailed(Object error) =>
      _t('保存配置失败：$error', 'Could not save the configuration: $error');

  // ---------------------------------------------------------------------------
  // The image browser the launcher's custom icon uses.
  // ---------------------------------------------------------------------------

  String get browseFiles => _t('浏览文件', 'Browse files');
  String get parentDirectory => _t('上一级', 'Up one level');
  String get chooseImage => _t('选择图片', 'Choose an image');
  String get customImage => _t('自定义图片', 'Custom image');
  String get pickImageHint =>
      _t('点右边的按钮挑一张图片', 'Use the button on the right to pick an image');
  String get noImageSelected => _t('还没有选择图片', 'No image selected yet');
  String get fileMissing => _t('这个文件不在了', 'That file is gone');
  String get directoryEmpty =>
      _t('这个目录里没有子目录或图片。', 'No sub-directories or images in this directory.');
  String get collapse => _t('收起', 'Collapse');
  String openDirectoryFailed(Object error) =>
      _t('打不开这个目录：$error', 'Could not open that directory: $error');

  // ---------------------------------------------------------------------------
  // Media, battery and the clock.
  // ---------------------------------------------------------------------------

  String get previousTrack => _t('上一首', 'Previous track');
  String get nextTrack => _t('下一首', 'Next track');
  String get play => _t('播放', 'Play');
  String get pause => _t('暂停', 'Pause');
  String get openPowerSettings => _t('打开电源设置', 'Open the power settings');

  String get clockTime => _t('时间', 'Time');
  String get clockDate => _t('日期', 'Date');
  String get clockShowDate => _t('显示日期', 'Show the date');
  String get clockShowDateHint =>
      _t('关掉之后胶囊上只剩时间', 'Turn this off and the pill shows only the time');
  String get clockUse24Hour => _t('24 小时制', '24-hour clock');
  String get clockDateFormat => _t('日期格式', 'Date format');
  String get clockOpenCalendar => _t('打开日历', 'Open the calendar');
  String clockTimeExample(String twelve) => _t('例如 $twelve', 'e.g. $twelve');
  String clockTimeExample24(String twentyFour) =>
      _t('例如 $twentyFour', 'e.g. $twentyFour');

  /// The name of date format [format] in the clock's settings.
  String clockDateFormatLabel(NeoClockDateFormat format) => switch (format) {
    NeoClockDateFormat.monthDayWeekday => _t(
      '月日 + 星期',
      'Month, day and weekday',
    ),
    NeoClockDateFormat.monthDay => _t('只要月日', 'Month and day'),
    NeoClockDateFormat.weekday => _t('只要星期', 'Weekday only'),
    NeoClockDateFormat.isoDate => _t('数字日期', 'Numeric date'),
  };

  /// What date format [format] looks like, in the clock's settings.
  String clockDateFormatDescription(NeoClockDateFormat format) =>
      switch (format) {
        NeoClockDateFormat.monthDayWeekday => _t(
          '例如「10月8日 星期四」',
          'e.g. "Thursday 8 October"',
        ),
        NeoClockDateFormat.monthDay => _t(
          '更短，例如「10月8日」',
          'Shorter, e.g. "8 October"',
        ),
        NeoClockDateFormat.weekday => _t(
          '最短，例如「星期四」',
          'Shortest, e.g. "Thursday"',
        ),
        NeoClockDateFormat.isoDate => _t(
          '带年份、任何语言下都不会歧义，例如「2026-10-08」',
          'Includes the year and reads the same in every language, e.g. "2026-10-08"',
        ),
      };

  // ---------------------------------------------------------------------------
  // The launcher's settings.
  // ---------------------------------------------------------------------------

  String get launcherIcon => _t('图标', 'Icon');
  String get launcherIconQuestion => _t('用哪种图标', 'Which icon to draw');
  String get launcherShowWorkspaceWindows =>
      _t('显示当前工作区的应用', 'Show this workspace\'s apps');
  String get launcherShowWorkspaceWindowsHint => _t(
    '在图标右边列出本工作区每个窗口的图标，点一下聚焦',
    'Lists an icon per window on this workspace next to the mark; click one to focus it',
  );
  String get launcherOpen => _t('打开应用启动器', 'Open the app launcher');
  String launcherOpenWithCount(int count) => isZh
      ? '打开应用启动器 · 当前工作区 $count 个窗口'
      : count == 1
      ? 'Open the app launcher · 1 window on this workspace'
      : 'Open the app launcher · $count windows on this workspace';
  String launcherUsingPath(String path) => _t('用的是 $path', 'Using $path');
  // The launcher pill's right-click menu. "Close window" is the shell's close
  // *request* — the application still gets to ask about unsaved work, exactly
  // like Windows' own taskbar entry — so it is not called a force-quit.
  String get launcherMenuOpenLauncher => _t('打开应用启动器', 'Open the app launcher');
  String get launcherMenuOpenTerminal => _t('打开终端', 'Open a terminal');
  String get launcherMenuNewWindow => _t('新窗口', 'New window');
  String get launcherMenuCloseWindow => _t('关闭窗口', 'Close window');
  String get launcherDenialUnavailable => _t(
    'Denial 官方图标还没有发布，所以这一项暂时不能选。',
    'Denial has not published its own mark yet, so this cannot be picked.',
  );
  String get launcherFallbackActive => _t(
    '当前这个选择还用不了，栏上显示的是默认图标。',
    'That choice cannot be used right now, so the bar falls back to the default mark.',
  );
  String get launcherNoDistroLogo => _t(
    '这台机器上没有发行版的图标文件，栏上会用插件自带的那张。',
    'This machine has no distribution mark installed, so the one bundled with the plugin is used.',
  );

  /// The name of icon source [icon] in the launcher's settings.
  String launcherIconLabel(NeoLauncherIcon icon) => switch (icon) {
    NeoLauncherIcon.grid => _t('默认', 'Default'),
    NeoLauncherIcon.system => _t('系统', 'System'),
    NeoLauncherIcon.custom => _t('自定义', 'Custom'),
    NeoLauncherIcon.denial => 'Denial',
  };

  /// What icon source [icon] means, in the launcher's settings.
  String launcherIconDescription(NeoLauncherIcon icon) => switch (icon) {
    NeoLauncherIcon.grid => _t(
      '九宫格图标，任何机器上都能用',
      'A plain app-grid mark, available on every machine',
    ),
    NeoLauncherIcon.system => _t(
      '按发行版选图标，找不到就用默认',
      'The distribution\'s own mark, falling back to the default',
    ),
    NeoLauncherIcon.custom => _t(
      '自己选一张图片（SVG / PNG / JPEG / WebP / GIF）',
      'Pick your own image (SVG / PNG / JPEG / WebP / GIF)',
    ),
    NeoLauncherIcon.denial => _t(
      '等 Denial 官方图标，暂时不能用',
      'Waits for Denial\'s own mark; not usable yet',
    ),
  };

  // ---------------------------------------------------------------------------
  // The calendar panel.
  // ---------------------------------------------------------------------------

  String get previousMonth => _t('上个月', 'Previous month');
  String get nextMonth => _t('下个月', 'Next month');
  String get backToToday => _t('回到今天', 'Today');

  /// Monday-first weekday initials for the calendar's header row.
  List<String> get calendarWeekdays => isZh
      ? const <String>['一', '二', '三', '四', '五', '六', '日']
      : const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String calendarMonthTitle(int year, int month) =>
      isZh ? '$year 年 $month 月' : '${_englishMonths[month - 1]} $year';

  // ---------------------------------------------------------------------------
  // Notifications.
  // ---------------------------------------------------------------------------

  String get notificationsPanelTitle => notifications;
  String get notificationsEmpty => _t('没有通知', 'No notifications');
  String get notificationsClearAll => _t('全部清除', 'Clear all');
  String get notificationsDismiss => _t('忽略', 'Dismiss');
  String get notificationsEnableDnd => _t('开启免打扰', 'Turn on do not disturb');
  String get notificationsDisableDnd => _t('关闭免打扰', 'Turn off do not disturb');
  String unreadNotifications(int count) => isZh
      ? '$count 条未读通知'
      : count == 1
      ? '1 unread notification'
      : '$count unread notifications';

  // ---------------------------------------------------------------------------
  // The workspace pill.
  // ---------------------------------------------------------------------------

  String get workspaceShowWindows => _t('胶囊里显示窗口图标', 'Show window icons');
  String get workspaceShowWindowsHint => _t(
    '每个工作区最多 3 个，放不下的记成 +N',
    'Up to three per workspace; the rest are counted as +N',
  );

  String trayMoreIcons(int count) => isZh
      ? '还有 $count 个图标'
      : count == 1
      ? '1 more icon'
      : '$count more icons';

  /// Said under the clock's date setting, because the bar can overrule it.
  String get clockCompactNote => _t(
    '空间不够时会自动只显示时间',
    'When the bar runs out of room, only the time is shown',
  );

  // ---------------------------------------------------------------------------
  // The control centre pill.
  // ---------------------------------------------------------------------------

  String get pillGlyphs => _t('胶囊上显示', 'Shown on the pill');
  String get pillGlyphsAtLeastOne =>
      _t('至少留一个，否则胶囊会是空白', 'Keep at least one, or the pill is blank');
  String get batteryGlyphIcon => _t('用图标代替百分比', 'Icon instead of a percentage');
  String get batteryGlyphIconHint => _t(
    '关掉就还是现在这样：胶囊上直接写 85%',
    'Off keeps what the pill does now: it writes 85%',
  );
  String get powerButtons => _t('电源按钮', 'Power buttons');
  String get powerHibernateHint =>
      _t('休眠，默认不在这一行里', 'Hibernate; off this row by default');
  String get powerSuspendHint =>
      _t('睡眠，默认不在这一行里', 'Suspend; off this row by default');
  String get powerLockHint =>
      _t('立即锁屏，不需要确认', 'Locks immediately, with no confirmation');
  String get powerLogoutHint =>
      _t('注销当前会话，会先问一次', 'Logs out, asking once first');
  String get powerRebootHint => _t('重启，会先问一次', 'Reboots, asking once first');
  String get powerShutdownHint =>
      _t('关机，会先问一次', 'Powers off, asking once first');
  String batteryTooltip(int capacity) =>
      _t('电量 $capacity%', 'Battery $capacity%');

  String get glyphVolumeTooltip =>
      _t('音量 · 右键静音', 'Volume · right-click to mute');
  String get glyphVolumeMutedTooltip =>
      _t('音量（静音）· 右键取消静音', 'Volume (muted) · right-click to unmute');
  String get glyphWifiTooltip =>
      _t('Wi-Fi · 右键关闭无线', 'Wi-Fi · right-click to turn wireless off');
  String get glyphWifiOffTooltip =>
      _t('无线已关闭 · 右键开启无线', 'Wireless is off · right-click to turn it on');
  String get glyphWifiDisconnectedTooltip => _t(
    '无线未连接 · 右键关闭无线',
    'Wireless is not connected · right-click to turn it off',
  );
  String get glyphWiredTooltip =>
      _t('有线网络 · 右键开关无线', 'Wired network · right-click to toggle wireless');
  String get glyphBluetoothTooltip =>
      _t('蓝牙 · 右键关闭', 'Bluetooth · right-click to turn off');

  /// The name of the pill glyph [glyph] in the control centre's settings.
  String pillGlyphLabel(NeoPillGlyph glyph) => switch (glyph) {
    NeoPillGlyph.volume => volume,
    NeoPillGlyph.network => network,
    NeoPillGlyph.bluetooth => bluetooth,
    NeoPillGlyph.battery => battery,
  };

  /// What the pill glyph [glyph] does, in the control centre's settings.
  String pillGlyphDescription(NeoPillGlyph glyph) => switch (glyph) {
    NeoPillGlyph.volume => _t(
      '扬声器图标，点开面板，右键静音',
      'A speaker mark; opens the panel, right-click mutes',
    ),
    NeoPillGlyph.network => _t(
      'Wi-Fi 或有线图标，右键开关无线',
      'The Wi-Fi or wired mark; right-click toggles wireless',
    ),
    NeoPillGlyph.bluetooth => _t(
      '适配器开启时才出现，右键开关蓝牙',
      'Appears once the adapter is on; right-click toggles Bluetooth',
    ),
    NeoPillGlyph.battery => _t(
      '电量百分比，没有电池的机器不显示',
      'A charge percentage, hidden on machines without a battery',
    ),
  };

  // ---------------------------------------------------------------------------
  // The power row and its confirmations.
  // ---------------------------------------------------------------------------

  /// The name of power action [action].
  String powerActionLabel(NeoPowerAction action) => switch (action) {
    NeoPowerAction.lock => _t('锁屏', 'Lock'),
    NeoPowerAction.logout => _t('注销', 'Log out'),
    NeoPowerAction.suspend => _t('睡眠', 'Suspend'),
    NeoPowerAction.hibernate => _t('休眠', 'Hibernate'),
    NeoPowerAction.reboot => _t('重启', 'Restart'),
    NeoPowerAction.powerOff => _t('关机', 'Power off'),
  };

  /// The question shown before [action] runs; empty when it needs no confirmation.
  String powerConfirmationQuestion(NeoPowerAction action) => switch (action) {
    NeoPowerAction.logout => _t(
      '注销当前会话？未保存的工作会丢失。',
      'Log out of this session? Unsaved work will be lost.',
    ),
    NeoPowerAction.reboot => _t('重启这台电脑？', 'Restart this computer?'),
    NeoPowerAction.powerOff => _t('关机？', 'Power off?'),
    NeoPowerAction.lock ||
    NeoPowerAction.suspend ||
    NeoPowerAction.hibernate => '',
  };

  /// The name of theme mode [mode].
  String themeModeLabel(NeoThemeMode mode) => switch (mode) {
    NeoThemeMode.light => _t('浅色', 'Light'),
    NeoThemeMode.dark => _t('深色', 'Dark'),
  };

  // ---------------------------------------------------------------------------
  // The control centre panel.
  // ---------------------------------------------------------------------------

  String pairRequest(String name) => _t('「$name」请求配对', '"$name" wants to pair');
  String pairCode(String name, String code) =>
      _t('「$name」配对码 $code', 'Pairing code for "$name": $code');
  String enterPassword(String ssid) =>
      _t('输入「$ssid」的密码', 'Password for "$ssid"');
  String get bluetoothDevices => _t('蓝牙设备', 'Bluetooth devices');
  String get noPairedDevices => _t('没有已配对的设备', 'No paired devices');
  String get scanDevices => _t('扫描设备', 'Scan for devices');
  String get stopScanning => _t('停止扫描', 'Stop scanning');
  String get rescan => _t('重新扫描', 'Scan again');
  String get reload => _t('重新读取', 'Reload');
  String get accept => _t('接受', 'Accept');
  String get reject => _t('拒绝', 'Reject');
  String get connected => _t('已连接', 'Connected');
  String get disconnected => _t('未连接', 'Not connected');
  String get paired => _t('已配对', 'Paired');
  String get notPaired => _t('未配对', 'Not paired');
  String get inUse => _t('正在使用', 'In use');
  String get openNetwork => _t('开放网络', 'Open network');
  String get passwordRequired => _t('需要密码', 'Password required');
  String get noNetworksFound => _t('没有找到网络', 'No networks found');
  String get noWifiAdapter => _t('没有无线网卡', 'No wireless adapter');
  String get wirelessOff => _t('无线已关闭', 'Wireless is off');
  String get bluetoothOff => _t('蓝牙已关闭', 'Bluetooth is off');
  String get noAdapter => _t('没有适配器', 'No adapter');
  String get expandDetails => _t('展开详细设置', 'Show more');
  String get collapseDetails => _t('收起详细设置', 'Show less');
  String get outputsAndApps => _t('输出与应用程序', 'Outputs and applications');
  String get displayBrightness => _t('显示器亮度', 'Display brightness');
  String get loadingOutputs => _t('正在读取输出设备…', 'Reading output devices…');
  String get noOutputDevices => _t('没有可用的输出设备', 'No output devices available');
  String get noDisplays => _t('没有检测到显示器', 'No displays detected');
  String get noAppPlaying => _t('当前没有应用程序在播放', 'No application is playing');
  String get devicesSection => _t('设备', 'Devices');
  String get customOpenModuleSettings =>
      _t('自定义 · 打开组件设置', 'Customize · open the component settings');

  /// The one English month list. Denial localizes month names, but only the host
  /// can reach them; this is the plugin's own table for the calendar's title,
  /// which has to be readable even where no month names were supplied.
  static const List<String> _englishMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // --- added while sweeping the modules ---

  /// The title of the launcher settings group that holds the window options.
  String get launcherWindowsSection => _t('窗口', 'Windows');
}
