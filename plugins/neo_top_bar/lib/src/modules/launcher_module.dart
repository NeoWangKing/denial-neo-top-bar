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
///
/// The host's order is z-order, so it changes on every activation. The row is
/// therefore drawn in the order windows were *first seen* in, not in the order
/// the host reports them — see `core/window_order.dart` for why.
library;

import 'dart:io';

import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/bar_budget.dart';
import '../core/launcher_options.dart';
import '../core/l10n_context.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../core/window_order.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_file_browser.dart';
import '../widgets/neo_setting_controls.dart';
import 'launcher_system_icon.dart';

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
///
/// The cut is taken from the *stable* order, so the same ten icons stay visible
/// and a window opened later is counted in `+N` until one of those ten closes.
/// That is the price of not moving icons around; the alternative — rotating the
/// visible set — would shuffle the row on every open and close.
const int kMaxWindowIcons = 10;

/// How many window tiles a **vertical** pill stacks.
///
/// The bar is a column there, so every extra tile makes one pill taller instead
/// of wider. Ten would be taller than most screens; five keeps the mark and its
/// workspace readable at a glance, and what did not fit is still counted in `+N`
/// (the mark itself opens the full list).
const int kMaxWindowIconsVertical = 5;

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

class LauncherModule implements NeoModule, NeoModuleSettings {
  const LauncherModule();

  @override
  NeoModuleDescriptor get descriptor => launcherModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _LauncherContent(module: module);

  @override
  Widget buildSettings(BuildContext context, NeoModuleSettingsScope scope) =>
      _LauncherSettings(scope: scope);
}

class _LauncherContent extends ConsumerStatefulWidget {
  const _LauncherContent({required this.module});

  final NeoModuleContext module;

  @override
  ConsumerState<_LauncherContent> createState() => _LauncherContentState();
}

class _LauncherContentState extends ConsumerState<_LauncherContent> {
  /// The order window icons were first seen in, so they never move on a click.
  ///
  /// Held in state rather than derived, because "first seen" is by definition
  /// information the current frame does not carry. See `core/window_order.dart`.
  List<int> _order = const <int>[];

