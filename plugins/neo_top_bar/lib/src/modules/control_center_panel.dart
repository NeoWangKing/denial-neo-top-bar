/// The control centre panel: everything the pill opens into.
///
/// Deliberately a *panel* rather than a second settings surface. Denial already
/// ships the full settings apps; what a bar needs is the handful of controls
/// people reach for mid-task — output volume, screen brightness, the two radios,
/// the theme, and the session actions — plus enough state on each row that it
/// can be read at a glance without opening anything.
///
/// Every control is backed by Denial's own provider for that subsystem, so the
/// panel and the rest of the shell never disagree:
///
/// | row | provider |
/// |---|---|
/// | volume, mute | `neoVolumeProvider` over `AudioService` |
/// | brightness | `displayBrightnessProvider` |
/// | Wi-Fi | `networkConnectivityProvider` |
/// | Bluetooth | `bluetoothProvider` |
/// | do not disturb | `desktopNotificationsProvider` |
/// | theme | `shellSettingsProvider` |
/// | lock / logout / sleep / reboot / power off | `sessionPowerProvider` |
///
/// Nothing here shells out, reads a config file, or talks to D-Bus directly.
library;

import 'dart:async';

import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/settings.dart';
import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/system_services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/control_center_model.dart';
import '../core/module.dart';
import '../widgets/neo_popup_surface.dart';
import 'control_center_volume.dart';

/// Opens the panel below the pill that owns [anchor].
void openControlCenterPanel({
  required BuildContext context,
  required WidgetRef ref,
  required NeoModuleContext module,
  required Rect? anchor,
}) {
  ref
      .read(shellPopupControllerProvider.notifier)
      .show(
        keyName: 'neo_top_bar.control_center',
        debugLabel: 'NeoTopBar control centre',
        dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
        // Same reasoning as the notification panel: a card attached to a bar
        // icon is a context menu, and dimming the whole desktop for it is far
        // too heavy. Outside-tap and Escape still dismiss it.
        barrierColor: Colors.transparent,
        builder: (_, handle) => NeoControlCenterPanel(
          services: module.services,
          monitorId: module.monitorId,
          anchor: anchor,
          onClose: handle.close,
        ),
      );
}

/// Rows that can expand a detail list underneath themselves.
enum _Detail { none, wifi, bluetooth }

class NeoControlCenterPanel extends ConsumerStatefulWidget {
  const NeoControlCenterPanel({
    required this.services,
    required this.monitorId,
    required this.anchor,
    required this.onClose,
    super.key,
  });

  final ShellServices services;
  final int monitorId;

  /// Scene-space rectangle of the pill that opened this panel.
  final Rect? anchor;

  final VoidCallback onClose;

  @override
  ConsumerState<NeoControlCenterPanel> createState() =>
      _NeoControlCenterPanelState();
}

class _NeoControlCenterPanelState extends ConsumerState<NeoControlCenterPanel> {
  _Detail _detail = _Detail.none;

  /// The network whose password field is open, and that field's text.
  String? _passwordSsid;
  final TextEditingController _password = TextEditingController();

