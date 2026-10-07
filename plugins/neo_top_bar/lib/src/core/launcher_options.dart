/// Pure logic behind the launcher module's settings.
///
/// Three things are decided here rather than in the widget tree, because each is
/// a rule with an edge that is easy to get wrong:
///
/// - **which icon is drawn.** The user picks one of four sources; a choice can be
///   unusable (a custom icon whose file was deleted, a system icon on a
///   distribution with no logo installed), and what is drawn then has to be
///   decided somewhere that can be tested.
/// - **which system logo that is.** Finding it means reading `/etc/os-release`
///   and looking in the places distributions put their marks; the parsing and the
///   candidate order are pure, only the file existence checks are not.
/// - **what the custom-icon browser lists.** Directory entries arrive in whatever
///   order the filesystem returns them, and a picker that reshuffles is unusable.
///
/// Kept free of Flutter and of `dart:io` so it is unit-testable — see
/// `neo_top_bar_logic.dart`.
library;

/// Where the launcher pill's mark comes from.
enum NeoLauncherIcon {
  /// A plain application-grid glyph. Always available, so it is the fallback for
  /// every other choice.
  grid,

  /// The distribution's own mark.
  system,

  /// An image the user picked.
  custom,

  /// Denial's own mark, once it has one.
  denial,
}

/// The order the settings offer them in.
const List<NeoLauncherIcon> neoLauncherIconOrder = <NeoLauncherIcon>[
  NeoLauncherIcon.grid,
  NeoLauncherIcon.system,
  NeoLauncherIcon.custom,
  NeoLauncherIcon.denial,
];

String neoLauncherIconLabel(NeoLauncherIcon icon) => switch (icon) {
  NeoLauncherIcon.grid => '默认',
  NeoLauncherIcon.system => '系统',
  NeoLauncherIcon.custom => '自定义',
  NeoLauncherIcon.denial => 'Denial',
};

String neoLauncherIconDescription(NeoLauncherIcon icon) => switch (icon) {
  NeoLauncherIcon.grid => '九宫格图标，任何机器上都能用',
  NeoLauncherIcon.system => '按发行版选图标，找不到就用默认',
  NeoLauncherIcon.custom => '自己选一张图片（SVG / PNG / JPEG / WebP / GIF）',
  NeoLauncherIcon.denial => '等 Denial 官方图标，暂时不能用',
};

/// Whether the settings let [icon] be picked.
///
/// Only [NeoLauncherIcon.denial] is not: it is listed so the option is visibly
/// coming, and disabled so it cannot be selected into a state that draws nothing
/// special.
bool neoLauncherIconSelectable(NeoLauncherIcon icon) =>
    icon != NeoLauncherIcon.denial;

/// The option key holding the chosen [NeoLauncherIcon].
const String neoLauncherIconKey = 'icon';

/// The option key holding whether the workspace's windows are listed.
const String neoLauncherWindowsKey = 'showWindows';

/// The option key holding the custom icon's absolute path.
const String neoLauncherCustomPathKey = 'customPath';

/// The launcher's stored settings, resolved against their defaults.
class NeoLauncherOptions {
  const NeoLauncherOptions({
    required this.icon,
    required this.showWindows,
    required this.customPath,
    required this.effectiveIcon,
  });

  /// The choice as stored, which may not be drawable.
  final NeoLauncherIcon icon;

  /// Whether the current workspace's application icons are shown.
  final bool showWindows;

  /// The custom icon's path; empty when none was chosen.
  final String customPath;

  /// The choice that can actually be drawn.
  ///
  /// Differs from [icon] when a choice has nothing behind it: a custom icon with
  /// no path (or one the browser could not read), or a system icon the user
  /// asked for even though no distribution mark was found. Both fall back to the
  /// grid rather than to a blank pill.
  final NeoLauncherIcon effectiveIcon;

  /// Whether the stored choice is being overridden, so the settings can say so.
  bool get fellBack => icon != effectiveIcon && icon != NeoLauncherIcon.grid;

  @override
  String toString() =>
      'NeoLauncherOptions(${icon.name} -> ${effectiveIcon.name}, '
      'showWindows: $showWindows, custom: $customPath)';
}

