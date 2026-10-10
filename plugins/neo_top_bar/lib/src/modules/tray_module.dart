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
              onPressed: () => _openTrayPanel(context, ids),
            ),
          ],
        ],
      ),
    );
  }

  /// The collapsed icons, in a flyout the host renders.
  ///
  /// Not a second tray implementation: the same `buildSystemTray` draws them, so
  /// activation, context menus and submenus behave exactly as they do on the bar.
  ///
  /// Nothing else goes in this card — no title, no close button. It is a tray
  /// overflow, not a panel: Windows' flyout is the same thing, a small grid of
  /// icons whose dismissal is the click outside (or Escape) that the shell's
  /// dismiss policy already gives it, and a header only made a mostly empty card
  /// out of four icons. The width hugs the grid for the same reason.
  void _openTrayPanel(BuildContext context, List<String> ids) {
    final services = module.services;
    final ref = ProviderScope.containerOf(context, listen: false);
    // The pill's rectangle has to be read *here*, on the bar's own context.
    // Inside the builder below, `context` is the popup host's: its box is the
    // whole scene, so anchoring to it put this panel in the middle of the screen
    // (`neoAnchoredPopupPlacement` finds no room beside a scene-sized anchor and
    // the card falls back to centering). The builder keeps that context for the
    // host's tray, which needs the popup layer's providers.
    final anchor = neoAnchorRectOf(context);
    ref
        .read(shellPopupControllerProvider.notifier)
        .show(
          keyName: 'neo_top_bar.tray',
          debugLabel: 'NeoTopBar tray overflow',
          dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
          barrierColor: Colors.transparent,
          // The card animates itself: the host's fade would put the whole
          // surface — the `BackdropFilter` included — under one opacity layer,
          // and a backdrop filter under an opacity layer samples that layer
          // instead of the scene. The glass then has nothing to blur until the
          // fade reaches 1.0 and snaps in. This is the calendar's bug, and the
          // tray was the one opener that did not opt out of it.
          transitionDuration: neoPopupHostTransition,
          builder: (context, _) => NeoPopupSurface(
            services: services,
            monitorId: module.monitorId,
            anchor: anchor,
            padding: const EdgeInsets.all(_trayFlyoutPadding),
            maxWidth: _trayFlyoutWidth(ids.length),
            child: services.buildSystemTray(
              context,
              horizontal: true,
              wrap: true,
              itemIds: ids,
            ),
          ),
        );
  }
}

/// Side of one tray icon, as the host renders it.
///
/// `SystemTrayModule` puts every icon in a `SizedBox.square(dimension: 22)`,
/// whatever the bar's thickness is, and its `Wrap` keeps 8 between them — so
/// these two numbers describe the flyout's content, not this plugin's taste.
const double _trayIconExtent = 22;
const double _trayIconGap = 8;

/// Padding between the flyout's edge and the icon grid.
///
/// Tighter than `NeoPopupSurface`'s panel default, which is sized for a card
/// with a header and rows of text.
const double _trayFlyoutPadding = 10;

/// How many icons share a row before the grid wraps.
const int _trayFlyoutColumns = 4;

/// The width of the tray flyout for [count] icons.
///
/// The card is placed with a *fixed* width, so it has to be the grid's own width
/// — a generous `maxWidth` is what left four icons floating in a 360px card. The
/// host's `Wrap` takes over past [_trayFlyoutColumns].
double _trayFlyoutWidth(int count) {
  final columns = count.clamp(1, _trayFlyoutColumns);
  return _trayFlyoutPadding * 2 +
      columns * _trayIconExtent +
      (columns - 1) * _trayIconGap;
}

/// The chevron that opens the collapsed icons.
///
/// A downward arrow rather than the `+N` it used to print, because the flyout it
/// opens hangs *below* the pill: the arrow says where the rest of the icons are,
/// and how many there are is in the tooltip and in the label a screen reader
/// reads. Windows' tray overflow is the same idea, down to the bare glyph: no
/// chip behind it, because the icons beside it have none either — the host draws
/// them as plain 22px squares — and a filled tile among them reads as another
/// status icon rather than as the way to the rest.
class _TrayOverflow extends StatelessWidget {
  const _TrayOverflow({required this.label, required this.onPressed});

  final String label;

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
              // The same box the host gives each icon, so the chevron sits on the
              // same rhythm as its neighbours and has the same tap target; the
              // glyph inside is smaller, which is what makes it read as an arrow
              // and not as one more 22px icon.
              child: SizedBox.square(
                dimension: _trayIconExtent,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: theme.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
