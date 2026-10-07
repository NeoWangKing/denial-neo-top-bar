/// The bar itself: three zones, user-ordered modules, per-card glass.
library;

import 'dart:io' show File, FileSystemException;

import 'package:denial_flutter_sdk/panels.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/config_state.dart';
import '../core/drop_target.dart';
import '../core/module.dart';
import '../core/module_descriptor.dart';
import '../core/module_registry.dart';
import '../core/preferences.dart';
import '../core/settings_requests.dart';
import 'module_settings_panel.dart';

/// Holds the process-wide preferences store.
///
/// The store is stateless apart from its write queue, so one instance shared by
/// every output keeps writes serialized instead of racing between monitors.
abstract final class NeoTopBarPreferencesStoreHolder {
  static final NeoTopBarPreferencesStore instance = NeoTopBarPreferencesStore(
    // `defaultFile` only throws when neither XDG_CONFIG_HOME nor HOME is set,
    // which cannot happen in a real session. Falling back to a relative path
    // keeps the bar rendering in that pathological case instead of failing the
    // whole surface; the store reports the resulting write error in the panel.
    _configFile(),
  );

  static File _configFile() {
    try {
      return NeoTopBarPreferencesStore.defaultFile();
    } on FileSystemException {
      return File('neo_top_bar.json');
    }
  }
}

/// Default bar widget mounted by the plugin's `ShellSurface`.
class NeoTopBar extends ConsumerStatefulWidget {
  const NeoTopBar({
    required this.monitorId,
    required this.side,
    required this.services,
    super.key,
  });

  final int monitorId;
  final PanelEdge side;
  final ShellServices services;

  @override
  ConsumerState<NeoTopBar> createState() => _NeoTopBarState();
}

class _NeoTopBarState extends ConsumerState<NeoTopBar> {
  NeoTopBarConfigState? _state;

  @override
  void initState() {
    super.initState();
    _load();
    // The shortcut action has no BuildContext of its own, so it raises a request
    // here instead and the bar opens the card. Several bars may be mounted (one
    // per output); the popup controller's keyName dedupe collapses them into one
    // card.
    NeoSettingsRequests.instance.addListener(_handleSettingsRequest);
  }

  void _handleSettingsRequest() {
    final state = _state;
    if (!mounted || state == null) return;
    openModuleSettingsPanel(
      context: context,
      state: state,
      services: widget.services,
      monitorId: widget.monitorId,
    );
  }

  Future<void> _load() async {
    final state = await NeoTopBarConfigState.load(
      NeoTopBarPreferencesStoreHolder.instance,
    );
    if (!mounted) return;
    setState(() => _state = state);
    // Drop ids from uninstalled builds so the settings panel and the saved
    // order never show stale entries. A failed write is reported by the panel,
    // not by removing the bar.
    await state.prune(NeoTopBarModules.descriptors);
  }

  @override
  void dispose() {
    NeoSettingsRequests.instance.removeListener(_handleSettingsRequest);
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    // Nothing is painted until the configuration is available. The surface's
    // reserved strip still exists, so the desktop does not reflow; the bar just
    // fills in a frame or two later after the file read.
    if (state == null) return const SizedBox.shrink();
    final accent = WallpaperAccent(ref.watch(widget.services.accent));
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => _BarContent(
        monitorId: widget.monitorId,
        side: widget.side,
        services: widget.services,
        state: state,
        accent: accent,
      ),
    );
  }
}

/// One visible pill, in bar order.
class _PillSlot {
  const _PillSlot({required this.id, required this.zone, required this.key});

  final String id;
  final NeoZone zone;
  final GlobalKey key;
}

/// The bar strip, with long-press drag to reorder its pills.
///
/// Dragging happens here rather than in the settings card because the bar is an
/// ordinary surface: the settings card sits under the popup host's dismissal
/// barrier, which competes for the same gestures. A long press (rather than an
/// immediate drag) keeps every pill's own click working.
class _BarContent extends StatefulWidget {
  const _BarContent({
    required this.monitorId,
    required this.side,
    required this.services,
    required this.state,
    required this.accent,
  });

  final int monitorId;
  final PanelEdge side;
  final ShellServices services;
  final NeoTopBarConfigState state;
  final WallpaperAccent accent;

  @override
  State<_BarContent> createState() => _BarContentState();
}

class _BarContentState extends State<_BarContent> {
  static const double _ghostWidth = 104;
  static const double _ghostHeight = 30;