  /// Local brightness while the slider is under the pointer.
  ///
  /// The provider commits on a timer, so reading it back mid-drag would fight
  /// the knob the same way the echoed volume does.
  double? _brightnessDrag;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkConnectivityProvider);
    final bluetooth = ref.watch(bluetoothProvider);
    final notifications = ref.watch(desktopNotificationsProvider);
    final settings = ref.watch(shellSettingsProvider);
    final power = ref.watch(sessionPowerProvider);
    final colorScheme = settings.appearance.colorSchemePreference;
    final dark = colorScheme.effectiveBrightness == Brightness.dark;
    final themeMode = switch (colorScheme) {
      DesktopColorSchemePreference.preferDark => NeoThemeMode.dark,
      DesktopColorSchemePreference.preferLight => NeoThemeMode.light,
      DesktopColorSchemePreference.noPreference => NeoThemeMode.system,
    };

    return NeoPopupSurface(
      services: widget.services,
      monitorId: widget.monitorId,
      anchor: widget.anchor,
      maxWidth: 380,
      maxHeight: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VolumeRow(),
            const SizedBox(height: 10),
            _BrightnessRow(
              monitorId: widget.monitorId,
              dragValue: _brightnessDrag,
              onDragStart: (value) => setState(() => _brightnessDrag = value),
              onDrag: (value) => setState(() => _brightnessDrag = value),
              onDragEnd: (value) {
                setState(() => _brightnessDrag = null);
              },
            ),
            const SizedBox(height: 14),
            _TileGrid(
              tiles: <Widget>[
                _ControlTile(
                  icon: network.snapshot.wirelessEnabled
                      ? Icons.wifi
                      : Icons.wifi_off,
                  title: 'Wi-Fi',
                  subtitle: _networkSubtitle(network),
                  active: network.snapshot.wirelessEnabled,
                  busy: network.radioChanging || network.initializing,
                  enabled:
                      network.snapshot.serviceAvailable &&
                      network.snapshot.wifiDeviceAvailable,
                  expanded: _detail == _Detail.wifi,
                  onTap: ref
                      .read(networkConnectivityProvider.notifier)
                      .toggleWireless,
                  onExpand: () {
                    if (_detail == _Detail.wifi) {
                      setState(() => _detail = _Detail.none);
                      return;
                    }
                    setState(() => _detail = _Detail.wifi);
                    // Opening the list also refreshes it: a scan is an explicit
                    // radio action, and this panel is the only place that asks.
                    unawaited(
                      ref.read(networkConnectivityProvider.notifier).scan(),
                    );
                  },
                ),
                _ControlTile(
                  icon: bluetooth.powered
                      ? Icons.bluetooth
                      : Icons.bluetooth_disabled,
                  title: '蓝牙',
                  subtitle: _bluetoothSubtitle(bluetooth),
                  active: bluetooth.powered,
                  busy: bluetooth.powerChanging || bluetooth.initializing,
                  enabled: bluetooth.serviceAvailable && bluetooth.available,
                  expanded: _detail == _Detail.bluetooth,
                  onTap: ref.read(bluetoothProvider.notifier).togglePower,
                  onExpand: () {
                    if (_detail == _Detail.bluetooth) {
                      setState(() => _detail = _Detail.none);
                      return;
                    }
                    setState(() => _detail = _Detail.bluetooth);
                    if (bluetooth.powered) {
                      unawaited(ref.read(bluetoothProvider.notifier).scan());
                    }
                  },
                ),
                _ControlTile(
                  icon: notifications.doNotDisturb
                      ? Icons.do_not_disturb_on
                      : Icons.do_not_disturb_off_outlined,
                  title: '免打扰',
                  subtitle: notifications.doNotDisturb ? '已开启' : '已关闭',
                  active: notifications.doNotDisturb,
                  onTap: ref
                      .read(desktopNotificationsProvider.notifier)
                      .toggleDoNotDisturb,
                ),
                _ControlTile(
                  icon: dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  title: '深浅模式',
                  subtitle: neoThemeModeLabel(themeMode),
                  active: dark,
                  onTap: () {
                    final next = neoNextThemeMode(themeMode);
                    ref
                        .read(shellSettingsProvider.notifier)
                        .setColorSchemePreference(switch (next) {
                          NeoThemeMode.system =>
                            DesktopColorSchemePreference.noPreference,
                          NeoThemeMode.light =>
                            DesktopColorSchemePreference.preferLight,
                          NeoThemeMode.dark =>
                            DesktopColorSchemePreference.preferDark,
                        });
                  },
                ),
              ],
            ),
            if (_detail == _Detail.wifi) ...[
              const SizedBox(height: 12),
              _WifiDetail(
                state: network,
                passwordSsid: _passwordSsid,
                password: _password,
                onRequestPassword: (ssid) => setState(() {
                  _passwordSsid = ssid;
                  _password.clear();
                }),
                onCancelPassword: () => setState(() => _passwordSsid = null),
              ),
            ],
            if (_detail == _Detail.bluetooth) ...[
              const SizedBox(height: 12),
              _BluetoothDetail(state: bluetooth),
            ],
            if (network.error case final error?) ...[
              const SizedBox(height: 10),
              _ErrorLine(message: error),
            ],
            if (bluetooth.error case final error?) ...[
              const SizedBox(height: 10),
              _ErrorLine(message: error),
            ],
            if (power.error case final error?) ...[
              const SizedBox(height: 10),
              _ErrorLine(message: error),
            ],
            const SizedBox(height: 16),
            // The provider owns the pending confirmation, so the strip is
            // driven by its state rather than by a second copy here: a power
            // action started from somewhere else still shows up.
            if (power.confirmationAction case final pending?) ...[
              _PowerConfirmation(
                action: _powerAction(pending),
                onCancel: ref
                    .read(sessionPowerProvider.notifier)
                    .cancelConfirmation,
                onConfirm: ref.read(sessionPowerProvider.notifier).confirm,
              ),
              const SizedBox(height: 10),
            ],
            _PowerRow(
              busy: power.busy,
              available: (action) =>
                  power.availabilityFor(_sessionAction(action)).enabled,
              blockedReason: (action) {
                final availability = power.availabilityFor(
                  _sessionAction(action),
                );
                if (availability.enabled) return null;
                final reason = availability.unavailableReason;
                if (reason != null && reason.isNotEmpty) return reason;
                if (availability.blockers.isEmpty) return '当前会话不支持';
                return availability.blockers.join('、');
              },
              // `request` is what decides whether an action runs now or asks
              // first, so the panel does not repeat that rule.
              onTap: (action) => unawaited(
                ref
                    .read(sessionPowerProvider.notifier)
                    .request(_sessionAction(action)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _networkSubtitle(NetworkConnectivityState state) {
    final snapshot = state.snapshot;
    if (!snapshot.serviceAvailable) return '服务不可用';
    if (!snapshot.wifiDeviceAvailable) return '没有无线网卡';
    if (!snapshot.wirelessEnabled) return '已关闭';
    final connected = snapshot.networks.where((entry) => entry.connected);
    if (connected.isNotEmpty) return connected.first.ssid;
    return switch (snapshot.status) {
      NetworkConnectivityStatus.online ||
      NetworkConnectivityStatus.limited ||
      NetworkConnectivityStatus.local ||
      NetworkConnectivityStatus.captivePortal => '已连接',
      NetworkConnectivityStatus.connecting => '连接中…',
      NetworkConnectivityStatus.disabled => '已关闭',
      NetworkConnectivityStatus.unavailable ||
      NetworkConnectivityStatus.disconnected => '未连接',
    };
  }

  static String _bluetoothSubtitle(BluetoothState state) {
    if (!state.serviceAvailable) return '服务不可用';
    if (!state.available) return '没有适配器';
    if (!state.powered) return '已关闭';
    final connected = state.devices.where((device) => device.connected);
    if (connected.isNotEmpty) return connected.first.name;
    return state.adapterName.isEmpty ? '已开启' : state.adapterName;
  }

  /// The reverse mapping, for the confirmation the provider is holding.
  static NeoPowerAction _powerAction(SessionPowerAction action) =>
      switch (action) {
        SessionPowerAction.lock => NeoPowerAction.lock,
        SessionPowerAction.logout => NeoPowerAction.logout,
        SessionPowerAction.suspend => NeoPowerAction.suspend,
        SessionPowerAction.hibernate => NeoPowerAction.hibernate,
        SessionPowerAction.reboot => NeoPowerAction.reboot,
        SessionPowerAction.powerOff => NeoPowerAction.powerOff,
      };

  static SessionPowerAction _sessionAction(NeoPowerAction action) =>
      switch (action) {
        NeoPowerAction.lock => SessionPowerAction.lock,
        NeoPowerAction.logout => SessionPowerAction.logout,
        NeoPowerAction.suspend => SessionPowerAction.suspend,
        NeoPowerAction.hibernate => SessionPowerAction.hibernate,
        NeoPowerAction.reboot => SessionPowerAction.reboot,
        NeoPowerAction.powerOff => SessionPowerAction.powerOff,
      };
}

/// Volume slider plus the speaker button that mutes it.
class _VolumeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(neoVolumeProvider);
    final controller = ref.read(neoVolumeProvider.notifier);
    final muted = volume.muted || volume.level <= 0;
    return _SliderRow(
      icon: muted ? Icons.volume_off : Icons.volume_up,
      label: neoVolumeLabel(volume.level, muted: muted),
      value: volume.ready ? volume.level : 0,
      enabled: volume.ready,
      onDragStart: (value) {
        controller.beginDrag();
        controller.setLevel(value);
      },
      onDrag: controller.setLevel,
      onDragEnd: controller.commitLevel,
      trailing: NeoPopupIconButton(
        icon: muted ? Icons.volume_up : Icons.volume_off,
        tooltip: muted ? '取消静音' : '静音',
        onPressed: controller.toggleMute,
      ),
    );
  }
}

/// Brightness slider for the output this bar is on.
class _BrightnessRow extends ConsumerWidget {
  const _BrightnessRow({
    required this.monitorId,
    required this.dragValue,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  final int monitorId;
  final double? dragValue;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(displayLayoutProvider);
    final outputs = layout?.outputs ?? const <DisplayOutput>[];
    DisplayOutput? output;
    for (final candidate in outputs) {
      if (candidate.monitorId == monitorId) output = candidate;
    }
    output ??= layout?.mainOutput;
    final brightness = ref.watch(displayBrightnessProvider);
    final controller = ref.read(displayBrightnessProvider.notifier);
    final target = output;
    final level =
        dragValue ??
        (target == null ? 0.72 : brightness.levels[target.monitorId] ?? 0.72);
    final loading =
        target == null || brightness.loading.contains(target.monitorId);

    return _SliderRow(
      icon: Icons.brightness_6_outlined,
      label: neoBrightnessLabel(level),
      value: level,
      enabled: target != null && !loading,
      onDragStart: (value) {
        if (target == null) return;
        onDragStart(value);
        controller.setLevel(target, value);
      },
      onDrag: (value) {
        if (target == null) return;
        onDrag(value);
        controller.setLevel(target, value);
      },
      onDragEnd: (value) {
        if (target == null) return;
        onDragEnd(value);
        controller.commitLevel(target, value);
      },
    );
  }
}

/// One labelled slider, the shape both rows above share.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    this.enabled = true,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: enabled
              ? theme.colors.textPrimary
              : theme.colors.glyphInactive,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NeoSlider(
            value: value.clamp(0.0, 1.0).toDouble(),
            enabled: enabled,
            onDragStart: onDragStart,
            onDrag: onDrag,
            onDragEnd: onDragEnd,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: theme.text.systemBarValue.copyWith(
              fontSize: 12,
              color: theme.colors.textSecondary,
            ),
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: 4),
          trailing,
        ],
      ],
    );
  }
}

