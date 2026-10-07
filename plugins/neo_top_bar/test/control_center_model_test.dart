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

  group('neoNextThemeMode', () {
    test('cycles through all three states and returns', () {
      expect(neoNextThemeMode(NeoThemeMode.system), NeoThemeMode.light);
      expect(neoNextThemeMode(NeoThemeMode.light), NeoThemeMode.dark);
      expect(neoNextThemeMode(NeoThemeMode.dark), NeoThemeMode.system);
    });

    test('every state has a label', () {
      for (final mode in NeoThemeMode.values) {
        expect(neoThemeModeLabel(mode), isNotEmpty);
      }
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

    test('the row lists every action exactly once', () {
      expect(neoPowerActionOrder.toSet(), NeoPowerAction.values.toSet());
      expect(neoPowerActionOrder.first, NeoPowerAction.lock);
      expect(neoPowerActionOrder.last, NeoPowerAction.powerOff);
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
