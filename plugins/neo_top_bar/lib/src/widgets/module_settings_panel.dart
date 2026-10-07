/// Module settings panel: enable/disable every known module, move it between the
/// bar's zones, and set the bar's spacing.
///
/// Denial's Settings app cannot host plugin pages, and the plugin SDK has no API
/// for opening a separate native window, so this is a large **centered** popup
/// card: Denial's own detail-popup mechanism, scaled up to read as a window.
/// Order inside one zone is not shown here; the JSON file remains the precise
/// ordering surface.
library;

import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/config_state.dart';
import '../core/module_descriptor.dart';
import '../core/module_registry.dart';
import 'neo_popup_surface.dart';

/// Opens the settings card, centered in the bar's output.
///
/// No anchor is passed: unlike the notification and calendar panels, this one is
/// a deliberate configuration surface rather than a menu attached to a control,
/// so it belongs in the middle of the screen where it has room to lay out.
void openModuleSettingsPanel({
  required BuildContext context,
  required NeoTopBarConfigState state,
  required ShellServices services,
  required int monitorId,
}) {
  final ref = ProviderScope.containerOf(context, listen: false);
  ref
      .read(shellPopupControllerProvider.notifier)
      .show(
        keyName: 'neo_top_bar.settings',
        debugLabel: 'NeoTopBar settings',
        dismissPolicy: ShellDismissPolicy.outsideTapAndEscape,
        // No dimming scrim. Outside-tap and Escape still dismiss because the
        // barrier is transparent, not absent.
        barrierColor: Colors.transparent,
        builder: (context, handle) => NeoModuleSettingsPanel(
          state: state,
          services: services,
          monitorId: monitorId,
          onClose: handle.close,
        ),
      );
}

class NeoModuleSettingsPanel extends StatelessWidget {
  const NeoModuleSettingsPanel({
    required this.state,
    required this.services,
    required this.monitorId,
    required this.onClose,
    super.key,
  });

  final NeoTopBarConfigState state;
  final ShellServices services;
  final int monitorId;
  final VoidCallback onClose;