  /// Measures pill rectangles in the strip's own coordinate space, so the drag
  /// ghost can be positioned without another ancestor lookup.
  final GlobalKey _stripKey = GlobalKey(debugLabel: 'neo-top-bar-strip');

  final Map<String, GlobalKey> _pillKeys = <String, GlobalKey>{};

  /// Visible pills in bar order. Refreshed on every build; the drag reads the
  /// copy from the last layout, which is still valid because a drag never
  /// changes the layout until it is committed.
  List<_PillSlot> _slots = const <_PillSlot>[];

  String? _draggingId;
  Offset? _ghostCenter;
  String? _targetBeforeId;
  NeoZone? _targetZone;

  /// Main-axis position, in strip coordinates, of the insertion line shown while
  /// dragging. The user needs to see where the pill will land, not just that
  /// something is being dragged.
  double? _indicatorMain;

  bool get _horizontal => widget.side.isHorizontal;

  GlobalKey _keyFor(String id) =>
      _pillKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'neo-pill-$id'));

  void _startDrag(String id, Offset globalPosition) {
    setState(() {
      _draggingId = id;
      _moveGhost(globalPosition);
      _updateTarget(globalPosition);
    });
  }

  void _updateDrag(Offset globalPosition) {
    setState(() {
      _moveGhost(globalPosition);
      _updateTarget(globalPosition);
    });
  }

  void _moveGhost(Offset globalPosition) {
    final strip = _stripKey.currentContext?.findRenderObject();
    _ghostCenter = strip is RenderBox && strip.attached
        ? strip.globalToLocal(globalPosition)
        : null;
  }

  /// Resolves where a drop at [globalPosition] would land, and where the
  /// insertion line belongs.
  ///
  /// The zone is decided first, from the extent each zone's pills occupy along
  /// the bar, and only then is the position inside that zone resolved. Deciding
  /// the zone from "the pill after this gap" is the bug that made a pill dropped
  /// on the workspaces land next to the launcher: crossing the middle of a
  /// zone's last pill flipped the answer into the following zone.
  void _updateTarget(Offset globalPosition) {
    final horizontal = _horizontal;
    final strip = _stripKey.currentContext?.findRenderObject();
    final stripBox = strip is RenderBox && strip.attached ? strip : null;

    // Every visible pill is measured, including the one being dragged: its slot
    // keeps its size, so it still defines its zone's extent. Excluding it would
    // make a single-pill zone (the launcher's, typically) undroppable.
    final measured = <_PillSlot, Rect>{};
    for (final slot in _slots) {
      final box = slot.key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      measured[slot] = box.localToGlobal(Offset.zero) & box.size;
    }
    if (measured.isEmpty || stripBox == null) {
      _targetZone = null;
      _targetBeforeId = null;
      _indicatorMain = null;
      return;
    }

    double toLocal(double globalMain) => horizontal
        ? stripBox.globalToLocal(Offset(globalMain, 0)).dx
        : stripBox.globalToLocal(Offset(0, globalMain)).dy;
    double startOf(Rect rect) => toLocal(horizontal ? rect.left : rect.top);
    double endOf(Rect rect) => toLocal(horizontal ? rect.right : rect.bottom);
    double centreOf(Rect rect) =>
        toLocal(horizontal ? rect.center.dx : rect.center.dy);
    final pointerGlobal = horizontal ? globalPosition.dx : globalPosition.dy;
    final pointerLocal = toLocal(pointerGlobal);

    // One extent per zone, in bar order, so a customised order still works.
    final extents = <NeoZoneExtent>[];
    for (final slot in _slots) {
      final rect = measured[slot];
      if (rect == null) continue;
      final slotStart = startOf(rect);
      final slotEnd = endOf(rect);
      if (extents.isNotEmpty && extents.last.zone == slot.zone) {
        final previous = extents.removeLast();
        extents.add(
          NeoZoneExtent(
            zone: slot.zone,
            start: slotStart < previous.start ? slotStart : previous.start,
            end: slotEnd > previous.end ? slotEnd : previous.end,
          ),
        );
      } else {
        extents.add(
          NeoZoneExtent(zone: slot.zone, start: slotStart, end: slotEnd),
        );
      }
    }

    final zone = neoDropZoneAt(
      mainAxisPosition: pointerLocal,
      zoneExtents: extents,
    );
    if (zone == null) {
      _targetZone = null;
      _targetBeforeId = null;
      _indicatorMain = null;
      return;
    }

    // Now the position, among that zone's own pills and ignoring the one that is
    // being dragged.
    String? beforeId;
    double? indicator;
    for (final slot in _slots) {
      if (slot.zone != zone || slot.id == _draggingId) continue;
      final rect = measured[slot];
      if (rect == null) continue;
      if (pointerLocal < centreOf(rect)) {
        beforeId = slot.id;
        indicator = startOf(rect);
        break;
      }
    }
    if (beforeId == null) {
      // Past the zone's last pill: the line goes after it.
      for (final extent in extents) {
        if (extent.zone == zone) indicator = extent.end;
      }
    }

    _targetZone = zone;
    _targetBeforeId = beforeId;
    _indicatorMain = indicator;
  }

  /// What the drag ghost says: the module and the zone it would join, so the
  /// destination is explicit rather than something to infer from the layout.
  String _ghostLabel(String id) {
    final module = NeoTopBarModules.descriptorOf(id)?.label ?? id;
    final zone = _targetZone;
    return zone == null ? module : '$module → ${zone.label}';
  }

  /// Whether [globalPosition] lands on one of the laid-out pills.
  ///
  /// Reuses the rectangles the drag already measures, so there is no second
  /// source of truth for where a pill is.
  bool _isOverPill(Offset globalPosition) {
    for (final slot in _slots) {
      final box = slot.key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return true;
    }
    return false;
  }

  Future<void> _endDrag() async {
    final id = _draggingId;
    final zone = _targetZone;
    final beforeId = _targetBeforeId;
    _clearDrag();
    if (id == null || zone == null) return;
    await widget.state.moveToSlot(
      id,
      targetZone: zone,
      beforeId: beforeId,
      descriptors: NeoTopBarModules.descriptors,
    );
  }

  void _clearDrag() {
    setState(() {
      _draggingId = null;
      _ghostCenter = null;
      _targetBeforeId = null;
      _targetZone = null;
      _indicatorMain = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = _horizontal;
    final density = widget.state.config.density.scale;
    final placements = resolvePlacements(
      descriptors: NeoTopBarModules.descriptors,
      config: widget.state.config,
    );
    final moduleContext = NeoModuleContext(
      services: widget.services,
      monitorId: widget.monitorId,
      side: widget.side,
      accent: widget.accent,
      density: density,
    );

    final zones = <NeoZone, List<Widget>>{};
    final slots = <_PillSlot>[];
    for (final placement in placements) {
      if (!placement.enabled) continue;
      final id = placement.descriptor.id;
      final module = NeoTopBarModules.byId(id);
      if (module == null) continue;
      if (!module.isAvailable(moduleContext)) continue;
      final key = _keyFor(id);
      slots.add(_PillSlot(id: id, zone: placement.zone, key: key));
      (zones[placement.zone] ??= <Widget>[]).add(
        KeyedSubtree(
          key: ValueKey<String>('neo-module-$id'),
          child: _DraggablePill(
            slotKey: key,
            id: id,
            dragging: _draggingId == id,
            // The pill the drop would land in front of.
            target:
                _draggingId != null &&
                id != _draggingId &&
                _targetBeforeId == id,
            onDragStart: _startDrag,
            onDragUpdate: _updateDrag,
            onDragEnd: _endDrag,
            onDragCancel: _clearDrag,
            child: module.build(context, moduleContext),
          ),
        ),
      );
    }
    _slots = slots;

    /// Packs one zone's modules along the bar's main axis.
    ///
    /// Cards stretch across the cross axis so they fill the strip Denial
    /// reserved. That is what Denial's own bar does, and it keeps the pills
    /// proportionate when the configured thickness is larger than their content
    /// needs instead of leaving thin chips floating in empty space.
    Widget? group(NeoZone zone) {
      final widgets = zones[zone];
      if (widgets == null || widgets.isEmpty) return null;
      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < widgets.length; index++) ...[
            if (index > 0)
              SizedBox(
                width: horizontal ? 6 * density : 0,
                height: horizontal ? 0 : 6 * density,
              ),
            widgets[index],
          ],
        ],
      );
    }

    /// One zone, allowed to shrink and scroll if the bar runs out of room.
    ///
    /// Without this a wide tray would push its neighbours off the strip instead
    /// of becoming scrollable.
    Widget? scrollable(Widget? child) => child == null
        ? null
        : ScrollConfiguration(
            // The strip is not a scroll area the user browses; hiding the
            // overscroll glow keeps the bar visually flat.
            behavior: const _NoGlowScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              child: child,
            ),
          );

    final start = scrollable(group(NeoZone.start));
    final center = scrollable(group(NeoZone.center));
    final end = scrollable(group(NeoZone.end));

    // Three real zones: start hugs the leading edge, end hugs the trailing edge,
    // and centre sits in the middle. A plain trailing-packed Flex would collapse
    // all three into one run, which is not the layout the bar promises.
    //
    // `stretch` on the outer axis gives each zone the strip's full cross extent,
    // which the group's own stretch then passes down to the cards.
    final Widget layout;
    if (horizontal) {
      layout = Stack(
        fit: StackFit.expand,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (start != null) Flexible(child: start),
              if (end != null) Flexible(child: end),
            ],
          ),
          if (center != null) Center(child: center),
        ],
      );
    } else {
      layout = Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (start != null) Flexible(child: start),
              if (end != null) Flexible(child: end),
            ],
          ),
          if (center != null) Center(child: center),
        ],
      );
    }

    final draggingId = _draggingId;
    final ghostCenter = _ghostCenter;
    final indicatorMain = _indicatorMain;
    final theme = ShellTheme.of(context);
    return Listener(
      // Without `opaque` the strip only counts as hit where a child is, because
      // Listener defaults to HitTestBehavior.deferToChild. The settings card
      // opens on right-clicks that deliberately miss every pill, so with the
      // default it could never fire at all: over a pill it is skipped on purpose,
      // and over the empty stretches between zones there is no child to hit.
      // `opaque` makes the strip itself a hit target while still delivering
      // events to its children, so the tray keeps its own right-click menus.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.buttons != kSecondaryButton) return;
        // A raw Listener does not compete in the gesture arena, so anything the
        // pills handle still runs. That is exactly why right-click must be
        // ignored over a pill: the status tray renders host-side items whose
        // context menus are opened with the secondary button, and opening this
        // card as well would fight them.
        if (_isOverPill(event.position)) return;
        // The settings card opens centered rather than at the pointer: it is a
        // configuration surface with many rows, not a context menu, so the click
        // position carries no meaning for it.
        openModuleSettingsPanel(
          context: context,
          state: widget.state,
          services: widget.services,
          monitorId: widget.monitorId,
        );
      },
      child: Stack(
        key: _stripKey,
        children: [
          // While a pill is being dragged its slot keeps its size, so the rest
          // of the bar stays put and only the ghost moves.
          Padding(
            padding: horizontal
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
                : const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: layout,
          ),
          if (draggingId != null && indicatorMain != null)
            Positioned(
              left: horizontal ? indicatorMain - 1.5 : 3,
              right: horizontal ? null : 3,
              top: horizontal ? 3 : indicatorMain - 1.5,
              bottom: horizontal ? 3 : null,
              width: horizontal ? 3 : null,
              height: horizontal ? null : 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: theme.borderRadius(3),
                ),
              ),
            ),
          if (draggingId != null && ghostCenter != null)
            Positioned(
              left: ghostCenter.dx - _ghostWidth / 2,
              top: ghostCenter.dy - _ghostHeight / 2,
              width: _ghostWidth,
              height: _ghostHeight,
              child: _DragGhost(label: _ghostLabel(draggingId)),
            ),
        ],
      ),
    );
  }
}

