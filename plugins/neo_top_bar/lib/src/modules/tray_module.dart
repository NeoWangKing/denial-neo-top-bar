/// StatusNotifier tray. The host owns icon rendering, activation and menus; the
/// bar only decides placement, whether the tray is shown at all, and how many
/// icons it keeps when the bar is over budget.
library;

import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bar_budget.dart';
import '../core/l10n_context.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_popup_surface.dart';

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
    final s = context.neoStrings;
    final services = module.services;
    // The host's tray renderer does not decide its own visibility, so without
    // this a hidden or empty tray would leave a stray empty pill on the bar.
    if (!ref.watch(services.trayVisible)) return const SizedBox.shrink();
    final ids = ref.watch(services.trayItemIds);
    if (ids.isEmpty) return const SizedBox.shrink();

    // Over budget: keep the leading icons and count the rest. The tray is the
    // one pill whose width is dictated by other applications, so it gives way
    // first — before media loses its title or the clock loses its date.
    final collapse =
        module.concession >= NeoConcession.tray &&
        ids.length > neoTrayCompactLimit;
    final shown = collapse ? ids.take(neoTrayCompactLimit).toList() : ids;
    final hidden = ids.length - shown.length;

    return NeoCard(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      padding: EdgeInsets.symmetric(
        // A vertical pill is only as wide as the strip; see `neoCardPadding`.
        horizontal: (module.horizontal ? 10 : 6) * module.density,
        vertical: module.horizontal ? 0 : 10 * module.density,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          services.buildSystemTray(
            context,
            horizontal: module.horizontal,
            itemIds: shown,
          ),
          if (hidden > 0) ...[
            SizedBox(width: 6 * module.density),
            _TrayOverflow(
              label: s.trayMoreIcons(hidden),
              size: module.glyphSize(0.4, min: 12, max: 18),
              onPressed: () => _openTrayPanel(context, ids),
            ),
          ],
        ],
      ),
    );
  }

  /// The collapsed icons, in a panel the host renders.
  ///
  /// Not a second tray implementation: the same `buildSystemTray` draws them, so
  /// activation, context menus and submenus behave exactly as they do on the bar.
  void _openTrayPanel(BuildContext context, List<String> ids) {
    final s = context.neoStrings;
    final services = module.services;
    final ref = ProviderScope.containerOf(context, listen: false);
    // The pill's rectangle has to be read *here*, on the bar's own context.
    // Inside the builder below, `context` is the popup host's: its box is the
    // whole scene, so anchoring to it put this panel in the middle of the screen
    // (`neoAnchoredPopupPlacement` finds no room beside a scene-sized anchor and
    // the card falls back to centering). The builder keeps that context for its
    // theme, which lives in the popup layer.
    final anchor = neoAnchorRectOf(context);
    ref
        .read(shellPopupControllerProvider.notifier)
        .show(
          keyName: 'neo_top_bar.tray',
          debugLabel: 'NeoTopBar tray overflow',
          dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
          barrierColor: Colors.transparent,
          builder: (context, handle) => NeoPopupSurface(
            services: services,
            monitorId: module.monitorId,
            anchor: anchor,
            maxWidth: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.moduleLabel(NeoModuleIds.tray),
                        style: ShellTheme.of(context).text.systemBarValue
                            .copyWith(fontSize: 16),
                      ),
                    ),
                    NeoPopupIconButton(
                      icon: Icons.close,
                      tooltip: s.close,
                      onPressed: handle.close,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                services.buildSystemTray(
                  context,
                  horizontal: true,
                  wrap: true,
                  itemIds: ids,
                ),
              ],
            ),
          ),
        );
  }
}

/// The chevron that opens the collapsed icons.
///
/// A downward arrow rather than the `+N` it used to print, because the panel it
/// opens hangs *below* the pill: the arrow says where the rest of the icons are,
/// and how many there are is in the tooltip and in the label a screen reader
/// reads. Windows' tray overflow is the same idea.
class _TrayOverflow extends StatelessWidget {
  const _TrayOverflow({
    required this.label,
    required this.size,
    required this.onPressed,
  });

  final String label;

  /// Glyph size, derived from the pill's own thickness like every other icon.
  final double size;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              // The tile keeps the tap target wider than the glyph, and keeps the
              // chevron readable against a busy tray: it is a control, not a
              // status icon.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.tileOff,
                  borderRadius: theme.borderRadius(theme.chipRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: size,
                    color: theme.colors.textSecondary,
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