/// Resolves the stored settings, tolerating anything a hand-edited file holds.
///
/// [systemIconAvailable] comes from the caller and means "something can be drawn
/// for the system choice" — a distribution mark found on this machine, or the mark
/// this plugin bundles, or both. A `system` choice with neither falls back to the
/// grid rather than to an empty pill.
NeoLauncherOptions neoLauncherOptions(
  Map<String, Object?> options, {
  bool systemIconAvailable = false,
}) {
  final stored = options[neoLauncherIconKey];
  var icon = NeoLauncherIcon.grid;
  if (stored is String) {
    for (final candidate in NeoLauncherIcon.values) {
      if (candidate.name == stored) icon = candidate;
    }
  }
  // A stored choice that cannot be selected is treated as never made: the file
  // may have been written by a build that offered more.
  if (!neoLauncherIconSelectable(icon)) icon = NeoLauncherIcon.grid;

  final rawPath = options[neoLauncherCustomPathKey];
  final customPath = rawPath is String ? rawPath.trim() : '';

  final showWindows = switch (options[neoLauncherWindowsKey]) {
    final bool value => value,
    _ => true,
  };

  final effective = switch (icon) {
    NeoLauncherIcon.custom when customPath.isNotEmpty => icon,
    NeoLauncherIcon.system when systemIconAvailable => icon,
    _ => NeoLauncherIcon.grid,
  };

  return NeoLauncherOptions(
    icon: icon,
    showWindows: showWindows,
    customPath: customPath,
    effectiveIcon: effective,
  );
}

/// What a launcher mark is drawn from.
enum NeoLauncherArtKind {
  /// A glyph from the icon font, named by [NeoLauncherArt.value].
  glyph,

  /// An asset bundled with this plugin.
  asset,

  /// A file on disk, by absolute path.
  file,
}

class NeoLauncherArt {
  const NeoLauncherArt(this.kind, this.value);

  final NeoLauncherArtKind kind;
  final String value;

  @override
  String toString() => 'NeoLauncherArt(${kind.name}, $value)';
}

/// The name the grid glyph is drawn by.
const String neoLauncherGridGlyph = 'apps';

/// The distribution mark this plugin bundles.
///
/// Shipped so the `system` choice has something to draw even on a machine whose
/// distribution package did not install a pixmap.
const String neoLauncherBundledArchAsset = 'assets/archlinux-logo.svg';

/// Distributions whose mark is the Arch one, including the Arch-derived ones.
const Set<String> neoArchFamilyDistroIds = <String>{
  'arch',
  'archarm',
  'archlinux',
  'cachyos',
  'endeavouros',
  'garuda',
  'manjaro',
  'artix',
  'arcolinux',
  'blackarch',
  'rebornos',
  'steamos',
};

/// The art to draw for [options].
///
/// [systemLogoPath] is the distribution mark found on this machine, if any.
/// Everything else falls back to the grid glyph, which is the one mark that is
/// always available.
NeoLauncherArt neoLauncherArt({
  required NeoLauncherOptions options,
  String? systemLogoPath,
  String? bundledAsset,
}) {
  switch (options.effectiveIcon) {
    case NeoLauncherIcon.custom:
      return NeoLauncherArt(NeoLauncherArtKind.file, options.customPath);
    case NeoLauncherIcon.system:
      if (systemLogoPath != null && systemLogoPath.isNotEmpty) {
        return NeoLauncherArt(NeoLauncherArtKind.file, systemLogoPath);
      }
      if (bundledAsset != null && bundledAsset.isNotEmpty) {
        return NeoLauncherArt(NeoLauncherArtKind.asset, bundledAsset);
      }
    case NeoLauncherIcon.grid:
    case NeoLauncherIcon.denial:
      break;
  }
  return const NeoLauncherArt(NeoLauncherArtKind.glyph, neoLauncherGridGlyph);
}

