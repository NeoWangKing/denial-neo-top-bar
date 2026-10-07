/// Control centre pill: the status readout, and the button that opens the panel.
///
/// The pill is deliberately small — a volume glyph, a Wi-Fi glyph, a Bluetooth
/// glyph when the adapter is on, and the battery percentage — so it can stand in
/// for the separate battery pill without turning the trailing end of the bar
/// into a dashboard. Everything it shows opens into a control in the panel.
library;

import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/system_services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/control_center_model.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
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
    final size = 16 * module.density.clamp(0.85, 1.15).toDouble();
    final gap = 7 * module.density;

    final glyph = theme.colors.textPrimary;
    final dim = theme.colors.glyphInactive;
    final online =
        network.snapshot.status == NetworkConnectivityStatus.online ||
        network.snapshot.status == NetworkConnectivityStatus.limited;

    final children = <Widget>[
      Icon(
        _volumeIcon(volume.level, muted: volume.muted || !volume.ready),
        size: size,
        color: glyph,
      ),
      Icon(
        // The Wi-Fi radio being off is a different fact from being off-line, and
        // the pill shows both: the slashed glyph means the radio, the dimmed
        // glyph means the connection.
        network.snapshot.wirelessEnabled ? Icons.wifi : Icons.wifi_off,
        size: size,
        color: network.snapshot.wirelessEnabled ? (online ? glyph : dim) : dim,
      ),
    ];
    if (bluetooth.powered && bluetooth.available) {
      children.add(
        Icon(
          bluetooth.devices.any((device) => device.connected)
              ? Icons.bluetooth_connected
              : Icons.bluetooth,
          size: size,
          color: glyph,
        ),
      );
    }
    if (battery.capacity case final capacity?) {
      children.add(
        Text(
          '$capacity%',
          style: ShellText.systemBarValue.copyWith(
            fontSize: 12 * module.density.clamp(0.9, 1.15).toDouble(),
            fontWeight: FontWeight.w600,
            color: battery.charging ? theme.accent : glyph,
          ),
        ),
      );
    }

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: '控制中心',
      onPressed: () => openControlCenterPanel(
        context: context,
        ref: ref,
        module: module,
        anchor: neoAnchorRectOf(context),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) SizedBox(width: gap),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

/// Speaker glyph for a level, including the muted case.
IconData _volumeIcon(double level, {required bool muted}) =>
    switch (neoVolumeGlyphStep(level, muted: muted)) {
      0 => Icons.volume_off,
      1 => Icons.volume_mute,
      2 => Icons.volume_down,
      _ => Icons.volume_up,
    };
