/// Date and ticking clock. Activating the card opens the calendar panel.
library;

import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
import 'calendar_panel.dart';

class ClockModule implements NeoModule {
  const ClockModule();

  @override
  NeoModuleDescriptor get descriptor => clockModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _ClockContent(module: module);
}

class _ClockContent extends ConsumerWidget {
  const _ClockContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = module.services.strings(context);
    final now = ref.watch(module.services.clock).value;
    final time = now == null ? null : strings.time(now);
    final date = now == null ? null : strings.shortDate(now);
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
