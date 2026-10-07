/// Tests for the clock module's settings rules.
///
/// The date formats are the interesting part: the arrangement of month, day and
/// weekday differs between languages, so the pattern is read out of the host's
/// own template and the pieces are put back together from it. Both real
/// templates — Chinese and English — are exercised here.
library;

import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

/// The Chinese template: `十月8日 星期四`.
const NeoDatePattern _zh = NeoDatePattern(
  order: <NeoDatePart>[NeoDatePart.month, NeoDatePart.day, NeoDatePart.weekday],
  separator: ' ',
  daySuffix: '日',
  monthDaySeparator: '',
);

/// The English one: `Thursday 8 October`.
const NeoDatePattern _en = NeoDatePattern(
  order: <NeoDatePart>[NeoDatePart.weekday, NeoDatePart.day, NeoDatePart.month],
  separator: ' ',
  daySuffix: '',
  monthDaySeparator: ' ',
);

void main() {
  group('neoClockOptions', () {
    test('defaults to date, 24-hour, month-day-weekday', () {
      final options = neoClockOptions(const <String, Object?>{});
      expect(options.showDate, isTrue);
      expect(options.twentyFourHour, isTrue);
      expect(options.dateFormat, NeoClockDateFormat.monthDayWeekday);
    });

    test('reads stored choices', () {
      final options = neoClockOptions(<String, Object?>{
        'showDate': false,
        'twentyFourHour': false,
        'dateFormat': 'isoDate',
      });
      expect(options.showDate, isFalse);
      expect(options.twentyFourHour, isFalse);
      expect(options.dateFormat, NeoClockDateFormat.isoDate);
    });

    test('unknown names and wrong types fall back, not throw', () {
      expect(
        neoClockOptions(const <String, Object?>{'dateFormat': 'martian'})
            .dateFormat,
        NeoClockDateFormat.monthDayWeekday,
      );
      expect(
        neoClockOptions(const <String, Object?>{'dateFormat': 3}).dateFormat,
        NeoClockDateFormat.monthDayWeekday,
      );
      expect(
        neoClockOptions(const <String, Object?>{'showDate': 'yes'}).showDate,
        isTrue,
      );
      expect(
        neoClockOptions(const <String, Object?>{'twentyFourHour': 0})
            .twentyFourHour,
        isTrue,
      );
    });

    test('every format has a label and a description', () {
      for (final format in NeoClockDateFormat.values) {
        expect(
          const NeoStrings(NeoLanguage.zh).clockDateFormatLabel(format),
          isNotEmpty,
        );
        expect(
          const NeoStrings(NeoLanguage.zh).clockDateFormatDescription(format),
          isNotEmpty,
        );
        expect(
          const NeoStrings(NeoLanguage.en).clockDateFormatLabel(format),
          isNot(const NeoStrings(NeoLanguage.zh).clockDateFormatLabel(format)),
        );
      }
      expect(
        neoClockDateFormatOrder.toSet(),
        NeoClockDateFormat.values.toSet(),
      );
    });
  });

  group('month numerals', () {
    const zh = <String>[
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月',
    ];
    const ja = <String>[
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    const en = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    test('finds the unit in languages that number their months', () {
      expect(neoMonthUnitSuffix(zh), '月');
      expect(neoMonthUnitSuffix(ja), '月');
      expect(
        neoMonthUnitSuffix(<String>[
          '1월',
          '2월',
          '3월',
          '4월',
          '5월',
          '6월',
          '7월',
          '8월',
          '9월',
          '10월',
          '11월',
          '12월',
        ]),
        '월',
      );
    });

    test('finds no unit where months are named', () {
      // January, February and March share nothing, which is the signal that a
      // bare number would be meaningless.
      expect(neoMonthUnitSuffix(en), '');
    });

    test(
      'builds the numeric label where there is a unit, and refuses elsewhere',
      () {
        expect(neoNumericMonthLabel(month: 10, monthNames: zh), '10月');
        expect(neoNumericMonthLabel(month: 1, monthNames: zh), '1月');
        expect(neoNumericMonthLabel(month: 10, monthNames: en), isNull);
      },
    );

    test('an incomplete or empty list is not a unit', () {
      expect(neoMonthUnitSuffix(const <String>[]), '');
      expect(neoMonthUnitSuffix(const <String>['一月', '二月']), '');
    });
  });

  group('neoDatePatternFrom', () {
    test('reads the Chinese template', () {
      final pattern = neoDatePatternFrom(
        shortDate: '十月8日 星期四',
        monthName: '十月',
        weekdayName: '星期四',
        day: 8,
      );
      expect(pattern.monthFirst, isTrue);
      expect(pattern.weekdayFirst, isFalse);
      expect(pattern.separator, ' ');
      expect(pattern.daySuffix, '日');
      expect(pattern.monthDaySeparator, '');
    });

    test('reads the English template', () {
      final pattern = neoDatePatternFrom(
        shortDate: 'Thursday 8 October',
        monthName: 'October',
        weekdayName: 'Thursday',
        day: 8,
      );
      expect(pattern.monthFirst, isFalse);
      expect(pattern.weekdayFirst, isTrue);
      expect(pattern.separator, ' ');
      expect(pattern.daySuffix, '');
      expect(pattern.monthDaySeparator, ' ');
    });

    test('reads a day-first template with a suffix', () {
      // Japanese: `10月8日 木曜日`.
      final pattern = neoDatePatternFrom(
        shortDate: '10月8日 木曜日',
        monthName: '10月',
        weekdayName: '木曜日',
        day: 8,
      );
      expect(pattern.monthFirst, isTrue);
      expect(pattern.daySuffix, '日');
      expect(pattern.monthDaySeparator, '');
    });

    test('an unreadable template falls back instead of guessing', () {
      expect(
        neoDatePatternFrom(
          shortDate: '???',
          monthName: '十月',
          weekdayName: '星期四',
          day: 8,
        ),
        neoFallbackDatePattern,
      );
      expect(
        neoDatePatternFrom(
          shortDate: '十月9日 星期四',
          monthName: '十月',
          weekdayName: '星期四',
          day: 8,
        ),
        neoFallbackDatePattern,
      );
    });
  });

  group('neoFormatClockDate', () {
    String format(
      NeoClockDateFormat value, {
      NeoDatePattern pattern = _zh,
      String monthName = '十月',
      String weekdayName = '星期四',
      int year = 2026,
      int month = 10,
      int day = 8,
    }) => neoFormatClockDate(
      format: value,
      pattern: pattern,
      monthName: monthName,
      weekdayName: weekdayName,
      year: year,
      month: month,
      day: day,
    );

    test('Chinese arrangements, with an Arabic month number', () {
      // The month label is `10月` rather than `十月`, so nothing in the date
      // mixes numeral systems.
      const monthLabel = '10月';
      expect(
        format(NeoClockDateFormat.monthDayWeekday, monthName: monthLabel),
        '10月8日 星期四',
      );
      expect(
        format(NeoClockDateFormat.monthDay, monthName: monthLabel),
        '10月8日',
      );
      expect(format(NeoClockDateFormat.weekday, monthName: monthLabel), '星期四');
      expect(
        format(NeoClockDateFormat.isoDate, monthName: monthLabel),
        '2026-10-08',
      );
    });

    test('English arrangements follow the English order', () {
      expect(
        format(
          NeoClockDateFormat.monthDayWeekday,
          pattern: _en,
          monthName: 'October',
          weekdayName: 'Thursday',
        ),
        'Thursday 8 October',
      );
      expect(
        format(
          NeoClockDateFormat.monthDay,
          pattern: _en,
          monthName: 'October',
          weekdayName: 'Thursday',
        ),
        '8 October',
      );
      expect(
        format(
          NeoClockDateFormat.weekday,
          pattern: _en,
          monthName: 'October',
          weekdayName: 'Thursday',
        ),
        'Thursday',
      );
    });

    test('the numeric form pads and never uses names', () {
      expect(
        format(
          NeoClockDateFormat.isoDate,
          month: 1,
          day: 2,
          monthName: '一月',
          weekdayName: '星期五',
        ),
        '2026-01-02',
      );
    });
  });

  group('clock time', () {
    test('meridiem wording follows the language', () {
      expect(neoMeridiemLabels('zh').am, '上午');
      expect(neoMeridiemLabels('zh_CN').pm, '下午');
      // Denial ships only these two, so any third tag reads as English.
      expect(neoMeridiemLabels('ja').am, 'AM');
      expect(neoMeridiemLabels('en').am, 'AM');
      expect(neoMeridiemLabels('de').pm, 'PM');
    });

    test('twelve-hour readings, including midnight and noon', () {
      const am = 'AM';
      const pm = 'PM';
      String at(int hour, int minute) =>
          neoFormatClockTime12(hour, minute, amLabel: am, pmLabel: pm);
      expect(at(0, 5), '12:05 AM');
      expect(at(1, 9), '1:09 AM');
      expect(at(11, 59), '11:59 AM');
      expect(at(12, 0), '12:00 PM');
      expect(at(13, 30), '1:30 PM');
      expect(at(23, 7), '11:07 PM');
    });
  });
}
