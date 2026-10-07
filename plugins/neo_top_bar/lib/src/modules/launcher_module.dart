/// Application launcher pill, listing the current output's windows.
///
/// Denial owns the launcher surface and its search, filtering and keyboard
/// navigation; this module only supplies the entry point. To its right it shows
/// one icon per window, which is what makes the pill a useful "what is open
/// here" readout as well as a launcher button.
///
/// The window list comes from `ShellWindowServices.windows(monitorId)`. That is
/// the documented plugin API and it is already scoped to the output's **current
/// workspace**: the host builds it from
/// `window.workspaceId == activeWorkspaceFor(monitorId)`, also including
/// minimized and always-visible (pinned) windows. A plugin therefore does not
/// need a workspace field on the window model to answer "what is on this
/// workspace" — the host already answered it.
library;

import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_card.dart';

/// The distribution mark shown in the launcher pill.
///
/// `assets/archlinux-logo.svg` is the unmodified official Arch Linux logo from
/// the `archlinux-logo` package (`/usr/share/pixmaps/archlinux-logo.svg`), kept
/// byte-identical to the shipped file (sha256 in the README). The white
/// appearance comes from a paint-time [ColorFilter], not from editing the asset.
///
/// Arch's trademark policy (section 4) asks that the ™ stay intact and that
/// scaling keep the original proportions, and explicitly suggests a monochrome
/// version for colourful or busy backdrops. A bar over a wallpaper is exactly
/// that case, so the tint is the sanctioned form: the ™ path is still painted,
/// and `BoxFit.contain` keeps the logo's aspect ratio.
const String kLauncherLogoAsset = 'assets/archlinux-logo.svg';

/// Above this many windows the rest collapse into a `+N` counter.
///
/// A pill wider than the strip would either clip or cover the whole bar, and the
/// counter is more useful than a scroller nobody can reach.
const int kMaxWindowIcons = 10;

/// Icon size as a fraction of the strip's cross extent, clamped to sane pixels.
const double _logoFraction = 0.62;
const double _windowFraction = 0.54;
const double _minIcon = 14;
const double _maxIcon = 30;

/// This plugin's own package name.
///
/// A plugin is a dependency of the generated shell application, so Flutter
/// bundles its declared assets under the `packages/<name>/` prefix and a plain
/// `assets/...` lookup finds nothing at runtime. Verified against a built
/// bundle's `AssetManifest.bin`, which registers only
/// `packages/neo_top_bar/assets/archlinux-logo.svg`.
///
/// There are two equivalent ways to reach it: pass this as `package:` (the
/// documented flutter_svg/`Image.asset` form, used here), or write the prefixed
/// key as a literal string. Denial's own code uses the literal form, e.g.
/// `'packages/denial_flutter_sdk/assets/branding/denial-dark.svg'`.
const String _assetPackage = 'neo_top_bar';

class LauncherModule implements NeoModule {
  const LauncherModule();

  @override
  NeoModuleDescriptor get descriptor => launcherModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _LauncherContent(module: module);
}

class _LauncherContent extends ConsumerWidget {
  const _LauncherContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = module.services;
    final windows = ref.watch(services.windows(module.monitorId));
    final theme = ShellTheme.of(context);
    final gap = 5 * module.density;

    final shown = windows.length > kMaxWindowIcons
        ? windows.sublist(0, kMaxWindowIcons)
        : windows;
    final hidden = windows.length - shown.length;

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: windows.isEmpty
          ? '打开应用启动器'
          : '打开应用启动器 · 当前工作区 ${windows.length} 个窗口',
      onPressed: services.toggleLauncher,
      padding: EdgeInsets.symmetric(
        horizontal: 10 * module.density,
        vertical: module.horizontal ? 0 : 10 * module.density,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Sized from the strip's cross extent, which the user sets in Denial's
          // settings, rather than from a fixed pixel value.
          final cross = module.horizontal
              ? constraints.maxHeight
              : constraints.maxWidth;
          final available = cross.isFinite && cross > 0 ? cross : 22.0;
          double iconSize(double fraction) =>
              (available * fraction).clamp(_minIcon, _maxIcon);
          final logoSize = iconSize(_logoFraction);
          final windowSize = iconSize(_windowFraction);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SvgPicture.asset(
                  kLauncherLogoAsset,
                  package: _assetPackage,
                  width: logoSize,
                  height: logoSize,
                  // Retains the logo's proportions, as the trademark policy asks.
                  fit: BoxFit.contain,
                  // Monochrome tint: the asset keeps its official `#1793d1` fill
                  // on disk and is recoloured only while painting. `srcIn` keeps
                  // the glyph's alpha, so the ™ mark is still drawn.
                  colorFilter: ColorFilter.mode(
                    theme.colors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              if (shown.isNotEmpty) ...[
                SizedBox(width: 8 * module.density),
                _Separator(
                  horizontal: module.horizontal,
                  extent: windowSize,
                  color: theme.colors.hairline,
                ),
                SizedBox(width: 8 * module.density),
                for (var index = 0; index < shown.length; index++) ...[
                  if (index > 0) SizedBox(width: gap),
                  _WindowIcon(
                    window: shown[index],
                    services: services,
                    size: windowSize,
                  ),
                ],
                if (hidden > 0) ...[
                  SizedBox(width: gap),
                  Text(
                    '+$hidden',
                    style: ShellText.systemBarCaption.copyWith(
                      color: module.accent.captionColor(theme),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A hairline between the launcher mark and the window list, so the pill reads
/// as "button | windows" instead of one run of icons.
class _Separator extends StatelessWidget {
  const _Separator({
    required this.horizontal,
    required this.extent,
    required this.color,
  });

  final bool horizontal;
  final double extent;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: horizontal ? 1 : extent,
      height: horizontal ? extent : 1,
      child: ColoredBox(color: color),
    ),
  );
}

/// One window, activated by clicking it.
///
/// This sits inside the pill's own tap target; the deeper gesture wins the
/// arena, so clicking an icon focuses that window and clicking anywhere else in
/// the pill opens the launcher.
class _WindowIcon extends StatelessWidget {
  const _WindowIcon({
    required this.window,
    required this.services,
    required this.size,
  });

  final ApplicationWindow window;
  final ShellServices services;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    void activate() => services.activateWindow(window.id);
    return Tooltip(
      message: window.title,
      child: Semantics(
        button: true,
        label: window.title,
        onTap: activate,
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: activate,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // The focused window gets an accent plate; a minimized one is
                  // dimmed so the pill also reports what is hidden.
                  color: window.active
                      ? theme.accent.withValues(alpha: 0.30)
                      : Colors.transparent,
                  borderRadius: theme.borderRadius(size),
                ),
                child: Padding(
                  padding: EdgeInsets.all(size * 0.10),
                  child: Opacity(
                    opacity: window.minimized ? 0.55 : 1,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: services.buildApplicationIcon(
                        context,
                        window.appId,
                      ),
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
