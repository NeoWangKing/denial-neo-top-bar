/// Application launcher pill.
///
/// Denial owns the launcher surface and its search, filtering and keyboard
/// navigation. The bar only supplies the entry point, so this module is a thin
/// wrapper over the host's own toggle.
library;

import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
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

class _LauncherContent extends StatelessWidget {
  const _LauncherContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context) {
    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: '打开应用启动器',
      onPressed: module.services.toggleLauncher,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * module.density,
        vertical: module.horizontal ? 0 : 12 * module.density,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The card stretches to the strip's thickness, which the user sets in
          // Denial's own settings, so the mark is sized from the available cross
          // extent rather than a fixed pixel value.
          final cross = module.horizontal
              ? constraints.maxHeight
              : constraints.maxWidth;
          final available = cross.isFinite && cross > 0 ? cross : 22.0;
          final size = (available * 0.62).clamp(14.0, 30.0);
          return Center(
            child: SvgPicture.asset(
              kLauncherLogoAsset,
              package: _assetPackage,
              width: size,
              height: size,
              // Retains the logo's proportions, as the trademark policy asks.
              fit: BoxFit.contain,
              // Monochrome tint: the asset keeps its official `#1793d1` fill on
              // disk and is recoloured only while painting. `srcIn` keeps the
              // glyph's alpha, so the ™ mark is still drawn.
              colorFilter: ColorFilter.mode(
                ShellTheme.of(context).colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          );
        },
      ),
    );
  }
}
