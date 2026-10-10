import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

NeoLaunchableApp _app(
  String id, {
  String? appId,
  String name = '',
  List<String> windowAppIds = const <String>[],
}) => (id: id, appId: appId ?? id, name: name, windowAppIds: windowAppIds);

void main() {
  group('neoNewWindowAppId', () {
    test('follows the catalog entry that claims the window app id', () {
      // The entry's own app id need not be the one the window reports; the
      // window list is what the launcher's own answer is built from.
      final applications = <NeoLaunchableApp>[
        _app('firefox.desktop', appId: 'org.mozilla.firefox'),
        _app(
          'code.desktop',
          appId: 'com.visualstudio.code',
          windowAppIds: <String>['code-oss', 'com.visualstudio.code'],
        ),
      ];
      expect(
        neoNewWindowAppId(applications: applications, appId: 'code-oss'),
        'code.desktop',
      );
    });

    test('falls back to an entry with the same app id', () {
      expect(
        neoNewWindowAppId(
          applications: <NeoLaunchableApp>[_app('foot.desktop', appId: 'foot')],
          appId: 'foot',
        ),
        'foot.desktop',
      );
    });

    test('answers null for an app the catalog does not know', () {
      expect(
        neoNewWindowAppId(
          applications: <NeoLaunchableApp>[_app('foot.desktop', appId: 'foot')],
          appId: 'unknown',
        ),
        isNull,
      );
      expect(
        neoNewWindowAppId(
          applications: <NeoLaunchableApp>[_app('foot.desktop', appId: 'foot')],
          appId: '',
        ),
        isNull,
      );
      expect(
        neoNewWindowAppId(
          applications: const <NeoLaunchableApp>[],
          appId: 'foot',
        ),
        isNull,
      );
    });
  });

  group('neoTerminalAppId', () {
    test('prefers a named emulator over a generic one', () {
      // `Terminal` is a real terminal, but `kitty` is unambiguous, and the list
      // puts the specific names first on purpose.
      final applications = <NeoLaunchableApp>[
        _app('terminal.desktop', appId: 'org.gnome.Terminal', name: 'Terminal'),
        _app('kitty.desktop', appId: 'kitty', name: 'kitty'),
      ];
      expect(neoTerminalAppId(applications), 'kitty.desktop');
    });

    test('matches a reverse-DNS app id on its last segment', () {
      expect(
        neoTerminalAppId(<NeoLaunchableApp>[
          _app('kgx.desktop', appId: 'org.gnome.Console', name: 'Console'),
          _app('wezterm.desktop', appId: 'org.wezfurlong.wezterm'),
        ]),
        'wezterm.desktop',
      );
    });

    test('matches a display name when the app id says nothing', () {
      expect(
        neoTerminalAppId(<NeoLaunchableApp>[
          _app('x.desktop', appId: 'com.example.x', name: 'Alacritty'),
        ]),
        'x.desktop',
      );
    });

    test('answers null rather than picking something that is not one', () {
      // A chat client whose name contains none of the words must not become the
      // "open terminal" entry.
      expect(
        neoTerminalAppId(<NeoLaunchableApp>[
          _app('chat.desktop', appId: 'com.example.chat', name: 'Chat'),
          _app('files.desktop', appId: 'org.gnome.Nautilus', name: 'Files'),
        ]),
        isNull,
      );
      expect(neoTerminalAppId(const <NeoLaunchableApp>[]), isNull);
    });
  });
}
