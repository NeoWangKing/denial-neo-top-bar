/// NeoTopBar: a customizable Denial top bar.
///
/// This library is the plugin's contribution entry point. The bar reserves its
/// strip through the exclusive [ShellWorkArea] contract, so it must not be
/// enabled together with another panel that reserves native space.
///
/// Placement and native reservation both derive from Denial's own system-bar
/// settings (edge, thickness, output selection). Keeping the two in one function
/// is what stops the painted strip and the reserved work area from drifting
/// apart, which would either leave a gap or let windows slide under the bar.
@Plugin()
library;

import 'package:denial_sdk/composition.dart';
import 'package:denial_flutter_sdk/actions.dart';
import 'package:denial_flutter_sdk/surfaces.dart';
import 'package:flutter/widgets.dart';

import 'src/core/l10n_context.dart';
import 'src/core/settings_requests.dart';
import 'src/widgets/neo_bar.dart';

export 'src/core/config.dart'
    show
        NeoDensity,
        NeoModulePlacement,
        NeoModuleInstancePreference,
        NeoTopBarConfig,
        resolvePlacements;
export 'src/core/module_defaults.dart'
    show NeoModuleIds, neoTopBarDefaultModules;
export 'src/core/module_registry.dart' show NeoTopBarModules;
export 'src/widgets/neo_bar.dart'
    show NeoTopBar, NeoTopBarPreferencesStoreHolder;

/// Opens the component settings card from a keyboard shortcut.
///
/// The bar also answers a right-click on empty strip space, but that is easy to
/// miss and deliberately does nothing over a pill — the status tray needs the
/// secondary button for its own context menus. This action is the dependable way
/// in: bind it under Settings → Shortcuts → Denial actions.
@Provides(ShellAction)
final class OpenNeoTopBarSettingsAction implements ShellAction {
  const OpenNeoTopBarSettingsAction();

  /// Stable, package-qualified id. Saved shortcut bindings store this string.
  static const String actionId = 'neo_top_bar.openSettings';

  @override
  String get id => actionId;

  @override
  String get provider => 'Neo Top Bar';

  @override
  String label(BuildContext context) => context.neoStrings.settingsTitle;

  @override
  String description(BuildContext context) =>
      context.neoStrings.settingsTooltip;

  @override
  void invoke(ShellActionContext context) {
    // A handler gets no BuildContext, so the mounted bar opens the card.
    NeoSettingsRequests.instance.request();
  }
}

/// Used only when the configured thickness is missing or non-positive.
///
/// Denial's own default is 33. A zero or negative value would make
/// `ShellSurfacePlacement.edgeBounds` and `ShellWorkAreaReservation` throw, so
/// both paths go through [neoTopBarStripThickness] instead of trusting the
/// setting blindly.
const double neoTopBarFallbackThickness = 33;

/// The strip thickness to use for [settings], sanitized.
///
/// Placement and reservation must both call this so they can never disagree.
double neoTopBarStripThickness(ShellLayoutSettings settings) {
  final thickness = settings.systemBarThickness;
  if (!thickness.isFinite || thickness <= 0) return neoTopBarFallbackThickness;
  return thickness;
}

/// The edge the bar is configured to sit on, or [PanelEdge.hidden].
PanelEdge neoTopBarConfiguredSide(ShellLayoutSettings settings) =>
    settings.systemBarSide ?? PanelEdge.top;

@Provides(ShellSurface)
final class NeoTopBarSurface implements ShellSurface {
  const NeoTopBarSurface();

  @override
  String get id => 'neo_top_bar.panel';

  @override
  ShellSurfaceLayer get layer => ShellSurfaceLayer.desktopControls;

  @override
  ShellSurfacePlacement? place(ShellSurfaceEnvironment environment) {
    final layout = environment.settings.layout;
    final side = neoTopBarConfiguredSide(layout);
    if (side == PanelEdge.hidden) return null;
    if (!environment.outputSelected(layout.systemBarOutputNames)) return null;
    return ShellSurfacePlacement(
      bounds: ShellSurfacePlacement.edgeBounds(
        environment.output.logicalRect,
        side,
        neoTopBarStripThickness(layout),
      ),
      // A locked session or the wallpaper selector owns the screen; fullscreen
      // only covers the bar while the user is not asking for the desktop.
      visible:
          !environment.locked &&
          !environment.wallpaperSelectorVisible &&
          (!environment.fullscreen ||
              environment.overview ||
              environment.desktopVisible),
    );
  }

  @override
  Widget build(BuildContext context, {required ShellSurfaceContext surface}) =>
      NeoTopBar(
        monitorId: surface.environment.output.monitorId,
        side: neoTopBarConfiguredSide(surface.environment.settings.layout),
        services: surface.services,
      );
}

@Provides(ShellWorkArea)
final class NeoTopBarWorkArea implements ShellWorkArea {
  const NeoTopBarWorkArea();

  @override
  ShellWorkAreaReservation? reserve(ShellLayoutSettings settings) {
    final side = neoTopBarConfiguredSide(settings);
    if (side == PanelEdge.hidden) return null;
    return ShellWorkAreaReservation(
      edge: side,
      thickness: neoTopBarStripThickness(settings) + settings.maximizePadding,
      outputNames: settings.systemBarOutputNames,
    );
  }
}
