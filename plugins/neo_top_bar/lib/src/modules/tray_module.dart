/// StatusNotifier tray. The host owns icon rendering, activation and menus; the
/// bar only decides placement and whether the tray is shown at all.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_card.dart';

class TrayModule implements NeoModule {
  const TrayModule();

  @override
  NeoModuleDescriptor get descriptor => trayModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _TrayContent(module: module);
}

class _TrayContent extends ConsumerWidget {
  const _TrayContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = module.services;
    // The host's tray renderer does not decide its own visibility, so without
    // this a hidden or empty tray would leave a stray empty pill on the bar.
    if (!ref.watch(services.trayVisible)) return const SizedBox.shrink();
    if (ref.watch(services.trayItemIds).isEmpty) {
      return const SizedBox.shrink();
    }
    return NeoCard(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      padding: EdgeInsets.symmetric(
        // A vertical pill is only as wide as the strip; see `neoCardPadding`.
        horizontal: (module.horizontal ? 10 : 6) * module.density,
        vertical: module.horizontal ? 0 : 10 * module.density,
      ),
      child: services.buildSystemTray(context, horizontal: module.horizontal),
    );
  }
}
