import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

/// The standalone phrases, one line each, sampled from every area of the UI.
///
/// A hand-written list rather than reflection: a phrase that is only written in
/// one language is exactly the mistake this file exists to catch, and listing the
/// pairs makes a missing translation visible in the diff.
final Map<String, ({String zh, String en})>
_samples = <String, ({String zh, String en})>{
  'close': (zh: zh.close, en: en.close),
  'cancel': (zh: zh.cancel, en: en.cancel),
  'add': (zh: zh.add, en: en.add),
  'mute': (zh: zh.mute, en: en.mute),
  'unmute': (zh: zh.unmute, en: en.unmute),
  'mutedCaption': (zh: zh.mutedCaption, en: en.mutedCaption),
  'volumeLabel': (zh: zh.volumeLabel(0.5), en: en.volumeLabel(0.5)),
  'volumeLabel muted': (
    zh: zh.volumeLabel(0, muted: true),
    en: en.volumeLabel(0, muted: true),
  ),
  'network': (zh: zh.network, en: en.network),
  'bluetooth': (zh: zh.bluetooth, en: en.bluetooth),
  'battery': (zh: zh.battery, en: en.battery),
  'notifications': (zh: zh.notifications, en: en.notifications),
  'doNotDisturb': (zh: zh.doNotDisturb, en: en.doNotDisturb),
  'appearance': (zh: zh.appearance, en: en.appearance),
  'switchedOn': (zh: zh.switchedOn, en: en.switchedOn),
  'switchedOff': (zh: zh.switchedOff, en: en.switchedOff),
  'serviceUnavailable': (zh: zh.serviceUnavailable, en: en.serviceUnavailable),
  'notSupportedInSession': (
    zh: zh.notSupportedInSession,
    en: en.notSupportedInSession,
  ),
  'toggle': (zh: zh.toggle, en: en.toggle),
  'connect': (zh: zh.connect, en: en.connect),
  'connecting': (zh: zh.connecting, en: en.connecting),
  'scanning': (zh: zh.scanning, en: en.scanning),
  'settingsTitle': (zh: zh.settingsTitle, en: en.settingsTitle),
  'settingsTooltip': (zh: zh.settingsTooltip, en: en.settingsTooltip),
  'appearanceSettingsTitle': (
    zh: zh.appearanceSettingsTitle,
    en: en.appearanceSettingsTitle,
  ),
  'allModuleSettings': (zh: zh.allModuleSettings, en: en.allModuleSettings),
  'pillGone': (zh: zh.pillGone, en: en.pillGone),
  'moduleSettingsTitle': (
    zh: zh.moduleSettingsTitle('X'),
    en: en.moduleSettingsTitle('X'),
  ),
  'expandSettings': (zh: zh.expandSettings, en: en.expandSettings),
  'collapseSettings': (zh: zh.collapseSettings, en: en.collapseSettings),
  'removeFromBar': (zh: zh.removeFromBar, en: en.removeFromBar),
  'moduleHasNoSettings': (
    zh: zh.moduleHasNoSettings,
    en: en.moduleHasNoSettings,
  ),
  'zoneEmpty': (zh: zh.zoneEmpty, en: en.zoneEmpty),
  'addModule': (zh: zh.addModule, en: en.addModule),
  'addModuleHint': (zh: zh.addModuleHint, en: en.addModuleHint),
  'densityLabel': (zh: zh.densityLabel, en: en.densityLabel),
  'densityCompact': (zh: zh.densityCompact, en: en.densityCompact),
  'densityStandard': (zh: zh.densityStandard, en: en.densityStandard),
  'densityRelaxed': (zh: zh.densityRelaxed, en: en.densityRelaxed),
  'dragToReorderZone': (zh: zh.dragToReorderZone, en: en.dragToReorderZone),
  'boardHintReorder': (zh: zh.boardHintReorder, en: en.boardHintReorder),
  'boardHintAxis': (
    zh: zh.boardHintAxis(barIsVertical: false),
    en: en.boardHintAxis(barIsVertical: false),
  ),
  'boardHintChevron': (zh: zh.boardHintChevron, en: en.boardHintChevron),
  'loadFailed': (zh: zh.loadFailed('x'), en: en.loadFailed('x')),
  'saveFailed': (zh: zh.saveFailed('x'), en: en.saveFailed('x')),
  'browseFiles': (zh: zh.browseFiles, en: en.browseFiles),
  'parentDirectory': (zh: zh.parentDirectory, en: en.parentDirectory),
  'chooseImage': (zh: zh.chooseImage, en: en.chooseImage),
  'customImage': (zh: zh.customImage, en: en.customImage),
  'pickImageHint': (zh: zh.pickImageHint, en: en.pickImageHint),
  'noImageSelected': (zh: zh.noImageSelected, en: en.noImageSelected),
  'fileMissing': (zh: zh.fileMissing, en: en.fileMissing),
  'directoryEmpty': (zh: zh.directoryEmpty, en: en.directoryEmpty),
  'collapse': (zh: zh.collapse, en: en.collapse),
  'openDirectoryFailed': (
    zh: zh.openDirectoryFailed('x'),
    en: en.openDirectoryFailed('x'),
  ),
  'previousTrack': (zh: zh.previousTrack, en: en.previousTrack),
  'nextTrack': (zh: zh.nextTrack, en: en.nextTrack),
  'play': (zh: zh.play, en: en.play),
  'pause': (zh: zh.pause, en: en.pause),
  'openPowerSettings': (zh: zh.openPowerSettings, en: en.openPowerSettings),
  'clockTime': (zh: zh.clockTime, en: en.clockTime),
  'clockDate': (zh: zh.clockDate, en: en.clockDate),
  'clockShowDate': (zh: zh.clockShowDate, en: en.clockShowDate),
  'clockShowDateHint': (zh: zh.clockShowDateHint, en: en.clockShowDateHint),
  'clockUse24Hour': (zh: zh.clockUse24Hour, en: en.clockUse24Hour),
  'clockDateFormat': (zh: zh.clockDateFormat, en: en.clockDateFormat),
  'clockOpenCalendar': (zh: zh.clockOpenCalendar, en: en.clockOpenCalendar),
  'clockTimeExample': (
    zh: zh.clockTimeExample('8:52 上午'),
    en: en.clockTimeExample('8:52 AM'),
  ),
  'clockTimeExample24': (
    zh: zh.clockTimeExample24('20:52'),
    en: en.clockTimeExample24('20:52'),
  ),
  'launcherIcon': (zh: zh.launcherIcon, en: en.launcherIcon),
  'launcherIconQuestion': (
    zh: zh.launcherIconQuestion,
    en: en.launcherIconQuestion,
  ),
  'launcherShowWorkspaceWindows': (
    zh: zh.launcherShowWorkspaceWindows,
    en: en.launcherShowWorkspaceWindows,
  ),
  'launcherShowWorkspaceWindowsHint': (
    zh: zh.launcherShowWorkspaceWindowsHint,
    en: en.launcherShowWorkspaceWindowsHint,
  ),
  'launcherOpen': (zh: zh.launcherOpen, en: en.launcherOpen),
  'launcherOpenWithCount': (
    zh: zh.launcherOpenWithCount(3),
    en: en.launcherOpenWithCount(3),
  ),
  'launcherUsingPath': (
    zh: zh.launcherUsingPath('/tmp/x.png'),
    en: en.launcherUsingPath('/tmp/x.png'),
  ),
  'launcherDenialUnavailable': (
    zh: zh.launcherDenialUnavailable,
    en: en.launcherDenialUnavailable,
  ),
  'launcherFallbackActive': (
    zh: zh.launcherFallbackActive,
    en: en.launcherFallbackActive,
  ),
  'launcherNoDistroLogo': (
    zh: zh.launcherNoDistroLogo,
    en: en.launcherNoDistroLogo,
  ),
  'previousMonth': (zh: zh.previousMonth, en: en.previousMonth),
  'nextMonth': (zh: zh.nextMonth, en: en.nextMonth),
  'backToToday': (zh: zh.backToToday, en: en.backToToday),
  'notificationsEmpty': (zh: zh.notificationsEmpty, en: en.notificationsEmpty),
  'notificationsClearAll': (
    zh: zh.notificationsClearAll,
    en: en.notificationsClearAll,
  ),
  'notificationsDismiss': (
    zh: zh.notificationsDismiss,
    en: en.notificationsDismiss,
  ),
  'notificationsEnableDnd': (
    zh: zh.notificationsEnableDnd,
    en: en.notificationsEnableDnd,
  ),
  'notificationsDisableDnd': (
    zh: zh.notificationsDisableDnd,
    en: en.notificationsDisableDnd,
  ),
  'unreadNotifications': (
    zh: zh.unreadNotifications(2),
    en: en.unreadNotifications(2),
  ),
  'pillGlyphs': (zh: zh.pillGlyphs, en: en.pillGlyphs),
  'pillGlyphsAtLeastOne': (
    zh: zh.pillGlyphsAtLeastOne,
    en: en.pillGlyphsAtLeastOne,
  ),
  'batteryGlyphIcon': (zh: zh.batteryGlyphIcon, en: en.batteryGlyphIcon),
  'clockCompactNote': (zh: zh.clockCompactNote, en: en.clockCompactNote),
  'trayMoreIcons': (zh: zh.trayMoreIcons(2), en: en.trayMoreIcons(2)),
  'launcherMenuOpenLauncher': (
    zh: zh.launcherMenuOpenLauncher,
    en: en.launcherMenuOpenLauncher,
  ),
  'launcherMenuOpenTerminal': (
    zh: zh.launcherMenuOpenTerminal,
    en: en.launcherMenuOpenTerminal,
  ),
  'launcherMenuNewWindow': (
    zh: zh.launcherMenuNewWindow,
    en: en.launcherMenuNewWindow,
  ),
  'launcherMenuCloseWindow': (
    zh: zh.launcherMenuCloseWindow,
    en: en.launcherMenuCloseWindow,
  ),
  'workspaceShowWindows': (
    zh: zh.workspaceShowWindows,
    en: en.workspaceShowWindows,
  ),
  'workspaceShowWindowsHint': (
    zh: zh.workspaceShowWindowsHint,
    en: en.workspaceShowWindowsHint,
  ),

  'batteryGlyphIconHint': (
    zh: zh.batteryGlyphIconHint,
    en: en.batteryGlyphIconHint,
  ),
  'powerButtons': (zh: zh.powerButtons, en: en.powerButtons),
  'powerHibernateHint': (zh: zh.powerHibernateHint, en: en.powerHibernateHint),
  'powerSuspendHint': (zh: zh.powerSuspendHint, en: en.powerSuspendHint),
  'powerLockHint': (zh: zh.powerLockHint, en: en.powerLockHint),
  'powerLogoutHint': (zh: zh.powerLogoutHint, en: en.powerLogoutHint),
  'powerRebootHint': (zh: zh.powerRebootHint, en: en.powerRebootHint),
  'powerShutdownHint': (zh: zh.powerShutdownHint, en: en.powerShutdownHint),
  'batteryTooltip': (zh: zh.batteryTooltip(64), en: en.batteryTooltip(64)),
  'glyphVolumeTooltip': (zh: zh.glyphVolumeTooltip, en: en.glyphVolumeTooltip),
  'glyphVolumeMutedTooltip': (
    zh: zh.glyphVolumeMutedTooltip,
    en: en.glyphVolumeMutedTooltip,
  ),
  'glyphWifiTooltip': (zh: zh.glyphWifiTooltip, en: en.glyphWifiTooltip),
  'glyphWifiOffTooltip': (
    zh: zh.glyphWifiOffTooltip,
    en: en.glyphWifiOffTooltip,
  ),
  'glyphWifiDisconnectedTooltip': (
    zh: zh.glyphWifiDisconnectedTooltip,
    en: en.glyphWifiDisconnectedTooltip,
  ),
  'glyphWiredTooltip': (zh: zh.glyphWiredTooltip, en: en.glyphWiredTooltip),
  'glyphBluetoothTooltip': (
    zh: zh.glyphBluetoothTooltip,
    en: en.glyphBluetoothTooltip,
  ),
  'pairRequest': (zh: zh.pairRequest('X'), en: en.pairRequest('X')),
  'pairCode': (zh: zh.pairCode('X', '1234'), en: en.pairCode('X', '1234')),
  'enterPassword': (zh: zh.enterPassword('wifi'), en: en.enterPassword('wifi')),
  'bluetoothDevices': (zh: zh.bluetoothDevices, en: en.bluetoothDevices),
  'noPairedDevices': (zh: zh.noPairedDevices, en: en.noPairedDevices),
  'scanDevices': (zh: zh.scanDevices, en: en.scanDevices),
  'stopScanning': (zh: zh.stopScanning, en: en.stopScanning),
  'rescan': (zh: zh.rescan, en: en.rescan),
  'reload': (zh: zh.reload, en: en.reload),
  'accept': (zh: zh.accept, en: en.accept),
  'reject': (zh: zh.reject, en: en.reject),
  'connected': (zh: zh.connected, en: en.connected),
  'disconnected': (zh: zh.disconnected, en: en.disconnected),
  'paired': (zh: zh.paired, en: en.paired),
  'notPaired': (zh: zh.notPaired, en: en.notPaired),
  'inUse': (zh: zh.inUse, en: en.inUse),
  'openNetwork': (zh: zh.openNetwork, en: en.openNetwork),
  'passwordRequired': (zh: zh.passwordRequired, en: en.passwordRequired),
  'noNetworksFound': (zh: zh.noNetworksFound, en: en.noNetworksFound),
  'noWifiAdapter': (zh: zh.noWifiAdapter, en: en.noWifiAdapter),
  'wirelessOff': (zh: zh.wirelessOff, en: en.wirelessOff),
  'bluetoothOff': (zh: zh.bluetoothOff, en: en.bluetoothOff),
  'noAdapter': (zh: zh.noAdapter, en: en.noAdapter),
  'expandDetails': (zh: zh.expandDetails, en: en.expandDetails),
  'collapseDetails': (zh: zh.collapseDetails, en: en.collapseDetails),
  'outputsAndApps': (zh: zh.outputsAndApps, en: en.outputsAndApps),
  'displayBrightness': (zh: zh.displayBrightness, en: en.displayBrightness),
  'loadingOutputs': (zh: zh.loadingOutputs, en: en.loadingOutputs),
  'noOutputDevices': (zh: zh.noOutputDevices, en: en.noOutputDevices),
  'noDisplays': (zh: zh.noDisplays, en: en.noDisplays),
  'noAppPlaying': (zh: zh.noAppPlaying, en: en.noAppPlaying),
  'devicesSection': (zh: zh.devicesSection, en: en.devicesSection),
  'customOpenModuleSettings': (
    zh: zh.customOpenModuleSettings,
    en: en.customOpenModuleSettings,
  ),
};

