/// The calendar panel shown when the clock is activated.
library;

import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar_data.dart';
import '../core/l10n_context.dart';
import '../core/module.dart';
import '../widgets/neo_popup_surface.dart';

/// Opens the calendar panel centered on the bar's output.
///
/// [keyName] makes a second activation focus the existing panel instead of
/// stacking another copy.
void openNeoCalendarPanel(
  BuildContext context,
  WidgetRef ref,
  NeoModuleContext module,
  Rect? anchor,
) {
  ref
      .read(shellPopupControllerProvider.notifier)
      .show(
        keyName: 'neo_top_bar.calendar',
        debugLabel: 'NeoTopBar calendar',
        dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
        // No dimming scrim. The host's default is Denial's full-screen
        // overview scrim, which suits a large centered surface; a small card
        // attached to a bar icon reads as a context menu, and darkening the
        // whole desktop for it is far too heavy. Outside-tap and Escape still
        // dismiss because the barrier is transparent, not absent.
        barrierColor: Colors.transparent,
        builder: (_, handle) => NeoCalendarPanel(
          services: module.services,
          monitorId: module.monitorId,
          anchor: anchor,
          onClose: handle.close,
        ),
      );
}

class NeoCalendarPanel extends ConsumerStatefulWidget {
  const NeoCalendarPanel({
    required this.services,
    required this.monitorId,
    required this.anchor,
    required this.onClose,
    super.key,
  });

  final ShellServices services;
  final int monitorId;

  /// Scene-space rectangle of the clock that opened this panel.
  final Rect? anchor;
  final VoidCallback onClose;

  @override
  ConsumerState<NeoCalendarPanel> createState() => _NeoCalendarPanelState();
}

class _NeoCalendarPanelState extends ConsumerState<NeoCalendarPanel> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final s = context.neoStrings;
    final theme = ShellTheme.of(context);
    final now = ref.watch(widget.services.clock).value ?? DateTime.now();
    final month = _month ?? neoMonthStart(now);
    final days = neoBuildMonthGrid(month, today: now);

    return NeoPopupSurface(
      services: widget.services,
      monitorId: widget.monitorId,
      anchor: widget.anchor,
      maxWidth: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.calendarMonthTitle(month.year, month.month),
                  style: theme.text.systemBarValue.copyWith(fontSize: 15),
                ),
              ),
              NeoPopupIconButton(
                icon: Icons.chevron_left,
                tooltip: s.previousMonth,
                onPressed: () =>
                    setState(() => _month = neoAddMonths(month, -1)),
              ),
              NeoPopupIconButton(
                icon: Icons.chevron_right,
                tooltip: s.nextMonth,
                onPressed: () =>
                    setState(() => _month = neoAddMonths(month, 1)),
              ),
              NeoPopupIconButton(
                icon: Icons.today,
                tooltip: s.backToToday,
                onPressed: () =>
                    setState(() => _month = neoMonthStart(DateTime.now())),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final label in s.calendarWeekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: theme.text.systemBarCaption.copyWith(
                        color: theme.colors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _CalendarCell(
                      day: days[week * 7 + weekday],
                      accent: theme.accent,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.day, required this.accent});

  final NeoCalendarDay day;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final color = !day.inMonth
        ? theme.colors.textTertiary.withValues(alpha: 0.55)
        : day.isToday
        ? theme.accentPalette.onPrimary
        : theme.colors.textPrimary;
    return SizedBox(
      height: 30,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: day.isToday ? accent : null,
            borderRadius: BorderRadius.circular(theme.roundButtonRadius),
          ),
          child: SizedBox(
            width: 28,
            height: 24,
            child: Center(
              child: Text(
                '${day.date.day}',
                style: theme.text.systemBarValue.copyWith(
                  color: color,
                  fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