/// The distribution id in an `/etc/os-release` document, lower-cased.
///
/// `ID` wins; `ID_LIKE` is the fallback for a derivative that names its parent
/// (EndeavourOS ships `ID=endeavouros` and `ID_LIKE=arch`, and either is enough
/// to find a mark). Returns null when neither is present, which is also what an
/// unreadable file looks like.
String? neoDistroId(String osRelease) {
  String? id;
  String? idLike;
  for (final line in osRelease.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    final value = _unquote(trimmed.substring(separator + 1).trim());
    if (value.isEmpty) continue;
    if (key == 'ID') {
      id = value;
    } else if (key == 'ID_LIKE' && idLike == null) {
      // A list, most specific first.
      idLike = value.split(RegExp(r'\s+')).first;
    }
  }
  final resolved = id ?? idLike;
  return resolved?.toLowerCase();
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

/// Where a distribution's mark is usually installed, most specific first.
///
/// Both the plain path and the Debian-style `-logo` name are tried, because
/// distributions disagree: Arch ships `/usr/share/pixmaps/archlinux-logo.svg`,
/// while others drop `<id>.svg` next to it.
List<String> neoSystemLogoCandidates(String? distroId) {
  final id = distroId?.toLowerCase();
  final candidates = <String>[];
  if (id != null && id.isNotEmpty) {
    candidates.addAll(<String>[
      '/usr/share/pixmaps/$id-logo.svg',
      '/usr/share/pixmaps/$id.svg',
      '/usr/share/icons/hicolor/scalable/apps/$id-logo.svg',
      '/usr/share/icons/hicolor/scalable/apps/$id.svg',
      '/usr/share/icons/hicolor/256x256/apps/$id-logo.png',
      '/usr/share/icons/hicolor/128x128/apps/$id-logo.png',
    ]);
  }
  if (id != null && neoArchFamilyDistroIds.contains(id)) {
    // Arch's own package installs this name.
    candidates.add('/usr/share/pixmaps/archlinux-logo.svg');
  }
  return List<String>.unmodifiable(candidates);
}

/// File extensions the custom-icon browser offers.
const List<String> neoImageExtensions = <String>[
  'svg',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'bmp',
];

/// Whether [name] looks like an image the launcher can draw.
bool neoIsImageFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return false;
  return neoImageExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// One entry of the custom-icon browser.
class NeoBrowseEntry {
  const NeoBrowseEntry({required this.name, required this.isDirectory});

  final String name;
  final bool isDirectory;

  /// Whether this entry can be chosen as the launcher's mark.
  bool get isImage => !isDirectory && neoIsImageFileName(name);

  @override
  String toString() => 'NeoBrowseEntry($name, dir: $isDirectory)';
}

/// What the browser shows: directories first, then images, each by name.
///
/// Hidden entries are left out — a picker that starts by showing `.cache` and
/// `.local` buries the pictures — and everything that is neither a directory nor
/// an image is dropped, so the list is only things the user can act on.
List<NeoBrowseEntry> neoBrowseEntries(List<NeoBrowseEntry> entries) {
  final visible =
      <NeoBrowseEntry>[
        for (final entry in entries)
          if (!entry.name.startsWith('.') &&
              (entry.isDirectory || entry.isImage))
            entry,
      ]..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  return List<NeoBrowseEntry>.unmodifiable(visible);
}

/// The last segment of [path], for showing a chosen file without its directory.
String neoFileName(String path) {
  var trimmed = path;
  while (trimmed.length > 1 && trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  // The root is its own name: there is nothing after the last separator.
  if (trimmed == '/') return '/';
  final slash = trimmed.lastIndexOf('/');
  return slash < 0 ? trimmed : trimmed.substring(slash + 1);
}

/// The parent of [path], or null at the filesystem root.
///
/// String arithmetic rather than `dart:io`, so the browser's idea of "up" can be
/// tested: `/` has no parent, and a trailing separator is not a level.
String? neoParentDirectory(String path) {
  if (path.isEmpty || path == '/') return null;
  var trimmed = path;
  while (trimmed.length > 1 && trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  final slash = trimmed.lastIndexOf('/');
  if (slash < 0) return null;
  if (slash == 0) return '/';
  return trimmed.substring(0, slash);
}
