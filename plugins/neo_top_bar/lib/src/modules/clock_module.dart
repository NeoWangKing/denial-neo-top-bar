/// Date and ticking clock. Activating the card opens the calendar panel.
library;

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock_options.dart';
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
    final strings = module.services.strings(context);
    final now = ref.watch(module.services.clock).value;
    final options = neoClockOptions(module.options);
    final time = now == null ? null : _timeText(context, strings, now, options);
    final date = now == null || !options.showDate
        ? null
        : neoFormatClockDate(
            format: options.dateFormat,
            pattern: _patternOf(context, strings, now),
            monthName: localizedMonth(context.l10n, now.month),
            weekdayName: localizedWeekday(context.l10n, now.weekday),
            year: now.year,
            month: now.month,
            day: now.day,
          );
    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: '打开日历',
      onPressed: () =>
          openNeoCalendarPanel(context, ref, module, neoAnchorRectOf(context)),
      child: Row(
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
    final options = neoClockOptions(scope.options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoSettingGroup(
          title: '时间',
          children: [
            NeoSettingRow(
              label: '24 小时制',
              description: options.twentyFourHour
                  ? '例如 20:52'
                  : '例如 ${neoFormatClockTime12(20, 52, amLabel: neoMeridiemLabels(_languageCode(context)).am, pmLabel: neoMeridiemLabels(_languageCode(context)).pm)}',
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
          title: '日期',
          children: [
            NeoSettingRow(
              label: '显示日期',
              description: '关掉之后胶囊上只剩时间',
              child: NeoSettingToggle(
                value: options.showDate,
                onChanged: (value) =>
                    scope.setOption(neoClockShowDateKey, value),
              ),
            ),
            if (options.showDate)
              NeoSettingRow(
                label: '日期格式',
                description: neoClockDateFormatDescription(options.dateFormat),
                child: NeoSettingChips<NeoClockDateFormat>(
                  values: <NeoClockDateFormat, String>{
                    for (final format in neoClockDateFormatOrder)
                      format: neoClockDateFormatLabel(format),
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
  final labels = neoMeridiemLabels(_languageCode(context));
  return neoFormatClockTime12(
    now.hour,
    now.minute,
    amLabel: labels.am,
    pmLabel: labels.pm,
  );
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
);
