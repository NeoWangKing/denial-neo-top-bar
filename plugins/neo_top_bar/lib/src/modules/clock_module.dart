/// Date and ticking clock. Activating the card opens the calendar panel.
library;

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock_options.dart';
import '../core/l10n_context.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_setting_controls.dart';
import 'calendar_panel.dart';

class ClockModule implements NeoModule, NeoModuleSettings {
  const ClockModule();

  @override
  NeoModuleDescriptor get descriptor => clockModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _ClockContent(module: module);

  @override
  Widget buildSettings(BuildContext context, NeoModuleSettingsScope scope) =>
      _ClockSettings(scope: scope);
}

class _ClockContent extends ConsumerWidget {
  const _ClockContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.neoStrings;
    final strings = module.services.strings(context);
    final now = ref.watch(module.services.clock).value;
    final options = neoClockOptions(module.options);
    final time = now == null ? null : _timeText(context, strings, now, options);
    final date = now == null || !options.showDate
        ? null
        : neoFormatClockDate(
            format: options.dateFormat,
            pattern: _patternOf(context, strings, now),
            // A number where the language numbers its months, its name otherwise:
            // `十月8日` mixes a Chinese numeral with an Arabic one.
            monthName: _monthLabel(context, now.month),
            weekdayName: localizedWeekday(context.l10n, now.weekday),
            year: now.year,
            month: now.month,
            day: now.day,
          );
    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: s.clockOpenCalendar,
      onPressed: () =>
          openNeoCalendarPanel(context, ref, module, neoAnchorRectOf(context)),
      child: module.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (date != null) ...[
                  Text(
                    date,
                    style: ShellText.systemBarCaption.copyWith(
                      color: module.accent.captionColor(ShellTheme.of(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (time != null)
                  Text(time, style: ShellText.systemBarValue)
                else
                  const SizedBox(width: 42, height: 14),
              ],
            )
          // A vertical pill is about 33px of usable width, which fits the time
          // (`20:52` is already ~34px before scaling) and nothing more, so the
          // date is dropped rather than wrapped: the calendar is one tap away,
          // and a shrunken date caption would be unreadable anyway. The date is
          // picked back up on a bar that has room for it.
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (time != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(time, style: ShellText.systemBarValue),
                  )
                else
                  const SizedBox(width: 42, height: 14),
              ],
            ),
    );
  }
}

/// The clock's own settings: how much of the date to show, and how to write the
/// time.
class _ClockSettings extends StatelessWidget {
  const _ClockSettings({required this.scope});

  final NeoModuleSettingsScope scope;

  @override
  Widget build(BuildContext context) {
    final s = context.neoStrings;
    final options = neoClockOptions(scope.options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoSettingGroup(
          title: s.clockTime,
          children: [
            NeoSettingRow(
              label: s.clockUse24Hour,
              description: options.twentyFourHour
                  ? s.clockTimeExample24('20:52')
                  : s.clockTimeExample(
                      neoFormatClockTime12(
                        20,
                        52,
                        amLabel: s.meridiem.am,
                        pmLabel: s.meridiem.pm,
                      ),
                    ),
              child: NeoSettingToggle(
                value: options.twentyFourHour,
                onChanged: (value) =>
                    scope.setOption(neoClockTwentyFourHourKey, value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        NeoSettingGroup(
          title: s.clockDate,
          children: [
            NeoSettingRow(
              label: s.clockShowDate,
              description: s.clockShowDateHint,
              child: NeoSettingToggle(
                value: options.showDate,
                onChanged: (value) =>
                    scope.setOption(neoClockShowDateKey, value),
              ),
            ),
            if (options.showDate)
              NeoSettingRow(
                label: s.clockDateFormat,
                description: s.clockDateFormatDescription(options.dateFormat),
                // Four chips need the row's whole width once the card is a popup.
                fit: NeoSettingRowFit.under,
                child: NeoSettingChips<NeoClockDateFormat>(
                  values: <NeoClockDateFormat, String>{
                    for (final format in neoClockDateFormatOrder)
                      format: s.clockDateFormatLabel(format),
                  },
                  selected: options.dateFormat,
                  onSelected: (format) =>
                      scope.setOption(neoClockDateFormatKey, format.name),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The shell's language, for the one piece of wording this plugin supplies.
String _languageCode(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

/// The 12-hour form needs meridiem wording the host does not localize.
String _timeText(
  BuildContext context,
  ShellStrings strings,
  DateTime now,
  NeoClockOptions options,
) {
  if (options.twentyFourHour) return strings.time(now);
  final labels = context.neoStrings.meridiem;
  return neoFormatClockTime12(
    now.hour,
    now.minute,
    amLabel: labels.am,
    pmLabel: labels.pm,
  );
}

/// The month as the clock should write it.
///
/// Languages that number their months get `10月`; languages that name them get
/// the name, because `10` alone would not read as a month. See
/// [neoNumericMonthLabel] for how the unit is recovered.
String _monthLabel(BuildContext context, int month) {
  final l10n = context.l10n;
  return neoNumericMonthLabel(
        month: month,
        monthNames: <String>[
          for (var index = 1; index <= 12; index++) localizedMonth(l10n, index),
        ],
      ) ??
      localizedMonth(l10n, month);
}

/// How this locale arranges a date, read from the host's own template.
///
/// The template is asked for the same day the clock is showing, then the names
/// are taken back out of it — see [neoDatePatternFrom]. Reading it rather than
/// hardcoding the order is what makes "month-day only" come out as `十月8日` in
/// Chinese and `8 October` in English.
NeoDatePattern _patternOf(
  BuildContext context,
  ShellStrings strings,
  DateTime now,
) => neoDatePatternFrom(
  shortDate: strings.shortDate(now),
  monthName: localizedMonth(context.l10n, now.month),
  weekdayName: localizedWeekday(context.l10n, now.weekday),
  day: now.day,
  fallback: neoFallbackDatePatternFor(_languageCode(context)),
);
