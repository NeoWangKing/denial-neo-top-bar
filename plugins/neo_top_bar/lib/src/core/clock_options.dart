/// Pure logic behind the clock module's settings.
///
/// A bar clock has to answer three questions — show the date at all, 24-hour or
/// not, and which date format — and the date format is the interesting one,
/// because "short" and "long" are not the same arrangement in every language.
/// Denial localizes two date templates (`shortDate` and `longDate`) whose part
/// *order* differs between locales: Chinese is `十月8日 星期四`, English is
/// `Thursday 8 October`. Hand-rolling either order would be wrong in the other
/// language, so instead the pattern is **read back out of the host's own
/// template** ([neoDatePatternFrom]) and the pieces are reassembled from it. The
/// only locale-specific thing this file invents is the AM/PM wording, and that is
/// chosen from the language code.
///
/// Kept free of Flutter so it is unit-testable — see `neo_top_bar_logic.dart`.
library;

/// Which pieces the clock's date shows.
enum NeoClockDateFormat {
  /// Month, day and weekday — what the bar shows by default.
  monthDayWeekday,

  /// Month and day only.
  monthDay,

  /// The weekday only.
  weekday,

  /// A numeric year-month-day, for when the year matters.
  ///
  /// Numeric rather than spelled out on purpose: no locale agrees on where the
  /// year goes in a written date, and `2026-10-08` is unambiguous everywhere.
  isoDate,
}

const List<NeoClockDateFormat> neoClockDateFormatOrder = <NeoClockDateFormat>[
  NeoClockDateFormat.monthDayWeekday,
  NeoClockDateFormat.monthDay,
  NeoClockDateFormat.weekday,
  NeoClockDateFormat.isoDate,
];

/// The unit a language writes after a month *number*, or an empty string when it
/// names its months instead.
///
/// This is what keeps the clock's date from mixing numeral systems. Denial
/// localizes month *names*, and languages that build those names out of a number
/// and a unit — 十月, 10月, 10월 — produce dates like `十月8日`, where a Chinese
/// numeral sits beside an Arabic one. The unit is recovered by finding the suffix
/// all twelve names share: every Chinese month ends in 月, so that is the unit,
/// while January, February and March share nothing, which is the signal that the
/// language names its months and that a bare `10` would read as nonsense.
String neoMonthUnitSuffix(List<String> monthNames) {
  if (monthNames.length < 12) return '';
  var suffix = monthNames.first;
  for (final name in monthNames.skip(1)) {
    suffix = _commonSuffix(suffix, name);
    if (suffix.isEmpty) return '';
  }
  // A shared suffix made of letters or digits is a spelling coincidence rather
  // than a unit, and using it would turn a month name into nonsense.
  if (RegExp(r'[A-Za-z0-9]').hasMatch(suffix)) return '';
  return suffix.trim();
}

String _commonSuffix(String left, String right) {
  var length = 0;
  while (length < left.length &&
      length < right.length &&
      left[left.length - 1 - length] == right[right.length - 1 - length]) {
    length++;
  }
  return left.substring(left.length - length);
}

/// The month written with Arabic numerals for [month], or null when this language
/// names its months and a number would read as nonsense.
String? neoNumericMonthLabel({
  required int month,
  required List<String> monthNames,
}) {
  final unit = neoMonthUnitSuffix(monthNames);
  if (unit.isEmpty) return null;
  return '$month$unit';
}

/// The option key holding whether the date is shown.
const String neoClockShowDateKey = 'showDate';

/// The option key holding whether the time is written in 24-hour form.
const String neoClockTwentyFourHourKey = 'twentyFourHour';

/// The option key holding the chosen [NeoClockDateFormat].
const String neoClockDateFormatKey = 'dateFormat';

/// The clock's stored settings, resolved against their defaults.
class NeoClockOptions {
  const NeoClockOptions({
    required this.showDate,
    required this.twentyFourHour,
    required this.dateFormat,
  });

  final bool showDate;
  final bool twentyFourHour;
  final NeoClockDateFormat dateFormat;

  @override
  String toString() =>
      'NeoClockOptions(date: $showDate, 24h: $twentyFourHour, '
      '${dateFormat.name})';
}

