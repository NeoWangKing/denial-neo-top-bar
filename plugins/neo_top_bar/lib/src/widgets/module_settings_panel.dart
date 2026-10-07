/// Module settings panel: enable/disable every known module, move it between the
/// bar's zones, reorder it inside its zone, set the bar's spacing, and edit
/// whatever a module wants to expose about itself.
///
/// Denial's Settings app cannot host plugin pages, and the plugin SDK has no API
/// for opening a separate native window, so this is a large **centered** popup
/// card: Denial's own detail-popup mechanism, scaled up to read as a window.
///
/// The card is organised as a board: one section per zone, holding that zone's
/// modules as draggable cards and an **add** button underneath. Placement is
/// therefore expressed by *where a card is* and *which section added it*, not by
/// repeating a left/centre/right selector and up/down buttons on every row —
/// those were four controls per row doing what dragging and one button per zone
/// do better, and they left no room for a module's own settings.
///
/// Each card still carries what only it can: its name, its description, its
/// on/off switch, and an expandable area with its own settings. Dragging is
/// scoped to a section, because a zone is the only place order means anything.
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
import '../core/zone_board.dart';
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
        // Only enabled modules appear: a switched-off module is not on the bar,
        // so it belongs in the add list rather than on the board.
        final byZone = <NeoZone, List<NeoModulePlacement>>{};
        for (final placement in placements) {
          if (!placement.enabled) continue;
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
                  '拖动卡片调整同一区内的顺序（越靠上，在横栏上越靠左）；'
                  '点卡片里的箭头展开它自己的选项；'
                  '「添加组件」可以把任何组件放进这一段，同一个组件想加几个就加几个。',
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
                      _ZoneSection(
                        zone: zone,
                        rows: byZone[zone] ?? const <NeoModulePlacement>[],
                        placements: placements,
                        state: state,
                        descriptors: descriptors,
                        services: services,
                        monitorId: monitorId,
                      ),
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

/// One zone: its cards, then the button that adds another.
class _ZoneSection extends StatelessWidget {
  const _ZoneSection({
    required this.zone,
    required this.rows,
    required this.placements,
    required this.state,
    required this.descriptors,
    required this.services,
    required this.monitorId,
  });

  final NeoZone zone;
  final List<NeoModulePlacement> rows;
  final List<NeoModulePlacement> placements;
  final NeoTopBarConfigState state;
  final Iterable<NeoModuleDescriptor> descriptors;
  final ShellServices services;
  final int monitorId;

  /// The id a drop at [newIndex] should end up in front of, as the configuration
  /// expresses placement.
  void _reorder(int oldIndex, int newIndex) {
    final ids = <String>[for (final row in rows) row.id];
    state.moveToSlot(
      ids[oldIndex],
      targetZone: zone,
      beforeId: neoBeforeIdAfterReorder(ids, oldIndex, newIndex),
      descriptors: descriptors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ZoneHeader(zone: zone, count: rows.length),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '这一段还没有组件。',
              style: theme.text.systemBarCaption.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
          )
        else
          ReorderableListView(
            // The panel owns the scrolling; a nested scrollable here would
            // fight it, and a zone is short enough that losing drag
            // auto-scroll costs nothing.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            proxyDecorator: _draggedCardDecorator,
            children: [
              for (final row in rows)
                _ModuleCard(
                  key: ValueKey<String>(neoCardKeyName(row.id)),
                  placement: row,
                  state: state,
                  services: services,
                  monitorId: monitorId,
                  index: rows.indexOf(row),
                ),
            ],
          ),
        _AddModuleButton(
          zone: zone,
          candidates: neoAddCandidates(descriptors),
          state: state,
          descriptors: descriptors,
        ),
      ],
    );
  }
}

/// How a card looks while it is being dragged.
///
/// The default decorator wraps the child in a `Material`, which this shell has no
/// use for: an elevation shadow drawn by Material would be the only one on
/// screen, and the bar's own drag has no such thing.
///
/// The lift is a scale plus a soft shadow, deliberately **not** a border. The
/// item box is the card *plus the gap under it* — a reorderable list has no
/// per-item spacing, so the gap belongs to the item — and a hard outline drawn
/// around that box is visibly offset from the card it is supposed to outline.
/// A blurred shadow around the same box reads as centred on the card, which is
/// also why Material's own elevation looks right here.
Widget _draggedCardDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) => AnimatedBuilder(
  animation: animation,
  builder: (context, _) {
    final theme = ShellTheme.of(context);
    final lift = animation.value;
    return Transform.scale(
      scale: 1 + 0.012 * lift,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.chipRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colors.shadow.withValues(alpha: 0.45 * lift),
              blurRadius: 22 * lift,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
    );
  },
);

