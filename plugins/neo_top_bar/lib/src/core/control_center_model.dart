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

/// The two states the theme tile switches between.
///
/// Two, not three, and derived from what is actually on screen. Denial's third
/// setting — "follow the system" — resolves to a fixed brightness in this SDK
/// version (`noPreference.effectiveBrightness` is `denialDefaultBrightness`,
/// which is dark), so cycling through it made a tap that changed nothing. A
/// control whose only feedback is invisible is worse than one that cannot
/// express a state the platform does not implement; if that default ever starts
/// following the portal preference, a third state becomes worth adding back.
enum NeoThemeMode { light, dark }

/// The mode currently in effect.
NeoThemeMode neoThemeMode({required bool isDark}) =>
    isDark ? NeoThemeMode.dark : NeoThemeMode.light;

/// The mode the tile shows after tapping [current]. Always a visible change.
NeoThemeMode neoNextThemeMode(NeoThemeMode current) =>
    current == NeoThemeMode.dark ? NeoThemeMode.light : NeoThemeMode.dark;

String neoThemeModeLabel(NeoThemeMode mode) => switch (mode) {
  NeoThemeMode.light => '浅色',
  NeoThemeMode.dark => '深色',
};

/// The writes a theme tap has to make, given what is on screen.
///
/// Two settings can drive the shell's colours, and which one wins depends on the
/// transparency mode: while it is `glass`, `denial_shell.dart` derives the shell
/// colour scheme from `glass.appearance` and ignores `colorSchemePreference`
/// entirely. A tile that writes only the colour scheme therefore changes a
/// setting nothing on screen reads — which is exactly the bug this type exists
/// to prevent, twice over. Applications still follow the colour scheme, so both
/// are written on every tap.
class NeoThemeToggle {
  const NeoThemeToggle({
    required this.mode,
    required this.writeGlass,
    required this.writeColorScheme,
  });

  /// The appearance to switch to.
  final NeoThemeMode mode;

  /// Whether `glass.appearance` must be written for the shell to change.
  final bool writeGlass;

  /// Whether `colorSchemePreference` must be written so applications follow.
  final bool writeColorScheme;

  @override
  String toString() =>
      'NeoThemeToggle($mode, glass: $writeGlass, '
      'colorScheme: $writeColorScheme)';
}

NeoThemeToggle neoThemeToggle({
  required NeoThemeMode current,
  required bool glassTransparency,
}) => NeoThemeToggle(
  mode: neoNextThemeMode(current),
  writeGlass: glassTransparency,
  writeColorScheme: true,
);

/// One network interface as the wired-link rule needs it.
///
/// Read from sysfs plus a routable-address check, because Denial's network
/// snapshot only describes the **Wi-Fi** device: its backend filters
/// NetworkManager devices to `DeviceType == 2` and derives the connectivity
/// status from that device's state, so a machine on Ethernet with the radio off
/// reports `disconnected` even though it is online.
class NeoLinkFacts {
  const NeoLinkFacts({
    required this.name,
    required this.operState,
    required this.wireless,
    required this.physical,
    required this.routable,
  });

  final String name;

  /// Contents of `/sys/class/net/<name>/operstate`.
  final String operState;

  /// A `wireless` directory exists, i.e. the kernel says this is Wi-Fi.
  final bool wireless;

  /// A `device` symlink exists, which rules out bridges, veth pairs, bonds,
  /// tunnels and other software interfaces that are not a cable.
  final bool physical;

  /// The interface currently holds a routable (non-link-local) address.
  final bool routable;

  @override
  String toString() =>
      'NeoLinkFacts($name, $operState, wireless: $wireless, '
      'physical: $physical, routable: $routable)';
}

/// Whether any interface looks like an Ethernet link that is actually up.
///
/// Deliberately conservative: a link with no address is not "connected" to a
/// user, and a wireless or virtual interface is never reported as wired.
bool neoWiredLinkUp(List<NeoLinkFacts> links) {
  for (final link in links) {
    if (link.wireless || !link.physical || !link.routable) continue;
    if (link.operState == 'up' || link.operState == 'unknown') return true;
  }
  return false;
}

/// What the pill's network slot shows.
enum NeoNetworkGlyph {
  /// A cable is up: shown even when Wi-Fi is also connected, because a wired
  /// link is the state a user wants to notice.
  ethernet,

  /// Connected over Wi-Fi.
  wifi,

  /// Radio on, nothing joined.
  offline,

  /// Radio off.
  wifiOff,
}

NeoNetworkGlyph neoNetworkGlyph({
  required bool wiredUp,
  required bool wifiConnected,
  required bool wirelessEnabled,
}) {
  if (wiredUp) return NeoNetworkGlyph.ethernet;
  if (wifiConnected) return NeoNetworkGlyph.wifi;
  return wirelessEnabled ? NeoNetworkGlyph.offline : NeoNetworkGlyph.wifiOff;
}

/// One audio output the panel can switch to.
class NeoAudioDevice {
  const NeoAudioDevice({
    required this.name,
    required this.description,
    required this.active,
    required this.available,
  });

  final String name;
  final String description;
  final bool active;
  final bool available;

  @override
  String toString() => 'NeoAudioDevice($description, active: $active)';
}

/// Outputs worth offering: the available ones, active first, then by name.
///
/// Unavailable outputs are dropped rather than greyed out: a sink that is not
/// present cannot be selected, and a list of ports that are not plugged in
/// pushes the one you want off the panel.
List<NeoAudioDevice> neoAudioDeviceEntries(
  List<NeoAudioDevice> devices, {
  int limit = 6,
}) {
  final entries =
      <NeoAudioDevice>[
        for (final device in devices)
          if (device.available) device,
      ]..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        final left = a.description.isEmpty ? a.name : a.description;
        final right = b.description.isEmpty ? b.name : b.description;
        final byName = left.toLowerCase().compareTo(right.toLowerCase());
        return byName != 0 ? byName : a.name.compareTo(b.name);
      });
  return List<NeoAudioDevice>.unmodifiable(entries.take(limit < 0 ? 0 : limit));
}

/// One application's audio stream.
class NeoAppStream {
  const NeoAppStream({
    required this.id,
    required this.name,
    required this.level,
    required this.muted,
  });

  final int id;
  final String name;
  final double level;
  final bool muted;

  @override
  String toString() => 'NeoAppStream($name, level: $level)';
}

/// Streams to show, one per id, ordered by name.
///
/// Ordered rather than taken as they arrive for the same reason the launcher's
/// window icons are: the host rebuilds this list on every audio change, and a
/// row that moves while it is being dragged is unusable.
List<NeoAppStream> neoAppStreamEntries(
  List<NeoAppStream> streams, {
  int limit = 8,
}) {
  final unique = <int, NeoAppStream>{};
  for (final stream in streams) {
    unique.putIfAbsent(stream.id, () => stream);
  }
  final entries = unique.values.toList()
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  return List<NeoAppStream>.unmodifiable(entries.take(limit < 0 ? 0 : limit));
}

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
