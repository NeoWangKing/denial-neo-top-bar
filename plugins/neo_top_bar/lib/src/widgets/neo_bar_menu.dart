/// The bar's two pointer-owned popups: its right-click menu, and the settings card
/// for one pill.
///
/// Both are created through Denial's popup host — dismissal, focus and input
/// lifetime stay the shell's business — and both appear at the click position
/// rather than under a widget, because that is where the user was looking.
///
/// Which one opens is decided by the *gesture arena*, not by hit testing here. A
/// pill is wrapped in a gesture recogniser, and a tray icon or a control-centre
/// glyph inside it is a deeper one, so the innermost recogniser that accepts the
/// secondary button wins. That is what keeps "right-click a pill" and
/// "right-click the Wi-Fi glyph inside it" from both firing.
library;

import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/config_state.dart';
import '../core/l10n_context.dart';
import '../core/module_registry.dart';
import '../core/settings_requests.dart';
import 'module_settings_panel.dart';
import 'neo_popup_surface.dart';

/// One row of the bar's right-click menu.
class NeoBarMenuAction {
  const NeoBarMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;

  /// Runs after the menu has been asked to close.
  final VoidCallback onSelected;
}

/// Opens the bar's right-click menu at [position].
///
/// The settings entry is added by this function rather than by [actions], so it
/// is always the last row as bar-wide actions are added above it: the bottom of a
/// context menu is where a settings entry is looked for.
void openNeoBarMenu({
  required BuildContext context,
  required ShellServices services,
  required int monitorId,
  required Offset position,
  List<NeoBarMenuAction> actions = const <NeoBarMenuAction>[],
}) {
  final ref = ProviderScope.containerOf(context, listen: false);
  ref
      .read(shellPopupControllerProvider.notifier)
      .show(
        keyName: 'neo_top_bar.menu',
        debugLabel: 'NeoTopBar menu',
        dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
        // No dimming scrim, exactly like the settings card: the bar stays
        // readable while the menu is open, and outside-tap still dismisses it
        // through the transparent barrier.
        barrierColor: Colors.transparent,
        // The card animates itself; see `neoPopupHostTransition`.
        transitionDuration: neoPopupHostTransition,
        builder: (context, handle) {
          final s = context.neoStrings;
          return _NeoPointerMenu(
            services: services,
            monitorId: monitorId,
            position: position,
            actions: actions,
            settings: NeoBarMenuAction(
              label: s.settingsTitle,
              icon: Icons.tune,
              // The card is a popup of its own, and the bar owns it: this menu
              // closes and *asks* for it, the same way the control centre's
              // pencil does. Opening it from here would race the popup host.
              onSelected: () {
                handle.close();
                NeoSettingsRequests.instance.request();
              },
            ),
          );
        },
      );
}

/// Opens the settings card for one pill instance at [position].
void openNeoPillSettings({
  required BuildContext context,
  required NeoTopBarConfigState state,
  required ShellServices services,
  required int monitorId,
  required String instanceId,
  required Offset position,
}) {
  final ref = ProviderScope.containerOf(context, listen: false);
  ref
      .read(shellPopupControllerProvider.notifier)
      .show(
        keyName: 'neo_top_bar.pill_settings.$instanceId',
        debugLabel: 'NeoTopBar pill settings',
        dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
        barrierColor: Colors.transparent,
        // The card animates itself; see `neoPopupHostTransition`.
        transitionDuration: neoPopupHostTransition,
        builder: (context, handle) => _NeoPillSettingsCard(
          state: state,
          services: services,
          monitorId: monitorId,
          instanceId: instanceId,
          position: position,
          onClose: handle.close,
        ),
      );
}

/// The menu: the bar-wide actions, then a divider, then settings.
class _NeoPointerMenu extends StatelessWidget {
  const _NeoPointerMenu({
    required this.services,
    required this.monitorId,
    required this.position,
    required this.actions,
    required this.settings,
  });