/// Wraps one pill with the long-press drag gesture and the drop highlight.
///
/// A long press, not an immediate pan: an immediate drag would swallow the tap
/// every pill already answers to.
class _DraggablePill extends StatelessWidget {
  const _DraggablePill({
    required this.slotKey,
    required this.id,
    required this.dragging,
    required this.target,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.child,
  });

  final GlobalKey slotKey;
  final String id;
  final bool dragging;
  final bool target;
  final void Function(String id, Offset globalPosition) onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return GestureDetector(
      key: slotKey,
      onLongPressStart: (details) => onDragStart(id, details.globalPosition),
      onLongPressMoveUpdate: (details) => onDragUpdate(details.globalPosition),
      onLongPressEnd: (_) => onDragEnd(),
      onLongPressCancel: onDragCancel,
      child: DecoratedBox(
        // A DecoratedBox paints inside the child's box, so highlighting never
        // changes the measured width mid-drag.
        decoration: BoxDecoration(
          borderRadius: theme.borderRadius(999),
          border: target
              ? Border.all(color: theme.accent, width: 2)
              : const Border.fromBorderSide(BorderSide.none),
        ),
        child: Opacity(opacity: dragging ? 0.35 : 1, child: child),
      ),
    );
  }
}

/// The pill-shaped label that follows the pointer while dragging.
class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.panelColor(theme.colors.panelBackground),
          borderRadius: theme.borderRadius(999),
          border: Border.all(color: theme.accent, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.text.systemBarCaption.copyWith(
              fontSize: 12,
              color: theme.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