/// A compact horizontal slider.
///
/// Written rather than taken from Material: Denial's shell has no `Material`
/// ancestor for the bar's popups, and the stock slider's thumb and padding are
/// far too large for a 380px-wide panel. The value is emitted continuously and
/// once more on release, because the caller debounces the first and commits the
/// second.
class _NeoSlider extends StatefulWidget {
  const _NeoSlider({
    required this.value,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final bool enabled;

  @override
  State<_NeoSlider> createState() => _NeoSliderState();
}

class _NeoSliderState extends State<_NeoSlider> {
  static const double _trackHeight = 6;
  static const double _thumbRadius = 7;

  bool _dragging = false;

  /// The last value this slider emitted.
  ///
  /// The release has to carry the value the user ended on, and the parent's
  /// rebuild may not have landed yet when the gesture ends — reading
  /// `widget.value` there can hand back the value from the previous frame, which
  /// commits one step behind the knob.
  double? _lastValue;

  double _valueAt(Offset localPosition, double width) {
    final usable = width - _thumbRadius * 2;
    if (usable <= 0) return 0;
    return ((localPosition.dx - _thumbRadius) / usable).clamp(0.0, 1.0);
  }

  void _emit(ValueChanged<double> callback, double value) {
    _lastValue = value;
    callback(value);
  }

  void _release() {
    setState(() => _dragging = false);
    widget.onDragEnd(_lastValue ?? widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final track = theme.colors.hairlineSoft;
    final active = theme.accent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: widget.enabled
                ? (details) {
                    setState(() => _dragging = true);
                    _emit(
                      widget.onDragStart,
                      _valueAt(details.localPosition, width),
                    );
                  }
                : null,
            onHorizontalDragUpdate: widget.enabled
                ? (details) => _emit(
                    widget.onDrag,
                    _valueAt(details.localPosition, width),
                  )
                : null,
            onHorizontalDragEnd: widget.enabled ? (_) => _release() : null,
            onHorizontalDragCancel: widget.enabled ? _release : null,
            // A click moves the knob to the pointer and commits, so the track is
            // usable without dragging.
            onTapDown: widget.enabled
                ? (details) {
                    final value = _valueAt(details.localPosition, width);
                    _emit(widget.onDragStart, value);
                    _emit(widget.onDrag, value);
                  }
                : null,
            onTapUp: widget.enabled ? (_) => _release() : null,
            onTapCancel: widget.enabled ? _release : null,
            child: SizedBox(
              height: _thumbRadius * 2 + 6,
              child: CustomPaint(
                painter: _NeoSliderPainter(
                  value: widget.value.clamp(0.0, 1.0).toDouble(),
                  track: track,
                  active: widget.enabled ? active : track,
                  thumb: theme.colors.sliderThumb,
                  thumbRadius: _thumbRadius,
                  trackHeight: _trackHeight,
                  highlighted: _dragging,
                ),
                size: Size(width, _thumbRadius * 2 + 6),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NeoSliderPainter extends CustomPainter {
  const _NeoSliderPainter({
    required this.value,
    required this.track,
    required this.active,
    required this.thumb,
    required this.thumbRadius,
    required this.trackHeight,
    required this.highlighted,
  });

  final double value;
  final Color track;
  final Color active;
  final Color thumb;
  final double thumbRadius;
  final double trackHeight;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.height / 2;
    final left = thumbRadius;
    final right = size.width - thumbRadius;
    final radius = trackHeight / 2;
    final trackPaint = Paint()..color = track;
    final activePaint = Paint()..color = active;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        centre - radius,
        right,
        centre + radius,
        Radius.circular(radius),
      ),
      trackPaint,
    );
    final filled = left + (right - left) * value;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        centre - radius,
        filled,
        centre + radius,
        Radius.circular(radius),
      ),
      activePaint,
    );
    canvas.drawCircle(
      Offset(filled, centre),
      highlighted ? thumbRadius : thumbRadius - 1,
      Paint()..color = thumb,
    );
  }

  @override
  bool shouldRepaint(_NeoSliderPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.active != active ||
      oldDelegate.track != track ||
      oldDelegate.thumb != thumb ||
      oldDelegate.highlighted != highlighted;
}

/// Two-column grid of on/off tiles.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < tiles.length; index += 2) ...[
          if (index > 0) const SizedBox(height: 8),
          // `IntrinsicHeight` is what makes both tiles in a row the same height
          // without stretching them to the incoming constraint. A bare
          // `CrossAxisAlignment.stretch` here asks the row to fill its cross
          // axis, and inside the panel's vertical scroll view that axis is
          // unbounded: the row takes an infinite height, everything after it in
          // the column is pushed out of the viewport, and the card is left at
          // its maximum height showing nothing below the sliders.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[index]),
                const SizedBox(width: 8),
                Expanded(
                  child: index + 1 < tiles.length
                      ? tiles[index + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One tile: an icon, a title, a live subtitle, and an on/off plate.
class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
    this.onExpand,
    this.busy = false,
    this.enabled = true,
    this.expanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;

  /// Toggles the subsystem. The tile's whole body, minus the chevron.
  final VoidCallback onTap;

  /// Opens the detail list, when the tile has one. Kept separate from [onTap]
  /// so a tile never has to guess whether a tap meant "turn it off" or "show me
  /// what is on it".
  final VoidCallback? onExpand;

  final bool busy;
  final bool enabled;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final foreground = active
        ? theme.accentPalette.onPrimary
        : theme.colors.textPrimary;
    final fill = active
        ? theme.accent
        : (enabled ? theme.colors.tileOff : theme.colors.surfaceContainerLow);
    return Semantics(
      button: true,
      toggled: active,
      label: '$title, $subtitle',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: Motion.cardSettle,
            curve: Motion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(theme.chipRadius),
              border: Border.all(
                color: expanded
                    ? theme.accent.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: enabled ? foreground : theme.colors.glyphInactive,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.systemBarValue.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? foreground
                              : theme.colors.glyphInactive,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.systemBarCaption.copyWith(
                          fontSize: 10.5,
                          color: active
                              ? foreground.withValues(alpha: 0.82)
                              : theme.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: foreground,
                    ),
                  )
                else if (onExpand != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: active
                              ? foreground
                              : theme.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Wi-Fi list, with an inline password field for secured networks.
class _WifiDetail extends ConsumerWidget {
  const _WifiDetail({
    required this.state,
    required this.passwordSsid,
    required this.password,
    required this.onRequestPassword,
    required this.onCancelPassword,
  });

  final NetworkConnectivityState state;
  final String? passwordSsid;
  final TextEditingController password;
  final ValueChanged<String> onRequestPassword;
  final VoidCallback onCancelPassword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShellTheme.of(context);
    final controller = ref.read(networkConnectivityProvider.notifier);
    // The row's id is the host's network identity, which is also the key the
    // provider uses for its busy set and its permission checks.
    final byId = <String, WifiNetwork>{
      for (final network in state.snapshot.networks) network.identity: network,
    };
    final entries = neoWifiPanelEntries(<NeoWifiEntry>[
      for (final network in state.snapshot.networks)
        NeoWifiEntry(
          id: network.identity,
          ssid: network.ssid,
          strength: network.strength,
          connected: network.connected,
          secured: network.security.requiresPassword,
        ),
    ], limit: 8);

    return _DetailCard(
      title: '网络',
      action: state.scanning
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            )
          : NeoPopupIconButton(
              icon: Icons.refresh,
              tooltip: '重新扫描',
              onPressed: () => unawaited(controller.scan()),
            ),
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                switch (state) {
                  _ when state.scanning => '正在扫描…',
                  _ when !state.snapshot.wirelessEnabled => '无线已关闭',
                  _ => '没有找到网络',
                },
                style: theme.text.systemBarCaption.copyWith(
                  color: theme.colors.textTertiary,
                ),
              ),
            )
          : Column(
              children: [
                for (final entry in entries)
                  _WifiRow(
                    entry: entry,
                    busy: state.busyNetworks.contains(entry.id),
                    passwordOpen: passwordSsid == entry.ssid,
                    password: password,
                    onTap: () {
                      final network = byId[entry.id];
                      if (network == null) return;
                      if (network.connected) {
                        unawaited(controller.disconnect(network));
                        return;
                      }
                      // A saved network already has its credentials, so asking
                      // again would be busywork; only an unknown secured one
                      // needs the field.
                      if (entry.secured && !network.saved) {
                        onRequestPassword(entry.ssid);
                        return;
                      }
                      unawaited(controller.connect(network));
                    },
                    onSubmitPassword: () {
                      final network = byId[entry.id];
                      if (network == null) return;
                      unawaited(
                        controller.connect(network, password: password.text),
                      );
                      onCancelPassword();
                    },
                  ),
              ],
            ),
    );
  }
}

class _WifiRow extends StatelessWidget {
  const _WifiRow({
    required this.entry,
    required this.busy,
    required this.passwordOpen,
    required this.password,
    required this.onTap,
    required this.onSubmitPassword,
  });

  final NeoWifiEntry entry;
  final bool busy;
  final bool passwordOpen;
  final TextEditingController password;
  final VoidCallback onTap;
  final VoidCallback onSubmitPassword;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailRow(
          icon: entry.connected ? Icons.wifi : _signalIcon(entry.strength),
          title: entry.ssid,
          subtitle: entry.connected ? '已连接' : (entry.secured ? '需要密码' : '开放网络'),
          trailing: busy
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              : (entry.secured
                    ? Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: theme.colors.textTertiary,
                      )
                    : null),
          highlighted: entry.connected,
          onTap: onTap,
        ),
        if (passwordOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: _InlineField(
              controller: password,
              hint: '输入「${entry.ssid}」的密码',
              onSubmit: onSubmitPassword,
            ),
          ),
      ],
    );
  }
}