  @override
  Widget build(BuildContext context) {
    final s = context.neoStrings;
    final module = widget.module;
    final services = module.services;
    final windows = ref.watch(services.windows(module.monitorId));
    final theme = ShellTheme.of(context);
    final logo = ref.watch(neoSystemLogoProvider);
    final options = neoLauncherOptions(
      module.options,
      systemIconAvailable: logo.available,
    );

    // Recomputed on every build and written without `setState`: the value is
    // used by this very build, so there is nothing to schedule. Dropping the
    // windows that closed also bounds the memory.
    _order = neoStableWindowOrder(
      current: <int>[for (final window in windows) window.id],
      previous: _order,
    );
    final byId = <int, ApplicationWindow>{
      for (final window in windows) window.id: window,
    };
    // Every id in `_order` is present by construction, but a lookup keeps this
    // total rather than relying on that.
    final ordered = <ApplicationWindow>[for (final id in _order) ?byId[id]];

    // The window list is the pill's second half, and the setting that turns it
    // off is about the *bar*, not about the data: the provider stays subscribed
    // either way so switching it back on is immediate.
    // Over budget the strip is what goes: the mark alone still opens the
    // launcher, and the window strip is the widest optional part of any pill.
    final listed =
        options.showWindows &&
            module.concession < NeoConcession.launcherStrip
        ? ordered
        : const <ApplicationWindow>[];
    // A vertical pill has room for a handful of stacked icons, not ten: the bar
    // is a column there, and ten 20px tiles would make one pill taller than the
    // screen. The rest are still reachable by clicking the mark itself.
    final limit = module.horizontal ? kMaxWindowIcons : kMaxWindowIconsVertical;
    final shown = listed.length > limit ? listed.sublist(0, limit) : listed;
    final hidden = listed.length - shown.length;

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: !options.showWindows
          ? s.launcherOpen
          : (listed.isEmpty
                ? s.launcherOpen
                : s.launcherOpenWithCount(listed.length)),
      onPressed: services.toggleLauncher,
      padding: EdgeInsets.symmetric(
        // A vertical pill is only as wide as the strip; see `neoCardPadding`.
        horizontal: (module.horizontal ? 10 : 6) * module.density,
        vertical: module.horizontal ? 0 : 10 * module.density,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Sized from the pill's height — that is, from the thickness the user
          // set in Denial's settings — rather than from this plugin's spacing
          // scale or from a fixed pixel value. One helper shared with every other
          // module, so a bar's glyphs all grow together.
          final logoSize = module.glyphSize(
            _logoFraction,
            min: _minIcon,
            max: _maxIcon,
          );
          final windowSize = module.glyphSize(
            _windowFraction,
            min: _minIcon,
            max: _maxIcon,
          );
          final gap = 5 * module.density;
          final separation = 8 * module.density;

          return Flex(
            // A vertical bar stacks the mark and the window tiles instead of
            // laying them out along a row: the pill is only as wide as the strip,
            // so a row of tiles would run off the bar. The separator turns with
            // them, which is what `_Separator.horizontal` is for.
            direction: module.horizontal ? Axis.horizontal : Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: NeoLauncherMark(
                  art: neoLauncherArt(
                    options: options,
                    systemLogoPath: logo.path,
                    bundledAsset: kLauncherLogoAsset,
                  ),
                  size: logoSize,
                  color: theme.colors.textPrimary,
                ),
              ),
              if (shown.isNotEmpty) ...[
                SizedBox(
                  width: module.horizontal ? separation : 0,
                  height: module.horizontal ? 0 : separation,
                ),
                _Separator(
                  horizontal: module.horizontal,
                  extent: windowSize,
                  color: theme.colors.hairline,
                ),
                SizedBox(
                  width: module.horizontal ? separation : 0,
                  height: module.horizontal ? 0 : separation,
                ),
                for (var index = 0; index < shown.length; index++) ...[
                  if (index > 0)
                    SizedBox(
                      width: module.horizontal ? gap : 0,
                      height: module.horizontal ? 0 : gap,
                    ),
                  _WindowIcon(
                    window: shown[index],
                    services: services,
                    size: windowSize,
                  ),
                ],
                if (hidden > 0) ...[
                  SizedBox(
                    width: module.horizontal ? gap : 0,
                    height: module.horizontal ? 0 : gap,
                  ),
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

/// The launcher's mark, drawn from whichever source the settings chose.
///
/// One widget for all four cases — a glyph, the bundled asset, a distribution
/// file, or the user's own image — because the pill should not care where the
/// picture came from, and because a file that disappears has to degrade to the
/// glyph rather than to nothing.
class NeoLauncherMark extends StatelessWidget {
  const NeoLauncherMark({
    required this.art,
    required this.size,
    required this.color,
    super.key,
  });

  final NeoLauncherArt art;
  final double size;

  /// Tint for the monochrome sources. A user's own image is never recoloured:
  /// they picked it for how it looks.
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (art.kind) {
      case NeoLauncherArtKind.glyph:
        return Icon(Icons.apps, size: size, color: color);
      case NeoLauncherArtKind.asset:
        return SvgPicture.asset(
          art.value,
          package: _assetPackage,
          width: size,
          height: size,
          // Retains the logo's proportions, as the trademark policy asks.
          fit: BoxFit.contain,
          // Monochrome tint: the asset keeps its official `#1793d1` fill on disk
          // and is recoloured only while painting. `srcIn` keeps the glyph's
          // alpha, so the ™ mark is still drawn.
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case NeoLauncherArtKind.file:
        final file = File(art.value);
        if (!file.existsSync()) {
          // The file the setting points at is gone: the glyph is the one mark
          // that is always there.
          return Icon(Icons.apps, size: size, color: color);
        }
        if (art.value.toLowerCase().endsWith('.svg')) {
          return SvgPicture.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          );
        }
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) =>
              Icon(Icons.apps, size: size, color: color),
        );
    }
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

/// The launcher's own settings: which mark it carries, and whether the pill also
/// lists the current workspace's windows.
class _LauncherSettings extends ConsumerStatefulWidget {
  const _LauncherSettings({required this.scope});

  final NeoModuleSettingsScope scope;

  @override
  ConsumerState<_LauncherSettings> createState() => _LauncherSettingsState();
}

class _LauncherSettingsState extends ConsumerState<_LauncherSettings> {
  bool _browsing = false;

  @override
  Widget build(BuildContext context) {
    final s = context.neoStrings;
    final scope = widget.scope;
    final logo = ref.watch(neoSystemLogoProvider);
    final options = neoLauncherOptions(
      scope.options,
      systemIconAvailable: logo.available,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoSettingGroup(
          title: s.launcherIcon,
          children: [
            NeoSettingRow(
              label: s.launcherIconQuestion,
              description: s.launcherIconDescription(options.effectiveIcon),
              // Four chips need the row's whole width once the card is a popup.
              fit: NeoSettingRowFit.under,
              child: NeoSettingChips<NeoLauncherIcon>(
                values: <NeoLauncherIcon, String>{
                  for (final icon in neoLauncherIconOrder)
                    icon: s.launcherIconLabel(icon),
                },
                selected: options.icon,
                enabled: neoLauncherIconSelectable,
                onSelected: (icon) {
                  scope.setOption(neoLauncherIconKey, icon.name);
                  // A custom icon without a file would draw the grid; open the
                  // browser straight away so choosing it means choosing a file.
                  if (icon == NeoLauncherIcon.custom &&
                      options.customPath.isEmpty) {
                    setState(() => _browsing = true);
                  } else {
                    setState(() => _browsing = false);
                  }
                },
              ),
            ),
            if (options.icon == NeoLauncherIcon.system)
              _SettingsNote(
                text: switch (logo.path) {
                  final path? => s.launcherUsingPath(path),
                  _ => s.launcherNoDistroLogo,
                },
              ),
            if (options.icon == NeoLauncherIcon.custom) ...[
              NeoImagePathField(
                path: options.customPath,
                browsing: _browsing,
                onBrowse: () => setState(() => _browsing = !_browsing),
                onChanged: (path) {
                  scope.setOption(neoLauncherCustomPathKey, path);
                  if (path != null) setState(() => _browsing = false);
                },
              ),
              if (_browsing) ...[
                const SizedBox(height: 8),
                NeoFileBrowser(
                  onSelected: (path) {
                    scope.setOption(neoLauncherCustomPathKey, path);
                    setState(() => _browsing = false);
                  },
                ),
              ],
            ],
            if (options.fellBack)
              _SettingsNote(text: s.launcherFallbackActive, warning: true),
            // Why the Denial chip is greyed out. It belongs to the icon group —
            // it explains a choice in the row above — rather than to the end of
            // the card, where it read as a remark about the window list.
            _SettingsNote(text: s.launcherDenialUnavailable),
          ],
        ),
        const SizedBox(height: 14),
        NeoSettingGroup(
          title: s.launcherWindowsSection,
          children: [
            NeoSettingRow(
              label: s.launcherShowWorkspaceWindows,
              description: s.launcherShowWorkspaceWindowsHint,
              child: NeoSettingToggle(
                value: options.showWindows,
                onChanged: (value) =>
                    scope.setOption(neoLauncherWindowsKey, value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A muted line under a group: what a choice resolved to, or why it cannot be
/// used. Not a setting row — there is nothing to press.
class _SettingsNote extends StatelessWidget {
  const _SettingsNote({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: theme.text.systemBarCaption.copyWith(
          fontSize: 11.5,
          color: warning
              ? theme.colors.performanceWarning
              : theme.colors.textTertiary,
        ),
      ),
    );
  }
}
