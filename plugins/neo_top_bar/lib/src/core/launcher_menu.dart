/// What the launcher's right-click menus can offer, and how they find their
/// target in the host's catalog of installed applications.
///
/// Pure: the widget layer turns these ids into `launchApplication` calls, so the
/// decisions worth testing — which catalog entry a window belongs to, which
/// entry is the user's terminal — live here instead of in a tap handler.
library;

/// One entry of the host's application catalog, reduced to what these menus ask
/// of it.
///
/// [id] is the opaque launch identity the host wants back; [appId] is what a
/// running window reports; [windowAppIds] is every app id that entry is known to
/// open windows under, which is how a window is traced back to its catalog
/// entry.
typedef NeoLaunchableApp = ({
  String id,
  String appId,
  String name,
  List<String> windowAppIds,
});

/// Application ids that are terminal emulators, most preferred first.
///
/// A list rather than a rule, because the catalog has no "this is a terminal"
/// flag: `appId` and the display name are all a plugin is given. Reverse-DNS ids
/// (`org.gnome.Terminal`) are matched on their last segment, and a display name
/// that contains one of these words counts too, so `Kitty` and `kitty` both land
/// on the same entry.
///
/// Deliberately short and unambiguous: a word that could name something else
/// would put "open terminal" on a menu that opens a chat client.
const List<String> neoTerminalWords = <String>[
  'ghostty',
  'kitty',
  'wezterm',
  'alacritty',
  'konsole',
  'gnome-terminal',
  'ptyxis',
  'kgx',
  'xfce4-terminal',
  'tilix',
  'terminator',
  'terminology',
  'guake',
  'yakuake',
  'xterm',
  'urxvt',
  'foot',
  // Last, and generic on purpose: an app id whose last segment is `terminal`,
  // or a name like `GNOME Terminal`, is a terminal whatever it is called. It
  // sits at the end so a specific emulator always wins.
  'terminal',
];

/// The catalog entry that opens another window of [appId], or null.
///
/// A window carries the app id it reports; the catalog knows which of its
/// entries open windows under it. Prefer an entry that *lists* the app id — that
/// is the launcher's own answer to "which of my applications is this" — and fall
/// back to an entry whose own app id is the same, which is the common case when
/// the two agree.
String? neoNewWindowAppId({
  required List<NeoLaunchableApp> applications,
  required String appId,
}) {
  if (appId.isEmpty) return null;
  for (final application in applications) {
    if (application.windowAppIds.contains(appId)) return application.id;
  }
  for (final application in applications) {
    if (application.appId == appId) return application.id;
  }
  return null;
}

/// The terminal to open, or null when the catalog holds none.
///
/// Null is a real answer and the menus have to respect it: an entry that opens
/// whatever happens to be lying around would be worse than no entry at all.
String? neoTerminalAppId(List<NeoLaunchableApp> applications) {
  for (final word in neoTerminalWords) {
    for (final application in applications) {
      if (_isTerminal(application, word)) return application.id;
    }
  }
  return null;
}

bool _isTerminal(NeoLaunchableApp application, String word) {
  final appId = application.appId.toLowerCase();
  if (appId == word || appId.split('.').last == word) return true;
  final name = application.name.toLowerCase().replaceAll(' ', '');
  return name == word || name.contains(word);
}