/// Bluetooth devices, paired and connected first.
class _BluetoothDetail extends ConsumerWidget {
  const _BluetoothDetail({required this.state});

  final BluetoothState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShellTheme.of(context);
    final controller = ref.read(bluetoothProvider.notifier);
    final entries = neoBluetoothPanelEntries(<NeoBluetoothEntry>[
      for (final device in state.devices)
        NeoBluetoothEntry(
          id: device.objectPath,
          name: device.name.isEmpty ? device.address : device.name,
          connected: device.connected,
          paired: device.paired,
          signal: device.signalStrength,
        ),
    ], limit: 8);
    final byId = <String, BluetoothDeviceInfo>{
      for (final device in state.devices) device.objectPath: device,
    };

    return _DetailCard(
      title: '蓝牙设备',
      action: state.scanning
          ? NeoPopupIconButton(
              icon: Icons.stop,
              tooltip: '停止扫描',
              onPressed: () => unawaited(controller.stopScan()),
            )
          : NeoPopupIconButton(
              icon: Icons.search,
              tooltip: '扫描设备',
              onPressed: () => unawaited(controller.scan()),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.pairingRequest case final request?)
            _PairingPrompt(request: request)
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                switch (state) {
                  _ when state.scanning => '正在扫描…',
                  _ when !state.powered => '蓝牙已关闭',
                  _ => '没有已配对的设备',
                },
                style: theme.text.systemBarCaption.copyWith(
                  color: theme.colors.textTertiary,
                ),
              ),
            )
          else
            for (final entry in entries)
              _DetailRow(
                icon: entry.connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth,
                title: entry.name,
                subtitle: entry.connected
                    ? '已连接'
                    : (entry.paired ? '已配对' : '未配对'),
                trailing: state.busyDevices.contains(entry.id)
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : null,
                highlighted: entry.connected,
                onTap: () {
                  final device = byId[entry.id];
                  if (device == null) return;
                  unawaited(controller.toggleConnection(device));
                },
              ),
        ],
      ),
    );
  }
}