  final ShellServices services;
  final int monitorId;
  final Offset position;
  final List<NeoBarMenuAction> actions;
  final NeoBarMenuAction settings;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final s = context.neoStrings;
    return NeoPopupSurface(
      services: services,
      monitorId: monitorId,
      position: position,
      maxWidth: 240,
      maxHeight: 420,
      // A menu wants its rows to reach the card's edges; the panel padding would
      // put a gutter around every hover highlight.
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
            child: Text(
              s.appearanceSettingsTitle,
              style: theme.text.systemBarCaption.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
          ),
          for (final action in actions) _NeoMenuRow(action: action),
          if (actions.isNotEmpty) const _NeoMenuDivider(),
          _NeoMenuRow(action: settings),
        ],
      ),
    );
  }
}

class _NeoMenuRow extends StatefulWidget {
  const _NeoMenuRow({required this.action});

  final NeoBarMenuAction action;

  @override
  State<_NeoMenuRow> createState() => _NeoMenuRowState();
}

class _NeoMenuRowState extends State<_NeoMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.action.onSelected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? theme.colors.chip : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.chipRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  widget.action.icon,
                  size: 16,
                  color: theme.colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.action.label,
                    style: theme.text.systemBarValue.copyWith(fontSize: 13),
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

class _NeoMenuDivider extends StatelessWidget {
  const _NeoMenuDivider();

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: theme.colors.hairlineSoft),
      ),
    );
  }
}

/// One pill's settings, at the pointer.
///
/// Rebuilds on the config state for the same reason the board does: a setting can
/// reveal or hide the row under it — the clock's date format only exists while the
/// date does — so a card built once would keep a stale shape.
class _NeoPillSettingsCard extends StatelessWidget {
  const _NeoPillSettingsCard({
    required this.state,
    required this.services,
    required this.monitorId,
    required this.instanceId,
    required this.position,
    required this.onClose,
  });

  final NeoTopBarConfigState state;
  final ShellServices services;
  final int monitorId;
  final String instanceId;
  final Offset position;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final s = context.neoStrings;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        // Resolved the way the bar resolves it, so the card shows *this*
        // instance's settings and keeps working while other settings change.
        NeoModulePlacement? placement;
        for (final candidate in resolvePlacements(
          descriptors: NeoTopBarModules.descriptors,
          config: state.config,
        )) {
          if (candidate.id == instanceId) placement = candidate;
        }
        final title = placement == null
            ? s.appearanceSettingsTitle
            : s.moduleLabel(placement.descriptor.id);
        return NeoPopupSurface(
          services: services,
          monitorId: monitorId,
          position: position,
          // Wide enough for four chips to stay on one line and for a row's label
          // to keep a real column, and no wider: this is a card beside the
          // pointer, not a panel.
          maxWidth: 420,
          maxHeight: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.text.systemBarValue.copyWith(fontSize: 16),
                    ),
                  ),
                  NeoPopupIconButton(
                    icon: Icons.close,
                    tooltip: s.close,
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: placement == null
                      // The pill left the bar while this card was open — removed
                      // by the board, or by another bar instance. Saying so beats
                      // an empty card.
                      ? Text(
                          s.pillGone,
                          style: theme.text.systemBarCaption.copyWith(
                            color: theme.colors.textTertiary,
                          ),
                        )
                      : NeoExpandedModuleSettings(
                          placement: placement,
                          state: state,
                          services: services,
                          monitorId: monitorId,
                          // The header above names the module, and this card is
                          // its own surface rather than a well in the board.
                          showTitle: false,
                          inset: false,
                        ),
                ),
              ),
              const SizedBox(height: 4),
              const _NeoMenuDivider(),
              _NeoMenuRow(
                action: NeoBarMenuAction(
                  label: s.allModuleSettings,
                  icon: Icons.tune,
                  onSelected: () {
                    onClose();
                    NeoSettingsRequests.instance.request();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