/// Resolves the stored settings, tolerating anything a hand-edited file holds.
NeoClockOptions neoClockOptions(Map<String, Object?> options) {
  final stored = options[neoClockDateFormatKey];
  var format = NeoClockDateFormat.monthDayWeekday;
  if (stored is String) {
    for (final candidate in NeoClockDateFormat.values) {
      if (candidate.name == stored) format = candidate;
    }
  }
  return NeoClockOptions(
    showDate: switch (options[neoClockShowDateKey]) {
      final bool value => value,
      _ => true,
    },
    twentyFourHour: switch (options[neoClockTwentyFourHourKey]) {
      final bool value => value,
      _ => true,
    },
    dateFormat: format,
  );
}

/// Which piece of a date a template puts where.
enum NeoDatePart { month, day, weekday }

/// How the host's date template arranges its pieces.
///
/// Read out of the localized template rather than assumed, so the clock can drop
/// or reorder pieces and still write a date the way the locale does.
class NeoDatePattern {
  const NeoDatePattern({
    required this.order,
    required this.separator,
    required this.daySuffix,
    required this.monthDaySeparator,
  });

  /// The pieces in template order.
  final List<NeoDatePart> order;

  /// What joins the date to the weekday.
  final String separator;

  /// What joins the month to the day.
  ///
  /// Empty in Chinese, where the day carries a suffix instead.
  final String monthDaySeparator;

  /// What follows the day number, e.g. `日` in Chinese.
  final String daySuffix;

  bool get monthFirst =>
      order.indexOf(NeoDatePart.month) < order.indexOf(NeoDatePart.day);
  bool get weekdayFirst =>
      order.indexOf(NeoDatePart.weekday) < order.indexOf(NeoDatePart.day);

  @override
  String toString() =>
      'NeoDatePattern(${order.map((part) => part.name).join('|')}, '
      'sep: "$separator", day: "$monthDaySeparator", suffix: "$daySuffix")';
}

/// What this file assumes when the template cannot be read.
///
/// Only reachable with a host that returns something unexpected, so it is written
/// in the plugin's own fallback language: Chinese, where the day carries a 日
/// suffix and the weekday trails the date. [neoFallbackDatePatternFor] has the
/// English arrangement for the other language.
const NeoDatePattern neoFallbackDatePattern = NeoDatePattern(
  order: <NeoDatePart>[NeoDatePart.month, NeoDatePart.day, NeoDatePart.weekday],
  separator: ' ',
  daySuffix: '日',
  monthDaySeparator: '',
);

/// The unreadable-template assumption for [languageCode].
///
/// English leads with the weekday and separates day from month with a space, so a
/// fallback built for Chinese would write `10月8日` to an English reader.
NeoDatePattern neoFallbackDatePatternFor(String languageCode) {
  if (languageCode.toLowerCase().startsWith('zh')) {
    return neoFallbackDatePattern;
  }
  return const NeoDatePattern(
    order: <NeoDatePart>[
      NeoDatePart.weekday,
      NeoDatePart.day,
      NeoDatePart.month,
    ],
    separator: ' ',
    daySuffix: '',
    monthDaySeparator: ' ',
  );
}