/// A pairing request the host is waiting on.
class _PairingPrompt extends ConsumerWidget {
  const _PairingPrompt({required this.request});

  final BluetoothPairingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShellTheme.of(context);
    final controller = ref.read(bluetoothProvider.notifier);
    final name = request.deviceName.isEmpty ? '设备' : request.deviceName;
    final code = request.passkey?.toString() ?? request.pinCode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            code == null ? '「$name」请求配对' : '「$name」配对码 $code',
            style: theme.text.systemBarValue.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SmallButton(
                  label: '拒绝',
                  onPressed: () => controller.respondToPairing(accepted: false),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SmallButton(
                  label: '接受',
                  primary: true,
                  onPressed: () => controller.respondToPairing(accepted: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The session actions, with the ones that can lose work marked as such.
class _PowerRow extends StatelessWidget {
  const _PowerRow({
    required this.onTap,
    required this.available,
    required this.blockedReason,
    required this.busy,
  });

  final ValueChanged<NeoPowerAction> onTap;
  final bool Function(NeoPowerAction action) available;
  final String? Function(NeoPowerAction action) blockedReason;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final action in neoPowerActionOrder)
          _PowerButton(
            action: action,
            enabled: !busy && available(action),
            reason: blockedReason(action),
            onPressed: () => onTap(action),
            color: neoPowerActionNeedsConfirmation(action)
                ? theme.colors.textPrimary
                : theme.colors.textSecondary,
          ),
      ],
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.action,
    required this.enabled,
    required this.onPressed,
    required this.color,
    this.reason,
  });