  /// Sized to read as a window while still fitting Denial's dialog conventions.
  static const double _width = 760;
  static const double _height = 720;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final descriptors = NeoTopBarModules.descriptors;
        final placements = resolvePlacements(
          descriptors: descriptors,
          config: state.config,
        );
        // Grouped by zone, because reordering only ever happens inside one zone.
        final byZone = <NeoZone, List<NeoModulePlacement>>{};
        for (final placement in placements) {
          (byZone[placement.zone] ??= <NeoModulePlacement>[]).add(placement);
        }
        return NeoPopupSurface(
          services: services,
          monitorId: monitorId,
          maxWidth: _width,
          maxHeight: _height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '顶栏组件',
                      style: theme.text.systemBarValue.copyWith(fontSize: 18),
                    ),
                  ),
                  NeoPopupIconButton(
                    icon: Icons.close,
                    tooltip: '关闭',
                    onPressed: onClose,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  '开关组件，选择它停在左 / 中 / 右哪一段，'
                  '再用每行的 ↑ ↓ 调整同一区内的先后顺序'
                  '（列表越靠上，在横栏上越靠左）。',
                  style: theme.text.systemBarCaption.copyWith(
                    color: theme.colors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ),
              _DensityRow(state: state),
              const SizedBox(height: 10),
              Divider(height: 1, color: theme.colors.hairlineSoft),
              if (state.loadError case final error?)
                _PanelMessage(
                  color: theme.colors.textPrimary,
                  text: '读取配置失败，正在使用默认值：$error',
                ),
              if (state.saveError case final error?)
                _PanelMessage(
                  color: theme.colors.textPrimary,
                  text: '保存配置失败：$error',
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final zone in NeoZone.values)
                      if (byZone[zone] case final rows?
                          when rows.isNotEmpty) ...[
                        _ZoneHeader(zone: zone, count: rows.length),
                        for (var index = 0; index < rows.length; index++)
                          _ModuleRow(
                            placement: rows[index],
                            state: state,
                            descriptors: descriptors,
                            // Reordering is per zone, so the buttons are only
                            // live where a move is actually possible.
                            canMoveUp: index > 0,
                            canMoveDown: index < rows.length - 1,
                          ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.tileOff,
          borderRadius: BorderRadius.circular(theme.chipRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            text,
            style: theme.text.systemBarCaption.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

/// One module: title and controls on one line, the description on its own full
/// width line below.
///
/// The description used to share the row with the controls, which squeezed it
/// into a clipped two-line column. Giving it the full width keeps it to one line
/// at this panel size and lets the row size itself naturally.
class _ZoneHeader extends StatelessWidget {
  const _ZoneHeader({required this.zone, required this.count});

  final NeoZone zone;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(
        children: [
          Text(
            zone.label,
            style: theme.text.systemBarValue.copyWith(
              fontSize: 13,
              color: theme.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: theme.colors.hairlineSoft)),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.placement,
    required this.state,
    required this.descriptors,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final NeoModulePlacement placement;
  final NeoTopBarConfigState state;
  final Iterable<NeoModuleDescriptor> descriptors;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final descriptor = placement.descriptor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descriptor.label,
                  style: theme.text.systemBarValue.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              _MoveButton(
                icon: Icons.keyboard_arrow_up,
                tooltip: '在本区内前移',
                onPressed: canMoveUp
                    ? () => state.move(
                        descriptor.id,
                        offset: -1,
                        descriptors: descriptors,
                      )
                    : null,
              ),
              _MoveButton(
                icon: Icons.keyboard_arrow_down,
                tooltip: '在本区内后移',
                onPressed: canMoveDown
                    ? () => state.move(
                        descriptor.id,
                        offset: 1,
                        descriptors: descriptors,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              _ZoneSelector(
                zone: placement.zone,
                onChanged: (zone) => state.setZone(
                  descriptor.id,
                  zone: zone,
                  defaultZone: descriptor.zone,
                ),
              ),
              const SizedBox(width: 10),
              _Toggle(
                value: placement.enabled,
                onChanged: (value) =>
                    state.setEnabled(descriptor.id, enabled: value),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            descriptor.description,
            style: theme.text.systemBarCaption.copyWith(
              color: theme.colors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar-wide spacing control.
class _DensityRow extends StatelessWidget {
  const _DensityRow({required this.state});

  final NeoTopBarConfigState state;

  static const Map<NeoDensity, String> _labels = <NeoDensity, String>{
    NeoDensity.compact: '紧凑',
    NeoDensity.regular: '标准',
    NeoDensity.comfortable: '宽松',
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '间距',
            style: theme.text.systemBarValue.copyWith(fontSize: 14),
          ),
        ),
        _Segmented<NeoDensity>(
          values: _labels,
          selected: state.config.density,
          onSelected: state.setDensity,
        ),
      ],
    );
  }
}

/// One reorder step. A null [onPressed] disables it at a zone boundary, so the
/// button never looks live when a move would do nothing.
class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: tooltip,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.tileOff.withValues(
                  alpha: enabled ? 1.0 : 0.45,
                ),
                borderRadius: BorderRadius.circular(theme.chipRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled
                      ? theme.colors.textPrimary
                      : theme.colors.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoneSelector extends StatelessWidget {
  const _ZoneSelector({required this.zone, required this.onChanged});

  final NeoZone zone;
  final ValueChanged<NeoZone> onChanged;

  static const Map<NeoZone, String> _labels = <NeoZone, String>{
    NeoZone.start: '左',
    NeoZone.center: '中',
    NeoZone.end: '右',
  };

  @override
  Widget build(BuildContext context) => _Segmented<NeoZone>(
    values: _labels,
    selected: zone,
    onSelected: onChanged,
  );
}

/// A small segmented control. Used for the per-module zone and the bar-wide
/// spacing, so both stay visually identical.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final Map<T, String> values;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.tileOff,
        borderRadius: BorderRadius.circular(theme.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in values.entries)
            _SegmentButton(
              label: entry.value,
              selected: entry.key == selected,
              onPressed: () => onSelected(entry.key),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? theme.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(theme.chipRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  label,
                  style: theme.text.systemBarCaption.copyWith(
                    fontSize: 12,
                    color: selected
                        ? theme.accentPalette.onPrimary
                        : theme.colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Semantics(
      toggled: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44,
            height: 24,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? theme.accent : theme.colors.tileOff,
              borderRadius: BorderRadius.circular(999),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: value
                    ? theme.accentPalette.onPrimary
                    : theme.colors.textTertiary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const SizedBox(width: 18, height: 18),
            ),
          ),
        ),
      ),
    );
  }
}