/// Reads the arrangement out of a localized date and the names it was built from.
///
/// [shortDate] is the host's own `shortDate` output for the same [day];
/// [monthName] and [weekdayName] are the localized names for that date. Removing
/// them leaves the separators and the day's suffix, which is exactly what the
/// clock needs to rebuild any subset of the date. [fallback] is returned when the
/// template cannot be read at all.
NeoDatePattern neoDatePatternFrom({
  required String shortDate,
  required String monthName,
  required String weekdayName,
  required int day,
  NeoDatePattern fallback = neoFallbackDatePattern,
}) {
  final text = shortDate;
  final monthAt = monthName.isEmpty ? -1 : text.indexOf(monthName);
  final weekdayAt = weekdayName.isEmpty ? -1 : text.indexOf(weekdayName);
  if (monthAt < 0 || weekdayAt < 0) return fallback;
  final monthFirst = monthAt < weekdayAt;

  // The date without the weekday: what is left between the two names, and the
  // whitespace that was cut away with it is the separator between them.
  final rawDate = monthFirst
      ? text.substring(monthAt, weekdayAt)
      : text.substring(weekdayAt + weekdayName.length, monthAt);
  final datePart = monthFirst ? rawDate.trimRight() : rawDate.trimLeft();
  final separator = monthFirst
      ? rawDate.substring(datePart.length)
      : rawDate.substring(0, rawDate.length - datePart.length);

  final dayAt = datePart.indexOf('$day');
  if (dayAt < 0) return fallback;

  String monthDaySeparator;
  String daySuffix;
  if (monthFirst) {
    // `十月8日` or `October 8`: the separator is what sits between the month name
    // and the number, the suffix what follows it.
    monthDaySeparator = datePart.substring(monthName.length, dayAt);
    daySuffix = datePart.substring(dayAt + '$day'.length);
  } else {
    // `8 October` or `8日10月`: after the number comes either a suffix or the
    // separator, never both — a space run is the separator.
    final rest = datePart.substring(dayAt + '$day'.length);
    if (rest.isEmpty) {
      monthDaySeparator = '';
      daySuffix = '';
    } else if (rest.startsWith(' ')) {
      monthDaySeparator = rest.substring(
        0,
        rest.length - rest.trimLeft().length,
      );
      daySuffix = '';
    } else {
      monthDaySeparator = '';
      daySuffix = rest.substring(0, rest.length - monthName.length);
    }
  }

  return NeoDatePattern(
    order: monthFirst
        ? const <NeoDatePart>[
            NeoDatePart.month,
            NeoDatePart.day,
            NeoDatePart.weekday,
          ]
        : const <NeoDatePart>[
            NeoDatePart.weekday,
            NeoDatePart.day,
            NeoDatePart.month,
          ],
    separator: separator.isEmpty ? ' ' : separator,
    daySuffix: daySuffix,
    // A separator is whitespace by definition; anything else glued to the day is
    // a suffix, which is how Chinese writes it.
    monthDaySeparator: monthDaySeparator.trim().isEmpty
        ? monthDaySeparator
        : ' ',
  );
}

/// Renders [format] using the names and pattern the host supplied.
String neoFormatClockDate({
  required NeoClockDateFormat format,
  required NeoDatePattern pattern,
  required String monthName,
  required String weekdayName,
  required int year,
  required int month,
  required int day,
}) {
  switch (format) {
    case NeoClockDateFormat.isoDate:
      final paddedMonth = month.toString().padLeft(2, '0');
      final paddedDay = day.toString().padLeft(2, '0');
      return '$year-$paddedMonth-$paddedDay';
    case NeoClockDateFormat.weekday:
      return weekdayName;
    case NeoClockDateFormat.monthDay:
      return _monthDay(pattern, monthName, day);
    case NeoClockDateFormat.monthDayWeekday:
      final date = _monthDay(pattern, monthName, day);
      return pattern.weekdayFirst
          ? '$weekdayName${pattern.separator}$date'
          : '$date${pattern.separator}$weekdayName';
  }
}

String _monthDay(NeoDatePattern pattern, String monthName, int day) =>
    pattern.monthFirst
    ? '$monthName${pattern.monthDaySeparator}$day${pattern.daySuffix}'
    : '$day${pattern.daySuffix}${pattern.monthDaySeparator}$monthName';

/// The AM/PM wording for [languageCode].
///
/// Denial's localization has no meridiem strings, so this is the one piece of
/// wording the plugin supplies itself. It lives here rather than in the string
/// catalogue because it is chosen from a language code alone, with no
/// `BuildContext` in reach. Denial only ships Chinese and English, so everything
/// that is not Chinese gets the Latin markers.
({String am, String pm}) neoMeridiemLabels(String languageCode) {
  final code = languageCode.toLowerCase();
  if (code.startsWith('zh')) return (am: '上午', pm: '下午');
  return (am: 'AM', pm: 'PM');
}

/// A 12-hour clock reading, e.g. `8:52 下午` or `8:52 AM`.
///
/// Midnight and noon are the two cases worth spelling out: 0 becomes 12 AM and 12
/// stays 12 PM, which is what every 12-hour clock does and what a naive `% 12`
/// gets wrong for midnight.
String neoFormatClockTime12(
  int hour,
  int minute, {
  required String amLabel,
  required String pmLabel,
}) {
  final isPm = hour >= 12;
  final twelve = switch (hour % 12) {
    0 => 12,
    final value => value,
  };
  final paddedMinute = minute.toString().padLeft(2, '0');
  return '$twelve:$paddedMinute ${isPm ? pmLabel : amLabel}';
}
