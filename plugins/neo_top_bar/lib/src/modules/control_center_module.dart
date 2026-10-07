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
import '../core/l10n.dart';
import '../core/l10n_context.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_setting_controls.dart';
import 'control_center_link.dart';
import 'control_center_panel.dart';
import 'control_center_volume.dart';

class ControlCenterModule implements NeoModule, NeoModuleSettings {
  const ControlCenterModule();

  @override
  NeoModuleDescriptor get descriptor => controlCenterModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _ControlCenterContent(module: module);

  /// The first module with settings of its own, and the reason the settings card
  /// grew an expandable area: which readouts the pill carries, and which session
  /// buttons the panel's row offers.
  ///
  /// Both write `null` when the selection is back to the default, so a file that
  /// has never been customised stays empty.
  @override
  Widget buildSettings(BuildContext context, NeoModuleSettingsScope scope) {
    final s = context.neoStrings;
    final options = neoControlCenterOptions(scope.options);
    final glyphs = options.glyphs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoSettingGroup(
          title: s.pillGlyphs,
          children: [
            for (final glyph in neoPillGlyphOrder)
              NeoSettingRow(
                label: s.pillGlyphLabel(glyph),
                description: s.pillGlyphDescription(glyph),
                child: Builder(
                  builder: (context) {
                    final selected = glyphs.contains(glyph);
                    // The last remaining readout cannot be switched off: an
                    // empty pill reads as a broken one, not as a choice.
                    final locked =
                        selected && !neoCanDisableGlyph(glyphs, glyph);
                    return NeoSettingToggle(
                      value: selected,
                      onChanged: locked
                          ? null
                          : (value) => scope.setOption(
                              neoControlCenterGlyphsKey,
                              _encodeGlyphs(glyphs, glyph, value),
                            ),
                      tooltip: locked ? s.pillGlyphsAtLeastOne : null,
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        NeoSettingGroup(
          title: s.powerButtons,
          children: [
            for (final action in NeoPowerAction.values)
              NeoSettingRow(
                label: s.powerActionLabel(action),
                description: _powerDescription(action, s),
                child: NeoSettingToggle(
                  value: options.powerActions.contains(action),
                  onChanged: (value) => scope.setOption(
                    neoControlCenterPowerKey,
                    _encodePower(options.powerActions, action, value),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The selection with [glyph] switched on or off, or null when it is the
/// default again.
List<String>? _encodeGlyphs(
  Set<NeoPillGlyph> current,
  NeoPillGlyph glyph,
  bool value,
) {
  final next = <NeoPillGlyph>{...current};
  if (value) {
    next.add(glyph);
  } else {
    next.remove(glyph);
  }
  // Switching the last one off is refused by the settings UI, so a full
  // selection is the default and can be dropped from the file again.
  if (next.length == neoPillGlyphOrder.length) return null;
  return <String>[
    for (final candidate in neoPillGlyphOrder)
      if (next.contains(candidate)) candidate.name,
  ];
}

/// The power selection with [action] switched on or off, or null when it is the
/// default row again.
List<String>? _encodePower(
  List<NeoPowerAction> current,
  NeoPowerAction action,
  bool value,
) {
  final next = <NeoPowerAction>{...current};
  if (value) {
    next.add(action);
  } else {
    next.remove(action);
  }
  if (next.length == neoPowerActionOrder.length) return null;
  return <String>[
    for (final candidate in neoPowerActionOrder)
      if (next.contains(candidate)) candidate.name,
  ];
}

String _powerDescription(NeoPowerAction action, NeoStrings s) =>
    switch (action) {
      NeoPowerAction.lock => s.powerLockHint,
      NeoPowerAction.logout => s.powerLogoutHint,
      NeoPowerAction.suspend => s.powerSuspendHint,
      NeoPowerAction.hibernate => s.powerHibernateHint,
      NeoPowerAction.reboot => s.powerRebootHint,
      NeoPowerAction.powerOff => s.powerShutdownHint,
    };

class _ControlCenterContent extends ConsumerWidget {
  const _ControlCenterContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.neoStrings;
    final theme = ShellTheme.of(context);
    final volume = ref.watch(neoVolumeProvider);
    final network = ref.watch(networkConnectivityProvider);
    final bluetooth = ref.watch(bluetoothProvider);
    final battery = ref.watch(module.services.battery);
    final wired = ref.watch(neoWiredLinkProvider).value ?? false;
    // Glyph sizes come from the bar's thickness, so switching between compact
    // and comfortable spacing moves the pills apart without shrinking what is
    // drawn inside them. Only the gaps follow the density.
    final size = module.glyphSize(0.36);
    final gap = 7 * module.density;
    // Which readouts the user kept, resolved from the module's own settings.
    final selected = neoControlCenterOptions(module.options).glyphs;

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
      if (selected.contains(NeoPillGlyph.volume))
        _StatusGlyph(
          icon: switch (neoVolumeGlyphStep(volume.level, muted: volume.muted)) {
            0 => Icons.volume_off,
            1 => Icons.volume_mute,
            2 => Icons.volume_down,
            _ => Icons.volume_up,
          },
          size: size,
          color: glyph,
          tooltip: muted ? s.glyphVolumeMutedTooltip : s.glyphVolumeTooltip,
          onTap: openPanel,
          onSecondary: ref.read(neoVolumeProvider.notifier).toggleMute,
        ),
      if (selected.contains(NeoPillGlyph.network))
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
            NeoNetworkGlyph.ethernet => s.glyphWiredTooltip,
            NeoNetworkGlyph.wifi => s.glyphWifiTooltip,
            NeoNetworkGlyph.offline => s.glyphWifiDisconnectedTooltip,
            NeoNetworkGlyph.wifiOff => s.glyphWifiOffTooltip,
          },
          onTap: openPanel,
          onSecondary: network.snapshot.wifiDeviceAvailable
              ? ref.read(networkConnectivityProvider.notifier).toggleWireless
              : null,
        ),
      if (selected.contains(NeoPillGlyph.bluetooth) &&
          bluetooth.powered &&
          bluetooth.available)
        _StatusGlyph(
          icon: bluetooth.devices.any((device) => device.connected)
              ? Icons.bluetooth_connected
              : Icons.bluetooth,
          size: size,
          color: glyph,
          tooltip: s.glyphBluetoothTooltip,
          onTap: openPanel,
          onSecondary: ref.read(bluetoothProvider.notifier).togglePower,
        ),
      if (selected.contains(NeoPillGlyph.battery))
        if (battery.capacity case final capacity?)
          _StatusGlyph(
            icon: null,
            label: '$capacity%',
            size: size,
            color: battery.charging ? theme.accent : glyph,
            tooltip: s.batteryTooltip(capacity),
            // No secondary action: there is no "toggle the battery", and inventing
            // one would only misfire.
            onTap: openPanel,
          ),
    ];

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: s.moduleLabel(NeoModuleIds.controlCenter),
      onPressed: openPanel,
      child: Center(
        child: Flex(
          // A vertical bar has only the strip's width, so a row of glyphs would
          // run off it; they stack instead, in the same order.
          direction: module.horizontal ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < glyphs.length; index++) ...[
              if (index > 0)
                SizedBox(
                  width: module.horizontal ? gap : 0,
                  height: module.horizontal ? 0 : gap,
                ),
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