const NeoStrings zh = NeoStrings(NeoLanguage.zh);
const NeoStrings en = NeoStrings(NeoLanguage.en);

bool _hasChinese(String value) => RegExp(r'[\u4e00-\u9fff]').hasMatch(value);

void main() {
  group('language selection', () {
    test('every Chinese tag Denial can send resolves to Chinese', () {
      for (final code in <String?>['zh', 'zh-Hans', 'zh_CN', 'zh-Hant', 'ZH']) {
        expect(neoLanguageFromCode(code), NeoLanguage.zh, reason: '$code');
      }
    });

    test('everything else resolves to English', () {
      for (final code in <String?>['en', 'en-US', 'de', null, '', 'ja']) {
        expect(neoLanguageFromCode(code), NeoLanguage.en, reason: '$code');
      }
    });

    test('the fallback is the language the plugin was written in', () {
      expect(neoFallbackLanguage, NeoLanguage.zh);
      expect(
        const NeoStrings(neoFallbackLanguage).settingsTitle,
        zh.settingsTitle,
      );
    });
  });

  group('the catalogue', () {
    test('every sampled phrase exists in both languages', () {
      expect(_samples.length, greaterThan(120));
      for (final entry in _samples.entries) {
        expect(entry.value.zh, isNotEmpty, reason: entry.key);
        expect(entry.value.en, isNotEmpty, reason: entry.key);
      }
    });

    test('no English phrase is left in Chinese', () {
      for (final entry in _samples.entries) {
        expect(_hasChinese(entry.value.en), isFalse, reason: entry.key);
      }
    });

    test('the two languages actually differ', () {
      // Phrase-level neutrality is allowed, but only where the word is a name or
      // a placeholder rather than a sentence.
      const Set<String> neutral = <String>{'volumeLabel'};
      for (final entry in _samples.entries) {
        if (neutral.contains(entry.key)) continue;
        expect(entry.value.en, isNot(entry.value.zh), reason: entry.key);
      }
    });

    test('every module has a name and a description in both languages', () {
      for (final descriptor in neoTopBarDefaultModules) {
        for (final catalogue in <NeoStrings>[zh, en]) {
          expect(
            catalogue.moduleLabel(descriptor.id),
            isNotEmpty,
            reason: descriptor.id,
          );
          expect(
            catalogue.moduleDescription(descriptor.id),
            isNotEmpty,
            reason: descriptor.id,
          );
          // The name must be a word, not the id echoed back.
          expect(catalogue.moduleLabel(descriptor.id), isNot(descriptor.id));
        }
        expect(
          en.moduleLabel(descriptor.id),
          isNot(zh.moduleLabel(descriptor.id)),
          reason: descriptor.id,
        );
      }
    });

    test('an unknown module still shows something recognizable', () {
      expect(zh.moduleLabel('who_knows'), 'who_knows');
      expect(zh.moduleDescription('who_knows'), isEmpty);
    });

    test('every zone, glyph, action and icon source is named', () {
      for (final zone in NeoZone.values) {
        expect(zh.zoneLabel(zone), isNotEmpty);
        expect(en.zoneLabel(zone), isNotEmpty);
        expect(en.zoneLabel(zone), isNot(zh.zoneLabel(zone)));
      }
      for (final glyph in NeoPillGlyph.values) {
        expect(zh.pillGlyphLabel(glyph), isNotEmpty);
        expect(zh.pillGlyphDescription(glyph), isNotEmpty);
        expect(en.pillGlyphLabel(glyph), isNotEmpty);
        expect(en.pillGlyphDescription(glyph), isNotEmpty);
      }
      for (final action in NeoPowerAction.values) {
        expect(zh.powerActionLabel(action), isNotEmpty);
        expect(en.powerActionLabel(action), isNotEmpty);
        expect(
          zh.powerConfirmationQuestion(action).isNotEmpty,
          neoPowerActionNeedsConfirmation(action),
          reason: action.name,
        );
        expect(
          en.powerConfirmationQuestion(action).isNotEmpty,
          neoPowerActionNeedsConfirmation(action),
          reason: action.name,
        );
      }
      for (final icon in NeoLauncherIcon.values) {
        expect(zh.launcherIconLabel(icon), isNotEmpty);
        expect(zh.launcherIconDescription(icon), isNotEmpty);
        expect(en.launcherIconLabel(icon), isNotEmpty);
        expect(en.launcherIconDescription(icon), isNotEmpty);
      }
      for (final format in NeoClockDateFormat.values) {
        expect(zh.clockDateFormatLabel(format), isNotEmpty);
        expect(zh.clockDateFormatDescription(format), isNotEmpty);
        expect(en.clockDateFormatLabel(format), isNotEmpty);
        expect(en.clockDateFormatDescription(format), isNotEmpty);
      }
      for (final mode in NeoThemeMode.values) {
        expect(zh.themeModeLabel(mode), isNotEmpty);
        expect(en.themeModeLabel(mode), isNotEmpty);
        expect(en.themeModeLabel(mode), isNot(zh.themeModeLabel(mode)));
      }
    });

    test('the calendar names a full week in both languages', () {
      for (final catalogue in <NeoStrings>[zh, en]) {
        expect(catalogue.calendarWeekdays, hasLength(7));
        expect(catalogue.calendarWeekdays.toSet(), hasLength(7));
        for (final day in catalogue.calendarWeekdays) {
          expect(day, isNotEmpty);
        }
      }
    });

    test('a month reads naturally in both languages', () {
      expect(zh.calendarMonthTitle(2026, 10), '2026 年 10 月');
      expect(en.calendarMonthTitle(2026, 10), 'October 2026');
      expect(en.calendarMonthTitle(2026, 1), 'January 2026');
      expect(en.calendarMonthTitle(2026, 12), 'December 2026');
    });

    test('meridiem markers differ per language', () {
      expect(zh.meridiem.am, '上午');
      expect(zh.meridiem.pm, '下午');
      expect(en.meridiem.am, 'AM');
      expect(en.meridiem.pm, 'PM');
    });

    test('a single unread notification is not pluralized in English', () {
      expect(en.unreadNotifications(1), '1 unread notification');
      expect(en.unreadNotifications(2), '2 unread notifications');
      expect(zh.unreadNotifications(2), '2 条未读通知');
      expect(en.launcherOpenWithCount(1), contains('1 window'));
      expect(en.launcherOpenWithCount(4), contains('4 windows'));
    });
  });
}