  final NeoPowerAction action;
  final bool enabled;
  final VoidCallback onPressed;
  final Color color;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final icon = switch (action) {
      NeoPowerAction.lock => Icons.lock_outline,
      NeoPowerAction.logout => Icons.logout,
      NeoPowerAction.suspend => Icons.bedtime_outlined,
      NeoPowerAction.hibernate => Icons.nightlight_outlined,
      NeoPowerAction.reboot => Icons.restart_alt,
      NeoPowerAction.powerOff => Icons.power_settings_new,
    };
    return Tooltip(
      message: enabled
          ? neoPowerActionLabel(action)
          : '${neoPowerActionLabel(action)}${reason == null ? '' : '：$reason'}',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.tileOff.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(theme.roundButtonRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(
                icon,
                size: 17,
                color: enabled ? color : theme.colors.glyphInactive,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerConfirmation extends StatelessWidget {
  const _PowerConfirmation({
    required this.action,
    required this.onCancel,
    required this.onConfirm,
  });

  final NeoPowerAction action;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          neoPowerConfirmationQuestion(action),
          style: theme.text.systemBarValue.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SmallButton(label: '取消', onPressed: onCancel),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SmallButton(
                label: neoPowerActionLabel(action),
                primary: true,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared chrome for a detail list under a tile.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(theme.chipRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.text.systemBarValue.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: highlighted ? theme.accent : theme.colors.textSecondary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.systemBarValue.copyWith(
                    fontSize: 12,
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: theme.text.systemBarCaption.copyWith(
                  fontSize: 10.5,
                  color: theme.colors.textTertiary,
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: 6),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A one-line text field for a Wi-Fi password or a pairing PIN.
class _InlineField extends StatefulWidget {
  const _InlineField({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The panel captures the keyboard while it is open, so the field can be
    // focused as soon as it appears instead of waiting for a click.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surfaceContainer,
              borderRadius: BorderRadius.circular(theme.chipRadius),
              border: Border.all(color: theme.colors.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              child: EditableText(
                controller: widget.controller,
                focusNode: _focus,
                obscureText: true,
                style: theme.text.systemBarValue.copyWith(fontSize: 12),
                cursorColor: theme.accent,
                backgroundCursorColor: theme.colors.hairline,
                onSubmitted: (_) => widget.onSubmit(),
                // Denial's popups run inside the shell's own surface, which the
                // pointer policies hand the keyboard to while a popup is open.
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _SmallButton(label: '连接', primary: true, onPressed: widget.onSubmit),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: primary
                ? theme.accent
                : theme.colors.tileOff.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(theme.roundButtonRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.text.systemBarValue.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: primary
                    ? theme.accentPalette.onPrimary
                    : theme.colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          size: 14,
          color: theme.colors.performanceWarning,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: theme.text.systemBarCaption.copyWith(
              color: theme.colors.performanceWarning,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _signalIcon(int strength) {
  if (strength >= 75) return Icons.network_wifi_3_bar;
  if (strength >= 50) return Icons.network_wifi_2_bar;
  if (strength >= 25) return Icons.network_wifi_1_bar;
  return Icons.network_wifi_1_bar;
}
