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

String neoClockDateFormatLabel(NeoClockDateFormat format) => switch (format) {
  NeoClockDateFormat.monthDayWeekday => '月日 + 星期',
  NeoClockDateFormat.monthDay => '只要月日',
  NeoClockDateFormat.weekday => '只要星期',
  NeoClockDateFormat.isoDate => '数字日期',
};

String neoClockDateFormatDescription(NeoClockDateFormat format) =>
    switch (format) {
      NeoClockDateFormat.monthDayWeekday => '和 Denial 自带顶栏一样，例如「十月8日 星期四」',
      NeoClockDateFormat.monthDay => '更短，例如「十月8日」',
      NeoClockDateFormat.weekday => '最短，例如「星期四」',
      NeoClockDateFormat.isoDate => '带年份、任何语言下都不会歧义，例如「2026-10-08」',
    };

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
/// Only reachable with a host that returns something unexpected; it matches the
/// Chinese template, which is what this plugin's own strings are written in.
const NeoDatePattern neoFallbackDatePattern = NeoDatePattern(
  order: <NeoDatePart>[NeoDatePart.month, NeoDatePart.day, NeoDatePart.weekday],
  separator: ' ',
  daySuffix: '日',
  monthDaySeparator: '',
);

/// Reads the arrangement out of a localized date and the names it was built from.
///
/// [shortDate] is the host's own `shortDate` output for the same [day];
/// [monthName] and [weekdayName] are the localized names for that date. Removing
/// them leaves the separators and the day's suffix, which is exactly what the
/// clock needs to rebuild any subset of the date.
NeoDatePattern neoDatePatternFrom({
  required String shortDate,
  required String monthName,
  required String weekdayName,
  required int day,
}) {
  final text = shortDate;
  final monthAt = monthName.isEmpty ? -1 : text.indexOf(monthName);
  final weekdayAt = weekdayName.isEmpty ? -1 : text.indexOf(weekdayName);
  if (monthAt < 0 || weekdayAt < 0) return neoFallbackDatePattern;
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
  if (dayAt < 0) return neoFallbackDatePattern;

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
/// wording the plugin supplies itself. Languages that write a 12-hour clock in
/// their own words get them; everything else gets the Latin markers, which are
/// understood nearly everywhere.
({String am, String pm}) neoMeridiemLabels(String languageCode) {
  final code = languageCode.toLowerCase();
  if (code.startsWith('zh')) return (am: '上午', pm: '下午');
  if (code.startsWith('ja')) return (am: '午前', pm: '午後');
  if (code.startsWith('ko')) return (am: '오전', pm: '오후');
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
