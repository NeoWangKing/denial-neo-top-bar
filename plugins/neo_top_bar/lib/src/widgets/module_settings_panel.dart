/// Module settings panel: enable/disable every known module, move it between the
/// bar's zones, reorder it inside its zone, set the bar's spacing, and edit
/// whatever a module wants to expose about itself.
///
/// Denial's Settings app cannot host plugin pages, and the plugin SDK has no API
/// for opening a separate native window, so this is a large **centered** popup
/// card: Denial's own detail-popup mechanism, scaled up to read as a window.
///
/// Each module gets one row plus an expandable area. The row carries only what
/// every module has — its name, its description and its on/off switch — and the
/// expansion carries the placement controls and the module's own settings. That
/// split exists because the previous single-line row was already full: name,
/// reorder, zone and toggle left nowhere for a module like the control centre to
/// put its own options, and adding them to the row would have made it unusable.
library;

import 'package:denial_flutter_sdk/popups.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/config_state.dart';
import '../core/module.dart';
import '../core/module_descriptor.dart';
import '../core/module_registry.dart';
import 'neo_popup_surface.dart';
import 'neo_setting_controls.dart';

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
  ///
  /// Wider than the rows need on purpose: an expanded module lays its settings
  /// out in two columns, which only reads well with room to spare.
  static const double _width = 820;
  static const double _height = 760;

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
                  '开关组件；点每行右侧的「设置」展开它的位置、顺序'
                  '和它自己的选项（列表越靠上，在横栏上越靠左）。',
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
                            services: services,
                            monitorId: monitorId,
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

/// One module: its identity and on/off switch, then an expandable area holding
/// its placement controls and its own settings.
class _ModuleRow extends StatefulWidget {
  const _ModuleRow({
    required this.placement,
    required this.state,
    required this.descriptors,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.services,
    required this.monitorId,
  });

  final NeoModulePlacement placement;
  final NeoTopBarConfigState state;
  final Iterable<NeoModuleDescriptor> descriptors;
  final bool canMoveUp;
  final bool canMoveDown;
  final ShellServices services;
  final int monitorId;

  @override
  State<_ModuleRow> createState() => _ModuleRowState();
}

class _ModuleRowState extends State<_ModuleRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final descriptor = widget.placement.descriptor;
    final module = NeoTopBarModules.byId(descriptor.id);
    final configurable = module is NeoModuleSettings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descriptor.label,
                  style: theme.text.systemBarValue.copyWith(
                    fontSize: 14,
                    color: widget.placement.enabled
                        ? theme.colors.textPrimary
                        : theme.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              NeoSettingToggle(
                value: widget.placement.enabled,
                onChanged: (value) =>
                    widget.state.setEnabled(descriptor.id, enabled: value),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  descriptor.description,
                  style: theme.text.systemBarCaption.copyWith(
                    color: theme.colors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _ExpanderButton(
                expanded: _expanded,
                // A module with settings of its own marks the expander, so the
                // place to look for them is visible without opening every row.
                highlighted: configurable,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            _ExpandedSettings(
              placement: widget.placement,
              state: widget.state,
              descriptors: widget.descriptors,
              canMoveUp: widget.canMoveUp,
              canMoveDown: widget.canMoveDown,
              module: module,
              services: widget.services,
              monitorId: widget.monitorId,
            ),
          ],
        ],
      ),
    );
  }
}

/// The inset panel under an expanded row.
class _ExpandedSettings extends StatelessWidget {
  const _ExpandedSettings({
    required this.placement,
    required this.state,
    required this.descriptors,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.module,
    required this.services,
    required this.monitorId,
  });

  final NeoModulePlacement placement;
  final NeoTopBarConfigState state;
  final Iterable<NeoModuleDescriptor> descriptors;
  final bool canMoveUp;
  final bool canMoveDown;
  final NeoModule? module;
  final ShellServices services;
  final int monitorId;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final descriptor = placement.descriptor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(theme.chipRadius),
        border: Border.all(color: theme.colors.hairlineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeoSettingRow(
              label: '位置',
              description: '停在栏的左 / 中 / 右哪一段',
              child: _ZoneSelector(
                zone: placement.zone,
                onChanged: (zone) => state.setZone(
                  descriptor.id,
                  zone: zone,
                  defaultZone: descriptor.zone,
                ),
              ),
            ),
            const SizedBox(height: 10),
            NeoSettingRow(
              label: '顺序',
              description: '在同一区内前后移动',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 6),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colors.hairlineSoft),
            const SizedBox(height: 10),
            Text(
              '「${descriptor.label}」设置',
              style: theme.text.systemBarCaption.copyWith(
                fontSize: 12,
                color: theme.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (module case final NeoModuleSettings configurable)
              configurable.buildSettings(
                context,
                NeoModuleSettingsScope(
                  services: services,
                  monitorId: monitorId,
                  options: state.config.optionsOf(descriptor.id),
                  setOption: (key, value) =>
                      state.setOption(descriptor.id, key, value),
                ),
              )
            else
              Text(
                '这个组件暂时没有自己的设置。',
                style: theme.text.systemBarCaption.copyWith(
                  color: theme.colors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The chevron that opens a module's settings.
class _ExpanderButton extends StatelessWidget {
  const _ExpanderButton({
    required this.expanded,
    required this.highlighted,
    required this.onPressed,
  });

  final bool expanded;

  /// True when the module contributes settings of its own.
  final bool highlighted;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final color = expanded || highlighted
        ? theme.accent
        : theme.colors.textTertiary;
    return Semantics(
      button: true,
      expanded: expanded,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.tileOff.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(theme.chipRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '设置',
                      style: theme.text.systemBarCaption.copyWith(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
