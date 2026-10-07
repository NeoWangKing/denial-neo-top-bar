/// Control centre pill: the status readout, and the button that opens the panel.
///
/// The pill is deliberately small — a volume glyph, a network glyph, a Bluetooth
/// glyph when the adapter is on, and the battery percentage — so it can stand in
/// for the separate battery pill without turning the trailing end of the bar
/// into a dashboard. Everything it shows opens into a control in the panel.
///
/// Each glyph is also its own shortcut: a right-click on the speaker mutes, on
/// the network glyph toggles the radio, on the Bluetooth glyph toggles the
/// adapter. That is the same secondary-button vocabulary the status tray uses,
/// and it is why the glyphs are separate hit targets rather than one picture.
/// The battery has no shortcut on purpose: there is no "toggle the battery".
library;

import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/control_center_model.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
import 'control_center_link.dart';
import 'control_center_panel.dart';
import 'control_center_volume.dart';

class ControlCenterModule implements NeoModule {
  const ControlCenterModule();

  @override
  NeoModuleDescriptor get descriptor => controlCenterModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _ControlCenterContent(module: module);
}

class _ControlCenterContent extends ConsumerWidget {
  const _ControlCenterContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShellTheme.of(context);
    final volume = ref.watch(neoVolumeProvider);
    final network = ref.watch(networkConnectivityProvider);
    final bluetooth = ref.watch(bluetoothProvider);
    final battery = ref.watch(module.services.battery);
    final wired = ref.watch(neoWiredLinkProvider).value ?? false;
    final size = 16 * module.density.clamp(0.85, 1.15).toDouble();
    final gap = 7 * module.density;

    final glyph = theme.colors.textPrimary;
    final dim = theme.colors.glyphInactive;
    final muted = volume.muted || !volume.ready || volume.level <= 0;
    final glyphState = neoNetworkGlyph(
      wiredUp: wired,
      wifiConnected: network.snapshot.connectedNetwork != null,
      wirelessEnabled: network.snapshot.wirelessEnabled,
    );

    void openPanel() => openControlCenterPanel(
      context: context,
      ref: ref,
      module: module,
      anchor: neoAnchorRectOf(context),
    );

    final glyphs = <Widget>[
      _StatusGlyph(
        icon: switch (neoVolumeGlyphStep(volume.level, muted: volume.muted)) {
          0 => Icons.volume_off,
          1 => Icons.volume_mute,
          2 => Icons.volume_down,
          _ => Icons.volume_up,
        },
        size: size,
        color: glyph,
        tooltip: muted ? '音量（静音）· 右键取消静音' : '音量 · 右键静音',
        onTap: openPanel,
        onSecondary: ref.read(neoVolumeProvider.notifier).toggleMute,
      ),
      _StatusGlyph(
        icon: switch (glyphState) {
          NeoNetworkGlyph.ethernet => Icons.settings_ethernet,
          NeoNetworkGlyph.wifi => Icons.wifi,
          NeoNetworkGlyph.offline => Icons.wifi,
          NeoNetworkGlyph.wifiOff => Icons.wifi_off,
        },
        size: size,
        color: switch (glyphState) {
          // A cable is as "connected" as a joined network; only the radio-off
          // and radio-on-but-idle states are the quiet ones.
          NeoNetworkGlyph.ethernet || NeoNetworkGlyph.wifi => glyph,
          NeoNetworkGlyph.offline || NeoNetworkGlyph.wifiOff => dim,
        },
        tooltip: switch (glyphState) {
          NeoNetworkGlyph.ethernet => '有线网络 · 右键开关无线',
          NeoNetworkGlyph.wifi => 'Wi-Fi · 右键关闭无线',
          NeoNetworkGlyph.offline => '无线未连接 · 右键关闭无线',
          NeoNetworkGlyph.wifiOff => '无线已关闭 · 右键开启无线',
        },
        onTap: openPanel,
        onSecondary: network.snapshot.wifiDeviceAvailable
            ? ref.read(networkConnectivityProvider.notifier).toggleWireless
            : null,
      ),
      if (bluetooth.powered && bluetooth.available)
        _StatusGlyph(
          icon: bluetooth.devices.any((device) => device.connected)
              ? Icons.bluetooth_connected
              : Icons.bluetooth,
          size: size,
          color: glyph,
          tooltip: '蓝牙 · 右键关闭',
          onTap: openPanel,
          onSecondary: ref.read(bluetoothProvider.notifier).togglePower,
        ),
      if (battery.capacity case final capacity?)
        _StatusGlyph(
          icon: null,
          label: '$capacity%',
          size: size,
          color: battery.charging ? theme.accent : glyph,
          tooltip: '电量 $capacity%',
          // No secondary action: there is no "toggle the battery", and inventing
          // one would only misfire.
          onTap: openPanel,
        ),
    ];

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: '控制中心',
      onPressed: openPanel,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < glyphs.length; index++) ...[
              if (index > 0) SizedBox(width: gap),
              glyphs[index],
            ],
          ],
        ),
      ),
    );
  }
}

/// One glyph in the pill: a tap opens the panel, a right-click acts on it.
class _StatusGlyph extends StatefulWidget {
  const _StatusGlyph({
    required this.icon,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.onSecondary,
  });

  /// Mutually exclusive with [label].
  final IconData? icon;

  /// Text form, used for the battery percentage.
  final String? label;

  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  /// The secondary-button action, when this glyph has one.
  final VoidCallback? onSecondary;

  @override
  State<_StatusGlyph> createState() => _StatusGlyphState();
}

class _StatusGlyphState extends State<_StatusGlyph> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final highlight = _hovered && widget.onSecondary != null;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Listener(
              // A raw `Listener`, not a gesture recogniser: the pill's own
              // `NeoCardButton` owns the tap, and a recogniser here would have to
              // win an arena against it to see the secondary button at all.
              onPointerDown: (event) {
                if (event.buttons != kSecondaryButton) return;
                widget.onSecondary?.call();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Left clicks fall through to the pill as well, so tapping a
                // glyph does what tapping the pill does; the highlight below is
                // the only thing this target adds.
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: Motion.cardSettle,
                  curve: Motion.standard,
                  padding: EdgeInsets.symmetric(
                    horizontal: 3 * (widget.size / 16),
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: highlight
                        ? theme.accent.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: theme.borderRadius(7),
                  ),
                  child: widget.icon != null
                      ? Icon(
                          widget.icon,
                          size: widget.size,
                          color: widget.color,
                        )
                      : Text(
                          widget.label ?? '',
                          style: ShellText.systemBarValue.copyWith(
                            fontSize: 12 * (widget.size / 16),
                            fontWeight: FontWeight.w600,
                            color: widget.color,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
