/// Tests for the launcher module's settings rules.
///
/// The interesting parts are the fallbacks: a choice the machine cannot draw has
/// to become the grid glyph rather than an empty pill, and finding a
/// distribution's mark depends on parsing a file that every distribution writes
/// slightly differently.
library;

import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

void main() {
  group('neoLauncherOptions', () {
    test('an untouched module shows the grid and the windows', () {
      final options = neoLauncherOptions(const <String, Object?>{});
      expect(options.icon, NeoLauncherIcon.grid);
      expect(options.effectiveIcon, NeoLauncherIcon.grid);
      expect(options.showWindows, isTrue);
      expect(options.customPath, isEmpty);
      expect(options.fellBack, isFalse);
    });

    test('reads a stored choice', () {
      final options = neoLauncherOptions(const <String, Object?>{
        'icon': 'custom',
        'customPath': '/tmp/a.png',
      });
      expect(options.icon, NeoLauncherIcon.custom);
      expect(options.effectiveIcon, NeoLauncherIcon.custom);
      expect(options.customPath, '/tmp/a.png');
    });

    test('a custom icon without a path falls back to the grid', () {
      final options = neoLauncherOptions(const <String, Object?>{
        'icon': 'custom',
        'customPath': '   ',
      });
      expect(options.icon, NeoLauncherIcon.custom);
      expect(options.effectiveIcon, NeoLauncherIcon.grid);
      expect(options.fellBack, isTrue);
    });

    test('a system icon without a distribution mark falls back too', () {
      final options = neoLauncherOptions(const <String, Object?>{
        'icon': 'system',
      });
      expect(options.effectiveIcon, NeoLauncherIcon.grid);
      expect(options.fellBack, isTrue);

      final withMark = neoLauncherOptions(const <String, Object?>{
        'icon': 'system',
      }, systemIconAvailable: true);
      expect(withMark.effectiveIcon, NeoLauncherIcon.system);
      expect(withMark.fellBack, isFalse);
    });

    test('the grid never reports a fallback', () {
      expect(
        neoLauncherOptions(const <String, Object?>{'icon': 'grid'}).fellBack,
        isFalse,
      );
    });

    test('a choice that cannot be picked is ignored', () {
      // `denial` is listed but disabled until the mark exists; a file left by a
      // build that offered more must not draw it.
      final options = neoLauncherOptions(const <String, Object?>{
        'icon': 'denial',
      });
      expect(options.icon, NeoLauncherIcon.grid);
    });

    test('unknown names and wrong types fall back, not throw', () {
      expect(
        neoLauncherOptions(const <String, Object?>{'icon': 'triangle'}).icon,
        NeoLauncherIcon.grid,
      );
      expect(
        neoLauncherOptions(const <String, Object?>{'icon': 7}).icon,
        NeoLauncherIcon.grid,
      );
      expect(
        neoLauncherOptions(const <String, Object?>{'customPath': 7}).customPath,
        isEmpty,
      );
      expect(
        neoLauncherOptions(const <String, Object?>{'showWindows': 'no'})
            .showWindows,
        isTrue,
      );
    });

    test('the windows can be switched off', () {
      expect(
        neoLauncherOptions(const <String, Object?>{'showWindows': false})
            .showWindows,
        isFalse,
      );
    });

    test('every icon has a label and a description', () {
      for (final icon in NeoLauncherIcon.values) {
        expect(neoLauncherIconLabel(icon), isNotEmpty);
        expect(neoLauncherIconDescription(icon), isNotEmpty);
      }
      expect(neoLauncherIconOrder.toSet(), NeoLauncherIcon.values.toSet());
    });

    test('only the Denial mark is not selectable yet', () {
      expect(neoLauncherIconSelectable(NeoLauncherIcon.denial), isFalse);
      for (final icon in NeoLauncherIcon.values) {
        if (icon == NeoLauncherIcon.denial) continue;
        expect(neoLauncherIconSelectable(icon), isTrue);
      }
    });
  });

  group('neoLauncherArt', () {
    NeoLauncherOptions options(
      String icon, {
      String? path,
      bool systemAvailable = true,
    }) => neoLauncherOptions(
      <String, Object?>{'icon': icon, 'customPath': ?path},
      // The caller decides this from what it found: a distribution mark on this
      // machine, the mark the plugin bundles, or neither.
      systemIconAvailable: systemAvailable,
    );

    test('the grid is a glyph', () {
      final art = neoLauncherArt(options: options('grid'));
      expect(art.kind, NeoLauncherArtKind.glyph);
      expect(art.value, neoLauncherGridGlyph);
    });

    test('a custom icon draws the file the user picked', () {
      final art = neoLauncherArt(
        options: options('custom', path: '/home/me/logo.svg'),
      );
      expect(art.kind, NeoLauncherArtKind.file);
      expect(art.value, '/home/me/logo.svg');
    });

    test('a system icon prefers the distribution file when there is one', () {
      final art = neoLauncherArt(
        options: options('system'),
        systemLogoPath: '/usr/share/pixmaps/cachyos-logo.svg',
        bundledAsset: neoLauncherBundledArchAsset,
      );
      expect(art.kind, NeoLauncherArtKind.file);
      expect(art.value, '/usr/share/pixmaps/cachyos-logo.svg');
    });

    test('a system icon falls back to the bundled mark, then the glyph', () {
      expect(
        neoLauncherArt(
          options: options('system'),
          bundledAsset: neoLauncherBundledArchAsset,
        ).value,
        neoLauncherBundledArchAsset,
      );
      // Nothing to draw at all: the grid, never an empty pill.
      expect(
        neoLauncherArt(options: options('system')).kind,
        NeoLauncherArtKind.glyph,
      );
      expect(
        neoLauncherArt(
          options: options('system', systemAvailable: false),
          bundledAsset: neoLauncherBundledArchAsset,
        ).kind,
        NeoLauncherArtKind.glyph,
      );
    });
  });

  group('neoDistroId', () {
    test('reads ID and lower-cases it', () {
      expect(neoDistroId('NAME="Arch Linux"\nID=arch\n'), 'arch');
      expect(neoDistroId('ID=CachyOS\n'), 'cachyos');
    });

    test('strips quotes and ignores comments and blanks', () {
      expect(neoDistroId('# a comment\n\nID="endeavouros"\n'), 'endeavouros');
    });

    test('uses the first ID_LIKE when ID is missing', () {
      expect(neoDistroId('ID_LIKE="arch linux"\n'), 'arch');
    });

    test('ID wins over ID_LIKE', () {
      expect(neoDistroId('ID=endeavouros\nID_LIKE=arch\n'), 'endeavouros');
    });

    test('an empty or unusable document is null', () {
      expect(neoDistroId(''), isNull);
      expect(neoDistroId('NAME=Whatever\n'), isNull);
      expect(neoDistroId('ID=\n'), isNull);
    });
  });

  group('neoSystemLogoCandidates', () {
    test('tries the distribution own names first', () {
      final candidates = neoSystemLogoCandidates('cachyos');
      expect(candidates.first, '/usr/share/pixmaps/cachyos-logo.svg');
      expect(candidates, contains('/usr/share/pixmaps/cachyos.svg'));
    });

    test('adds the Arch name for Arch-derived distributions', () {
      expect(
        neoSystemLogoCandidates('endeavouros'),
        contains('/usr/share/pixmaps/archlinux-logo.svg'),
      );
      expect(
        neoSystemLogoCandidates('fedora'),
        isNot(contains('/usr/share/pixmaps/archlinux-logo.svg')),
      );
    });

    test('an unknown distribution still gets generic candidates', () {
      expect(neoSystemLogoCandidates(null), isEmpty);
      expect(neoSystemLogoCandidates(''), isEmpty);
    });
  });

  group('the custom icon browser', () {
    test('offers directories and images, directories first', () {
      final entries = neoBrowseEntries(const <NeoBrowseEntry>[
        NeoBrowseEntry(name: 'zebra.png', isDirectory: false),
        NeoBrowseEntry(name: 'Pictures', isDirectory: true),
        NeoBrowseEntry(name: 'notes.txt', isDirectory: false),
        NeoBrowseEntry(name: 'apple.svg', isDirectory: false),
        NeoBrowseEntry(name: 'Music', isDirectory: true),
      ]);
      expect(entries.map((entry) => entry.name), <String>[
        'Music',
        'Pictures',
        'apple.svg',
        'zebra.png',
      ]);
    });

    test('hides dotfiles and anything unusable', () {
      final entries = neoBrowseEntries(const <NeoBrowseEntry>[
        NeoBrowseEntry(name: '.cache', isDirectory: true),
        NeoBrowseEntry(name: '.bashrc', isDirectory: false),
        NeoBrowseEntry(name: 'README.md', isDirectory: false),
        NeoBrowseEntry(name: 'logo.WEBP', isDirectory: false),
      ]);
      expect(entries.map((entry) => entry.name), <String>['logo.WEBP']);
    });

    test('sorts case-insensitively', () {
      final entries = neoBrowseEntries(const <NeoBrowseEntry>[
        NeoBrowseEntry(name: 'beta.png', isDirectory: false),
        NeoBrowseEntry(name: 'Alpha.png', isDirectory: false),
      ]);
      expect(entries.map((entry) => entry.name), <String>[
        'Alpha.png',
        'beta.png',
      ]);
    });

    test('recognises the image extensions it advertises', () {
      expect(neoIsImageFileName('a.svg'), isTrue);
      expect(neoIsImageFileName('a.JPEG'), isTrue);
      expect(neoIsImageFileName('a'), isFalse);
      expect(neoIsImageFileName('.png'), isFalse);
      expect(neoIsImageFileName('a.png.bak'), isFalse);
    });

    test('shows a chosen file by name, not by full path', () {
      expect(neoFileName('/home/me/Pictures/logo.svg'), 'logo.svg');
      expect(neoFileName('/home/me/Pictures/'), 'Pictures');
      expect(neoFileName('logo.svg'), 'logo.svg');
      expect(neoFileName('/'), '/');
    });

    test('walks up without losing the root', () {
      expect(neoParentDirectory('/home/me/Pictures'), '/home/me');
      expect(neoParentDirectory('/home/me/Pictures/'), '/home/me');
      expect(neoParentDirectory('/home'), '/');
      expect(neoParentDirectory('/'), isNull);
      expect(neoParentDirectory(''), isNull);
    });
  });
}