/// One module: a card with its identity, its switch, and its own settings.
class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    required this.placement,
    required this.state,
    required this.services,
    required this.monitorId,
    required this.index,
    super.key,
  });

  final NeoModulePlacement placement;
  final NeoTopBarConfigState state;
  final ShellServices services;
  final int monitorId;
  final int index;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final descriptor = widget.placement.descriptor;
    final module = NeoTopBarModules.byId(descriptor.id);
    final configurable = module is NeoModuleSettings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(theme.chipRadius),
          border: Border.all(color: theme.colors.hairlineSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
          child: Row(
            // The grip sits at the card's vertical middle rather than under its
            // top edge, which is where the eye looks for a drag handle.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Tooltip(
                  message: '拖动调整这一区内的顺序',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: theme.colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ReorderableDelayedDragStartListener(
                  // Holding the card lifts it too, so the whole card is a drag
                  // target and the grip is only the quicker way in. The two
                  // listeners must not nest: a second start while a drag is in
                  // flight *cancels* the first, which is exactly what a grip
                  // inside a delayed listener would do half a second after the
                  // grip started one.
                  index: widget.index,
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
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // A switch would be a lie here: a switched-off card
                          // leaves the board, so "off" and "not on the bar"
                          // would look like two different states of one control.
                          // The control is removal, and re-adding goes through
                          // the zone's add button.
                          _RemoveButton(
                            onPressed: () => widget.state.removeInstance(
                              widget.placement.id,
                              descriptors: NeoTopBarModules.descriptors,
                            ),
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
                            highlighted: configurable,
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                        ],
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 10),
                        _ExpandedSettings(
                          placement: widget.placement,
                          state: widget.state,
                          module: module,
                          services: widget.services,
                          monitorId: widget.monitorId,
                        ),
                      ],
                    ],
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

/// The settings a module contributes, inside its own card.
class _ExpandedSettings extends StatelessWidget {
  const _ExpandedSettings({
    required this.placement,
    required this.state,
    required this.module,
    required this.services,
    required this.monitorId,
  });

  final NeoModulePlacement placement;
  final NeoTopBarConfigState state;
  final NeoModule? module;
  final ShellServices services;
  final int monitorId;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(theme.chipRadius),
        border: Border.all(color: theme.colors.hairlineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '「${placement.descriptor.label}」设置',
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
                  // Read from the placement, which already carries *this*
                  // instance's options: two copies of one module have their own,
                  // and reaching back into the config by module id would have
                  // both cards editing the first copy. The write still needs the
                  // instance id, which is why it is spelled out here.
                  options: placement.options,
                  setOption: (key, value) =>
                      state.setOption(placement.id, key, value),
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

/// The add button under a zone, and the list it opens.
class _AddModuleButton extends StatefulWidget {
  const _AddModuleButton({
    required this.zone,
    required this.candidates,
    required this.state,
    required this.descriptors,
  });

  final NeoZone zone;
  final List<NeoModuleDescriptor> candidates;
  final NeoTopBarConfigState state;
  final Iterable<NeoModuleDescriptor> descriptors;

  @override
  State<_AddModuleButton> createState() => _AddModuleButtonState();
}

class _AddModuleButtonState extends State<_AddModuleButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OutlineButton(
            icon: _open ? Icons.expand_less : Icons.add,
            label: '添加组件',
            onPressed: () => setState(() => _open = !_open),
          ),
          if (_open) ...[
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surfaceContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(theme.chipRadius),
                border: Border.all(color: theme.colors.hairlineSoft),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final candidate in widget.candidates)
                      _AddCandidateRow(
                        descriptor: candidate,
                        onPressed: () {
                          setState(() => _open = false);
                          widget.state.addInstance(
                            candidate.id,
                            zone: widget.zone,
                            descriptors: widget.descriptors,
                            defaultZone: candidate.zone,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddCandidateRow extends StatelessWidget {
  const _AddCandidateRow({required this.descriptor, required this.onPressed});

  final NeoModuleDescriptor descriptor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 15, color: theme.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  descriptor.label,
                  style: theme.text.systemBarValue.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // Adding a copy is the same gesture as adding the first one, so
                // there is nothing to distinguish here.
                '添加',
                style: theme.text.systemBarCaption.copyWith(
                  fontSize: 11.5,
                  color: theme.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bare chevron that opens a module's own settings.
///
/// No background plate: the card already has one, and a second dark rectangle
/// inside it — next to the label — was the thing that looked wrong. The chevron
/// stays accent-tinted when the module has settings to open, so the card still
/// says where to look.
/// Both trailing controls are drawn in this box so their icons sit on one
/// vertical axis down the right edge of every card.
const double _cardControlSize = 28;

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
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: _cardControlSize,
          child: Center(
            child: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: color,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded ? '收起设置' : '展开设置',
      child: ExcludeSemantics(
        child: Tooltip(message: expanded ? '收起设置' : '展开设置', child: button),
      ),
    );
  }
}

/// The cross that takes a module off the bar.
class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Semantics(
      button: true,
      label: '从顶栏移除',
      child: ExcludeSemantics(
        child: Tooltip(
          message: '从顶栏移除',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: DecoratedBox(
                // The plate only appears under the pointer: a row of idle red
                // crosses would make the panel look like a warning.
                decoration: BoxDecoration(
                  color: _hovered
                      ? theme.colors.performanceBad.withValues(alpha: 0.24)
                      : Colors.transparent,
                  borderRadius: theme.borderRadius(7),
                ),
                child: SizedBox.square(
                  dimension: _cardControlSize,
                  child: Center(
                    child: Icon(
                      Icons.close,
                      size: 17,
                      color: _hovered
                          ? theme.colors.performanceBad
                          : theme.colors.textTertiary,
                    ),
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

/// A wide outlined button, used for the per-zone add action.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.chipRadius),
            border: Border.all(color: theme.colors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: theme.colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.text.systemBarCaption.copyWith(
                    fontSize: 12,
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
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
        NeoSettingChips<NeoDensity>(
          values: _labels,
          selected: state.config.density,
          onSelected: state.setDensity,
        ),
      ],
    );
  }
}
