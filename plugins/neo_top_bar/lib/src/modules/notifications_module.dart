/// Desktop notifications: unread badge in the bar plus a history panel with
/// per-item dismissal, actions and a do-not-disturb toggle.
///
/// The data comes from Denial's public notification state; the bar never talks
/// to the notification daemon directly.
library;

import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_anchor.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_popup_surface.dart';

/// Upper bound on rows the panel renders at once.
const int _maxPanelEntries = 50;

class NotificationsModule implements NeoModule {
  const NotificationsModule();

  @override
  NeoModuleDescriptor get descriptor => notificationsModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _NotificationsContent(module: module);
}

class _NotificationsContent extends ConsumerWidget {
  const _NotificationsContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(desktopNotificationsProvider);
    final unread = state.unreadCount;
    final theme = ShellTheme.of(context);
    final active = state.active.length;
    final tooltip = unread > 0 ? '$unread 条未读通知' : '通知';

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: tooltip,
      onPressed: () =>
          _openPanel(context, ref, module, neoAnchorRectOf(context)),
      child: Center(
        // The card stretches to the strip's height, so the icon and its badge
        // keep their own box; otherwise the badge would anchor to the top of a
        // tall card instead of to the bell.
        child: SizedBox(
          width: 22,
          height: 20,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                active > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                size: 17,
                color: theme.colors.textPrimary,
              ),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: ShellText.systemBarCaption.copyWith(
                          color: theme.accentPalette.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openPanel(
  BuildContext context,
  WidgetRef ref,
  NeoModuleContext module,
  Rect? anchor,
) {
  ref
      .read(shellPopupControllerProvider.notifier)
      .show(
        keyName: 'neo_top_bar.notifications',
        debugLabel: 'NeoTopBar notifications',
        dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
        // No dimming scrim. The host's default is Denial's full-screen
        // overview scrim, which suits a large centered surface; a small card
        // attached to a bar icon reads as a context menu, and darkening the
        // whole desktop for it is far too heavy. Outside-tap and Escape still
        // dismiss because the barrier is transparent, not absent.
        barrierColor: Colors.transparent,
        builder: (_, handle) => NeoNotificationsPanel(
          services: module.services,
          monitorId: module.monitorId,
          anchor: anchor,
          onClose: handle.close,
        ),
      );
  // Opening the panel is the acknowledgement gesture, so unread marks clear.
  ref.read(desktopNotificationsProvider.notifier).markAllRead();
}

class NeoNotificationsPanel extends ConsumerWidget {
  const NeoNotificationsPanel({
    required this.services,
    required this.monitorId,
    required this.anchor,
    required this.onClose,
    super.key,
  });

  final ShellServices services;
  final int monitorId;

  /// Scene-space rectangle of the bell that opened this panel.
  final Rect? anchor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShellTheme.of(context);
    final state = ref.watch(desktopNotificationsProvider);
    final controller = ref.read(desktopNotificationsProvider.notifier);
    // Newest first, and bounded: history can grow without limit, and this panel
    // is a quick review surface rather than an archive browser.
    final records = state.history.reversed.take(_maxPanelEntries).toList();

    return NeoPopupSurface(
      services: services,
      monitorId: monitorId,
      anchor: anchor,
      maxWidth: 420,
      maxHeight: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '通知',
                  style: theme.text.systemBarValue.copyWith(fontSize: 15),
                ),
              ),
              NeoPopupIconButton(
                icon: state.doNotDisturb
                    ? Icons.do_not_disturb_on
                    : Icons.do_not_disturb_off_outlined,
                tooltip: state.doNotDisturb ? '关闭免打扰' : '开启免打扰',
                onPressed: controller.toggleDoNotDisturb,
              ),
              NeoPopupIconButton(
                icon: Icons.delete_sweep_outlined,
                tooltip: '全部清除',
                onPressed: records.isEmpty ? () {} : controller.clearAll,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  '没有通知',
                  style: theme.text.systemBarCaption.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: records.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 12, color: theme.colors.hairlineSoft),
                itemBuilder: (context, index) => _NotificationTile(
                  record: records[index],
                  controller: controller,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.record, required this.controller});

  final DesktopNotificationRecord record;
  final DesktopNotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final notification = record.notification;
    final urgencyColor = switch (notification.urgency) {
      DesktopNotificationUrgency.critical => theme.colors.textPrimary,
      DesktopNotificationUrgency.normal => theme.colors.textSecondary,
      DesktopNotificationUrgency.low => theme.colors.textTertiary,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const SizedBox(width: 6, height: 6),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.appName.isNotEmpty)
                Text(
                  notification.appName,
                  style: theme.text.systemBarCaption.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                notification.summary,
                style: theme.text.systemBarValue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (notification.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    notification.body,
                    style: theme.text.systemBarCaption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (notification.actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final action in notification.actions)
                        _NotificationActionChip(
                          label: action.label,
                          onPressed: () => controller.invokeAction(
                            notification.id,
                            action.key,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        NeoPopupIconButton(
          icon: Icons.close,
          tooltip: '忽略',
          onPressed: () => controller.dismissFromHistory(notification.id),
        ),
      ],
    );
  }
}

class _NotificationActionChip extends StatefulWidget {
  const _NotificationActionChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_NotificationActionChip> createState() =>
      _NotificationActionChipState();
}

class _NotificationActionChipState extends State<_NotificationActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? theme.colors.chip : theme.colors.tileOff,
            borderRadius: BorderRadius.circular(theme.chipRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(widget.label, style: theme.text.systemBarCaption),
          ),
        ),
      ),
    );
  }
}
