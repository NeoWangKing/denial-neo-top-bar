/// Pure logic behind the control centre.
///
/// The panel is mostly a thin shell over Denial's own providers, but three
/// things are worth deciding away from the widget tree, because they are rules
/// rather than rendering: which rows the Wi-Fi and Bluetooth lists show and in
/// what order, what the theme tile does next, and which power actions have to be
/// confirmed.
///
/// Kept free of Flutter and of the SDK so it is unit-testable on plain Dart —
/// see `neo_top_bar_logic.dart`.
library;

/// One Wi-Fi row, as the panel needs it.
///
/// The host exposes networks per BSSID, so one access point with 2.4 GHz and
/// 5 GHz radios arrives as two entries with the same SSID. The panel wants one
/// row per network the user recognises, which is why this carries the pieces the
/// collapse and the ordering need rather than the SDK type itself.
class NeoWifiEntry {
  const NeoWifiEntry({
    required this.id,
    required this.ssid,
    required this.strength,
    required this.connected,
    required this.secured,
  });

  /// Host identity of this BSSID, used to connect to the row the user picked.
  final String id;

  final String ssid;

  /// Signal strength, higher is better.
  final int strength;

  final bool connected;
  final bool secured;

  @override
  String toString() =>
      'NeoWifiEntry($ssid, strength: $strength, '
      'connected: $connected, secured: $secured)';
}

/// Collapses [networks] to one row per SSID, strongest first, connected on top.
///
/// Names that are empty are dropped: the host reports hidden or not-yet-resolved
/// networks that way, and a nameless row cannot be identified well enough to
/// connect to on purpose.
List<NeoWifiEntry> neoWifiPanelEntries(
  List<NeoWifiEntry> networks, {
  int limit = 8,
}) {
  final best = <String, NeoWifiEntry>{};
  for (final entry in networks) {
    if (entry.ssid.isEmpty) continue;
    final current = best[entry.ssid];
    if (current == null || _wifiWins(entry, current)) {
      best[entry.ssid] = entry;
    }
  }
  final entries = best.values.toList()
    ..sort((a, b) {
      // The network you are on is the one you look for first.
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      if (a.strength != b.strength) return b.strength.compareTo(a.strength);
      // Ties broken by name so the list does not reshuffle between scans, which
      // report equal strengths for equal radios in whatever order they arrive.
      return a.ssid.compareTo(b.ssid);
    });
  return List<NeoWifiEntry>.unmodifiable(entries.take(limit < 0 ? 0 : limit));
}

/// Whether [candidate] should represent its SSID instead of [current].
bool _wifiWins(NeoWifiEntry candidate, NeoWifiEntry current) {
  if (candidate.connected != current.connected) return candidate.connected;
  return candidate.strength > current.strength;
}

/// One Bluetooth device row.
class NeoBluetoothEntry {
  const NeoBluetoothEntry({
    required this.id,
    required this.name,
    required this.connected,
    required this.paired,
    this.signal,
  });

  /// Host identity of the device, used for connect/disconnect.
  final String id;

  final String name;
  final bool connected;
  final bool paired;

  /// Signal strength when the host reports one; null otherwise.
  final int? signal;

  @override
  String toString() =>
      'NeoBluetoothEntry($name, connected: $connected, paired: $paired)';
}

