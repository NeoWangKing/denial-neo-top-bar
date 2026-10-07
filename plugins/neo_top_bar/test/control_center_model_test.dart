/// Tests for the control centre's pure logic.
///
/// The rules under test are the ones that make the panel readable: one row per
/// Wi-Fi network rather than one per radio, useful devices on top, a theme tile
/// that can express "follow the system", and confirmations only where a mistake
/// costs work.
library;

import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

NeoWifiEntry wifi(
  String ssid, {
  int strength = 50,
  bool connected = false,
  bool secured = true,
  String? id,
}) => NeoWifiEntry(
  id: id ?? '$ssid-$strength',
  ssid: ssid,
  strength: strength,
  connected: connected,
  secured: secured,
);

NeoBluetoothEntry bt(
  String name, {
  bool connected = false,
  bool paired = false,
  int? signal,
  String? id,
}) => NeoBluetoothEntry(
  id: id ?? name,
  name: name,
  connected: connected,
  paired: paired,
  signal: signal,
);

void main() {
  group('neoWifiPanelEntries', () {
    test('collapses one network with two radios into one row', () {
      final entries = neoWifiPanelEntries(<NeoWifiEntry>[
        wifi('Home', strength: 40, id: 'home-2g'),
        wifi('Home', strength: 80, id: 'home-5g'),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.strength, 80);
      expect(entries.single.id, 'home-5g');
    });

    test('keeps the connected radio of a network it is on', () {
      // The connected radio can be the weaker one, and the row has to be the
      // one that can be disconnected.
      final entries = neoWifiPanelEntries(<NeoWifiEntry>[
        wifi('Home', strength: 90, id: 'home-5g'),
        wifi('Home', strength: 30, connected: true, id: 'home-2g'),
      ]);
      expect(entries.single.connected, isTrue);
      expect(entries.single.id, 'home-2g');
    });

    test('puts the connected network first, then the strongest', () {
      final entries = neoWifiPanelEntries(<NeoWifiEntry>[
        wifi('Weak', strength: 10),
        wifi('Strong', strength: 95),
        wifi('Joined', strength: 20, connected: true),
      ]);
      expect(entries.map((entry) => entry.ssid), <String>[
        'Joined',
        'Strong',
        'Weak',
      ]);
    });

    test('breaks equal strengths by name so scans do not reshuffle it', () {
      final first = neoWifiPanelEntries(<NeoWifiEntry>[
        wifi('Beta', strength: 60),
        wifi('Alpha', strength: 60),
      ]);
      final second = neoWifiPanelEntries(<NeoWifiEntry>[
        wifi('Alpha', strength: 60),
        wifi('Beta', strength: 60),
      ]);
      expect(first.map((entry) => entry.ssid), <String>['Alpha', 'Beta']);
      expect(second.map((entry) => entry.ssid), <String>['Alpha', 'Beta']);
    });

    test('drops nameless networks', () {
      expect(
        neoWifiPanelEntries(<NeoWifiEntry>[
          wifi('', strength: 99),
          wifi('Named'),
        ]).map((entry) => entry.ssid),
        <String>['Named'],
      );
    });

    test('caps the list without dropping the connected row', () {
      final entries = neoWifiPanelEntries(<NeoWifiEntry>[
        for (var index = 0; index < 20; index++)
          wifi('Net$index', strength: index),
        wifi('Joined', strength: 1, connected: true),
      ], limit: 3);
      expect(entries, hasLength(3));
      expect(entries.first.ssid, 'Joined');
    });

    test('a zero limit yields nothing and is not an error', () {
      expect(neoWifiPanelEntries(<NeoWifiEntry>[wifi('A')], limit: 0), isEmpty);
      expect(
        neoWifiPanelEntries(<NeoWifiEntry>[wifi('A')], limit: -1),
        isEmpty,
      );
      expect(neoWifiPanelEntries(const <NeoWifiEntry>[]), isEmpty);
    });
  });

  group('neoBluetoothPanelEntries', () {
    test('orders connected, then paired, then the rest', () {
      final entries = neoBluetoothPanelEntries(<NeoBluetoothEntry>[
        bt('Scanner'),
        bt('Paired', paired: true),
        bt('Headset', connected: true),
      ]);
      expect(entries.map((entry) => entry.name), <String>[
        'Headset',
        'Paired',
        'Scanner',
      ]);
    });

    test('sorts alphabetically inside a group, ignoring case', () {
      final entries = neoBluetoothPanelEntries(<NeoBluetoothEntry>[
        bt('zeta', paired: true),
        bt('Alpha', paired: true),
      ]);
      expect(entries.map((entry) => entry.name), <String>['Alpha', 'zeta']);
    });

    test('keeps one row per device, preferring the live one', () {
      final entries = neoBluetoothPanelEntries(<NeoBluetoothEntry>[
        bt('Mouse', id: 'm', signal: 10),
        bt('Mouse', id: 'm', connected: true, paired: true, signal: 5),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.connected, isTrue);
      expect(entries.single.paired, isTrue);
    });
  });

  group('theme mode', () {
    test('reads the effective brightness', () {
      expect(neoThemeMode(isDark: true), NeoThemeMode.dark);
      expect(neoThemeMode(isDark: false), NeoThemeMode.light);
    });

    test('every tap flips to the other state', () {
      expect(neoNextThemeMode(NeoThemeMode.dark), NeoThemeMode.light);
      expect(neoNextThemeMode(NeoThemeMode.light), NeoThemeMode.dark);
      expect(
        neoNextThemeMode(neoNextThemeMode(neoThemeMode(isDark: true))),
        NeoThemeMode.dark,
      );
    });

    test('every state has a label', () {
      for (final mode in NeoThemeMode.values) {
        expect(neoThemeModeLabel(mode), isNotEmpty);
      }
    });

    test('in glass mode the tap must write the glass appearance', () {
      // The shell reads `glass.appearance` while the transparency mode is glass,
      // so writing only the colour scheme is the bug this guards: it changed a
      // setting nothing on screen read.
      final toggle = neoThemeToggle(
        current: NeoThemeMode.dark,
        glassTransparency: true,
      );
      expect(toggle.mode, NeoThemeMode.light);
      expect(toggle.writeGlass, isTrue);
      expect(toggle.writeColorScheme, isTrue);
    });

    test('outside glass mode the colour scheme is what the shell reads', () {
      final toggle = neoThemeToggle(
        current: NeoThemeMode.light,
        glassTransparency: false,
      );
      expect(toggle.mode, NeoThemeMode.dark);
      expect(toggle.writeGlass, isFalse);
      expect(toggle.writeColorScheme, isTrue);
    });
  });

  group('neoWiredLinkUp', () {
    NeoLinkFacts link(
      String name, {
      String operState = 'up',
      bool wireless = false,
      bool physical = true,
      bool routable = true,
    }) => NeoLinkFacts(
      name: name,
      operState: operState,
      wireless: wireless,
      physical: physical,
      routable: routable,
    );

    test('accepts an up physical link with an address', () {
      expect(neoWiredLinkUp(<NeoLinkFacts>[link('enp5s0')]), isTrue);
    });

    test('rejects a wireless interface even when it is up', () {
      expect(
        neoWiredLinkUp(<NeoLinkFacts>[link('wlan0', wireless: true)]),
        isFalse,
      );
    });

    test('rejects a link that is down or has no address', () {
      expect(
        neoWiredLinkUp(<NeoLinkFacts>[link('enp5s0', operState: 'down')]),
        isFalse,
      );
      expect(
        neoWiredLinkUp(<NeoLinkFacts>[link('enp5s0', routable: false)]),
        isFalse,
      );
    });

    test('rejects software interfaces, which have no device symlink', () {
      expect(
        neoWiredLinkUp(<NeoLinkFacts>[
          link('docker0', physical: false),
          link('veth1a2b', physical: false),
        ]),
        isFalse,
      );
    });

    test('accepts an interface whose driver reports unknown', () {
      expect(
        neoWiredLinkUp(<NeoLinkFacts>[link('enp5s0', operState: 'unknown')]),
        isTrue,
      );
    });

    test('finds one good link among many bad ones', () {
      expect(
        neoWiredLinkUp(<NeoLinkFacts>[
          link('lo', physical: false),
          link('wlan0', wireless: true),
          link('enp5s0', operState: 'down'),
          link('enx00e04c', operState: 'up'),
        ]),
        isTrue,
      );
    });

    test('an empty list is not a wired link', () {
      expect(neoWiredLinkUp(const <NeoLinkFacts>[]), isFalse);
    });
  });

  group('neoNetworkGlyph', () {
    test('a wired link wins over Wi-Fi', () {
      expect(
        neoNetworkGlyph(
          wiredUp: true,
          wifiConnected: true,
          wirelessEnabled: true,
        ),
        NeoNetworkGlyph.ethernet,
      );
    });

    test('Wi-Fi connected, then radio state', () {
      expect(
        neoNetworkGlyph(
          wiredUp: false,
          wifiConnected: true,
          wirelessEnabled: true,
        ),
        NeoNetworkGlyph.wifi,
      );
      expect(
        neoNetworkGlyph(
          wiredUp: false,
          wifiConnected: false,
          wirelessEnabled: true,
        ),
        NeoNetworkGlyph.offline,
      );
      expect(
        neoNetworkGlyph(
          wiredUp: false,
          wifiConnected: false,
          wirelessEnabled: false,
        ),
        NeoNetworkGlyph.wifiOff,
      );
    });
  });

  group('audio lists', () {
    NeoAudioDevice device(
      String name, {
      String description = '',
      bool active = false,
      bool available = true,
    }) => NeoAudioDevice(
      name: name,
      description: description,
      active: active,
      available: available,
    );

    NeoAppStream stream(int id, String name, {double level = 0.5}) =>
        NeoAppStream(id: id, name: name, level: level, muted: false);

    test('drops unavailable outputs and puts the active one first', () {
      final entries = neoAudioDeviceEntries(<NeoAudioDevice>[
        device('hdmi', description: 'HDMI'),
        device('usb', description: 'USB 耳機'),
        device('analog', description: 'Analog', active: true),
        device('ghost', description: 'Gone', available: false),
      ]);
      expect(entries.map((entry) => entry.name), <String>[
        'analog',
        'hdmi',
        'usb',
      ]);
    });

    test('orders outputs by name, falling back to the id', () {
      final entries = neoAudioDeviceEntries(<NeoAudioDevice>[
        device('b', description: 'Zeta'),
        device('a', description: 'alpha'),
      ]);
      expect(entries.map((entry) => entry.description), <String>[
        'alpha',
        'Zeta',
      ]);
    });

    test('orders application streams by name and keeps one row per id', () {
      final entries = neoAppStreamEntries(<NeoAppStream>[
        stream(2, 'firefox'),
        stream(1, 'Discord'),
        stream(2, 'firefox'),
      ]);
      expect(entries.map((entry) => entry.id), <int>[1, 2]);
      expect(entries.map((entry) => entry.name), <String>[
        'Discord',
        'firefox',
      ]);
    });

    test('caps both lists', () {
      expect(
        neoAudioDeviceEntries(<NeoAudioDevice>[
          for (var index = 0; index < 10; index++) device('$index'),
        ], limit: 3),
        hasLength(3),
      );
      expect(
        neoAppStreamEntries(<NeoAppStream>[
          for (var index = 0; index < 10; index++) stream(index, 'app$index'),
        ], limit: 3),
        hasLength(3),
      );
      expect(neoAudioDeviceEntries(const <NeoAudioDevice>[]), isEmpty);
      expect(neoAppStreamEntries(const <NeoAppStream>[]), isEmpty);
    });
  });

  group('power actions', () {
    test('only the actions that can lose work ask first', () {
      expect(neoPowerActionNeedsConfirmation(NeoPowerAction.lock), isFalse);
      expect(neoPowerActionNeedsConfirmation(NeoPowerAction.suspend), isFalse);
      expect(
        neoPowerActionNeedsConfirmation(NeoPowerAction.hibernate),
        isFalse,
      );
      expect(neoPowerActionNeedsConfirmation(NeoPowerAction.logout), isTrue);
      expect(neoPowerActionNeedsConfirmation(NeoPowerAction.reboot), isTrue);
      expect(neoPowerActionNeedsConfirmation(NeoPowerAction.powerOff), isTrue);
    });

    test('every action has a label, and confirmed ones a question', () {
      for (final action in NeoPowerAction.values) {
        expect(neoPowerActionLabel(action), isNotEmpty);
        expect(
          neoPowerConfirmationQuestion(action).isNotEmpty,
          neoPowerActionNeedsConfirmation(action),
        );
      }
    });

    test('the row shows the four session actions, least destructive first', () {
      expect(neoPowerActionOrder, <NeoPowerAction>[
        NeoPowerAction.lock,
        NeoPowerAction.logout,
        NeoPowerAction.reboot,
        NeoPowerAction.powerOff,
      ]);
      // Sleep and hibernate stay implemented (the label and confirmation tests
      // above cover them) but are not offered: a six-button row squeezed every
      // target too small to hit comfortably.
      expect(neoPowerActionOrder, isNot(contains(NeoPowerAction.suspend)));
      expect(neoPowerActionOrder, isNot(contains(NeoPowerAction.hibernate)));
    });
  });

  group('neoControlCenterOptions', () {
    test(
      'an untouched configuration shows and offers everything by default',
      () {
        final options = neoControlCenterOptions(const <String, Object?>{});
        expect(options.glyphs, neoPillGlyphOrder.toSet());
        expect(options.powerActions, neoPowerActionOrder);
        expect(options.isDefault, isTrue);
      },
    );

    test('a stored selection is honoured in canonical order', () {
      final options = neoControlCenterOptions(<String, Object?>{
        'glyphs': <String>['battery', 'volume'],
        'power': <String>['powerOff', 'lock'],
      });
      expect(options.glyphs, <NeoPillGlyph>{
        NeoPillGlyph.volume,
        NeoPillGlyph.battery,
      });
      // Power off cannot be hoisted above lock by editing the file: a mis-click
      // must not become a shutdown.
      expect(options.powerActions, <NeoPowerAction>[
        NeoPowerAction.lock,
        NeoPowerAction.powerOff,
      ]);
    });

    test('unknown names are ignored, not treated as an error', () {
      final options = neoControlCenterOptions(<String, Object?>{
        'glyphs': <String>['volume', 'teleporter', 'network'],
        'power': <String>['lock', 'selfDestruct'],
      });
      expect(options.glyphs, <NeoPillGlyph>{
        NeoPillGlyph.volume,
        NeoPillGlyph.network,
      });
      expect(options.powerActions, <NeoPowerAction>[NeoPowerAction.lock]);
    });

    test('values of the wrong shape fall back rather than throw', () {
      final options = neoControlCenterOptions(<String, Object?>{
        'glyphs': 'volume',
        'power': 7,
      });
      expect(options.glyphs, neoPillGlyphOrder.toSet());
      expect(options.powerActions, neoPowerActionOrder);
    });

    test('an emptied power row is a choice, an emptied pill is not', () {
      expect(
        neoControlCenterOptions(<String, Object?>{'power': <String>[]})
            .powerActions,
        isEmpty,
      );
      expect(
        neoControlCenterOptions(<String, Object?>{'glyphs': <String>[]}).glyphs,
        neoPillGlyphOrder.toSet(),
      );
    });

    test('every glyph has a label and a description', () {
      for (final glyph in NeoPillGlyph.values) {
        expect(neoPillGlyphLabel(glyph), isNotEmpty);
        expect(neoPillGlyphDescription(glyph), isNotEmpty);
      }
    });

    test('the last remaining glyph cannot be switched off', () {
      expect(
        neoCanDisableGlyph(<NeoPillGlyph>{
          NeoPillGlyph.volume,
        }, NeoPillGlyph.volume),
        isFalse,
      );
      expect(
        neoCanDisableGlyph(neoPillGlyphOrder.toSet(), NeoPillGlyph.volume),
        isTrue,
      );
      expect(
        neoCanDisableGlyph(<NeoPillGlyph>{
          NeoPillGlyph.volume,
        }, NeoPillGlyph.network),
        isFalse,
      );
    });
  });

  group('labels', () {
    test('volume reads as a percentage, or as muted at zero', () {
      expect(neoVolumeLabel(0.42), '42%');
      expect(neoVolumeLabel(0.0), '静音');
      expect(neoVolumeLabel(0.42, muted: true), '静音');
      expect(neoVolumeLabel(1.5), '100%');
      expect(neoVolumeLabel(-1), '静音');
    });

    test('brightness never reads as muted', () {
      expect(neoBrightnessLabel(0.5), '50%');
      expect(neoBrightnessLabel(0), '0%');
    });

    test('muting remembers a level and unmuting restores it', () {
      expect(
        neoVolumeAfterMuteToggle(level: 0.8, muted: false, remembered: 0.3),
        0.0,
      );
      expect(
        neoVolumeAfterMuteToggle(level: 0.0, muted: false, remembered: 0.3),
        0.3,
      );
      // Nothing to remember: fall back to a level nobody has to fix.
      expect(
        neoVolumeAfterMuteToggle(level: 0.0, muted: true, remembered: 0.0),
        0.05,
      );
    });

    test('the pill glyph steps through four states', () {
      expect(neoVolumeGlyphStep(0.0), 0);
      expect(neoVolumeGlyphStep(0.9, muted: true), 0);
      expect(neoVolumeGlyphStep(0.1), 1);
      expect(neoVolumeGlyphStep(0.5), 2);
      expect(neoVolumeGlyphStep(0.9), 3);
    });
  });
}
