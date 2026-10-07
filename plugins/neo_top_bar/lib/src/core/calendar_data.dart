/// A calendar month grid plus pure month arithmetic.
///
/// Kept free of Flutter imports so the date logic is unit-testable without a
/// widget environment.
library;

/// One cell of a month grid. [inMonth] is false for the leading/trailing days
/// borrowed from the previous/next month.
class NeoCalendarDay {
  const NeoCalendarDay({
    required this.date,
    required this.inMonth,
    required this.isToday,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
}

/// First day of the month containing [value], at midnight.
DateTime neoMonthStart(DateTime value) => DateTime(value.year, value.month, 1);

/// Adds [months] calendar months to the first of [value]'s month.
///
/// Dart's `~/` truncates toward zero, so a negative offset must use
/// [num.remainder] to keep the month in `1..12` instead of producing month 0 or
/// a negative month.
DateTime neoAddMonths(DateTime value, int months) {
  final zeroBased = value.month - 1 + months;
  final year = value.year + (zeroBased ~/ 12);
  final month = zeroBased.remainder(12);
  return DateTime(year, month + 1, 1);
}

/// Number of days in the month containing [value].
int neoDaysInMonth(DateTime value) =>
    DateTime(value.year, value.month + 1, 0).day;

/// Builds a six-row grid (42 cells) for the month containing [month].
///
/// [weekStartsOn] is the first weekday column: 1 for Monday (ISO) through 7 for
/// Sunday. The grid always starts on that column so month rows never shift.
List<NeoCalendarDay> neoBuildMonthGrid(
  DateTime month, {
  required DateTime today,
  int weekStartsOn = 1,
}) {
  assert(weekStartsOn >= 1 && weekStartsOn <= 7);
  final start = neoMonthStart(month);
  final offset = (start.weekday - weekStartsOn + 7) % 7;
  final first = start.subtract(Duration(days: offset));
  final todayDate = DateTime(today.year, today.month, today.day);
  return List<NeoCalendarDay>.generate(42, (index) {
    final date = first.add(Duration(days: index));
    return NeoCalendarDay(
      date: date,
      inMonth: date.month == start.month && date.year == start.year,
      isToday: date == todayDate,
    );
  }, growable: false);
}

/// Days in any month, indexed by `DateTime.month`.
const List<int> neoDaysPerMonth = <int>[
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];