/// Orders [devices] for the panel: connected first, then paired, then by name.
///
/// A device the host has never paired and is not connected to is a scan result;
/// the caller decides whether to show those, so they are ordered here rather
/// than filtered out.
List<NeoBluetoothEntry> neoBluetoothPanelEntries(
  List<NeoBluetoothEntry> devices, {
  int limit = 6,
}) {
  final unique = <String, NeoBluetoothEntry>{};
  for (final device in devices) {
    final current = unique[device.id];
    if (current == null || _bluetoothWins(device, current)) {
      unique[device.id] = device;
    }
  }
  final entries = unique.values.toList()
    ..sort((a, b) {
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      if (a.paired != b.paired) return a.paired ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return List<NeoBluetoothEntry>.unmodifiable(
    entries.take(limit < 0 ? 0 : limit),
  );
}

bool _bluetoothWins(NeoBluetoothEntry candidate, NeoBluetoothEntry current) {
  if (candidate.connected != current.connected) return candidate.connected;
  if (candidate.paired != current.paired) return candidate.paired;
  return (candidate.signal ?? -1) > (current.signal ?? -1);
}

/// The three states the theme tile cycles through.
///
/// Three rather than two on purpose: a plain dark/light switch cannot express
/// "follow the system", which is what Denial stores by default, and forcing a
/// preference the user never asked for is worse than one extra tap.
enum NeoThemeMode { system, light, dark }

/// The mode the tile shows after tapping [current].
NeoThemeMode neoNextThemeMode(NeoThemeMode current) => switch (current) {
  NeoThemeMode.system => NeoThemeMode.light,
  NeoThemeMode.light => NeoThemeMode.dark,
  NeoThemeMode.dark => NeoThemeMode.system,
};

String neoThemeModeLabel(NeoThemeMode mode) => switch (mode) {
  NeoThemeMode.system => '跟随系统',
  NeoThemeMode.light => '浅色',
  NeoThemeMode.dark => '深色',
};

/// A session action the control centre can request.
///
/// Mirrors Denial's own `SessionPowerAction`, minus the widget layer's
/// permission handling: the panel reads availability from the provider and only
/// uses this enum to decide what a tap means.
enum NeoPowerAction { lock, logout, suspend, hibernate, reboot, powerOff }

/// The order the power row shows its buttons in, least destructive first.
const List<NeoPowerAction> neoPowerActionOrder = <NeoPowerAction>[
  NeoPowerAction.lock,
  NeoPowerAction.suspend,
  NeoPowerAction.hibernate,
  NeoPowerAction.logout,
  NeoPowerAction.reboot,
  NeoPowerAction.powerOff,
];

/// Whether [action] ends or interrupts the session and therefore asks first.
///
/// Locking and sleeping are instantly reversible, so a confirmation would only
/// be an obstacle. Every action that can lose work asks.
bool neoPowerActionNeedsConfirmation(NeoPowerAction action) => switch (action) {
  NeoPowerAction.lock ||
  NeoPowerAction.suspend ||
  NeoPowerAction.hibernate => false,
  NeoPowerAction.logout ||
  NeoPowerAction.reboot ||
  NeoPowerAction.powerOff => true,
};

String neoPowerActionLabel(NeoPowerAction action) => switch (action) {
  NeoPowerAction.lock => '锁屏',
  NeoPowerAction.logout => '注销',
  NeoPowerAction.suspend => '睡眠',
  NeoPowerAction.hibernate => '休眠',
  NeoPowerAction.reboot => '重启',
  NeoPowerAction.powerOff => '关机',
};

/// Text of the confirmation strip shown for [action].
String neoPowerConfirmationQuestion(NeoPowerAction action) => switch (action) {
  NeoPowerAction.logout => '注销当前会话？未保存的工作会丢失。',
  NeoPowerAction.reboot => '重启这台电脑？',
  NeoPowerAction.powerOff => '关机？',
  NeoPowerAction.lock ||
  NeoPowerAction.suspend ||
  NeoPowerAction.hibernate => '',
};

/// The slider caption: a percentage, or the muted state the slider cannot show.
String neoVolumeLabel(double level, {bool muted = false}) {
  final percent = (level.clamp(0.0, 1.0) * 100).round();
  if (muted || percent == 0) return '静音';
  return '$percent%';
}

String neoBrightnessLabel(double level) =>
    '${(level.clamp(0.0, 1.0) * 100).round()}%';

/// The level a speaker-button tap should restore when unmuting, and 0 when
/// muting.
///
/// There is no mute call in the audio bridge — only a level — so muting *is*
/// setting zero, and unmuting has to put something back. [remembered] is the
/// level the panel last saw while audible; 0.5 is a deliberately unremarkable
/// fallback for a session that starts muted.
double neoVolumeAfterMuteToggle({
  required double level,
  required bool muted,
  required double remembered,
}) {
  final silent = muted || level <= 0.0;
  if (!silent) return 0.0;
  final restore = remembered.clamp(0.05, 1.0);
  return restore;
}

/// Volume glyph steps, so the pill does not need a bool ladder in the widget.
int neoVolumeGlyphStep(double level, {bool muted = false}) {
  if (muted || level <= 0.0) return 0;
  if (level < 0.34) return 1;
  if (level < 0.67) return 2;
  return 3;
}
