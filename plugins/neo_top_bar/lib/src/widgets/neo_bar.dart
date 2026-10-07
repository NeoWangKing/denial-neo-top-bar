/// The bar itself: three zones, user-ordered modules, per-card glass.
library;

import 'dart:io' show File, FileSystemException;

import 'package:denial_flutter_sdk/panels.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/bar_drag_layout.dart';
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
  /// The strip's coordinate space, for placing the drag feedback.
  final GlobalKey _stripKey = GlobalKey(debugLabel: 'neo-top-bar-strip');

  final Map<String, GlobalKey> _pillKeys = <String, GlobalKey>{};

  /// Visible pills in bar order, refreshed on every non-drag build.
  List<_PillSlot> _slots = const <_PillSlot>[];

  String? _draggingId;

  /// Centre of the drag feedback, in strip coordinates.
  Offset? _feedbackCenter;

  /// Vector from the pointer to the dragged pill's centre, captured when the
  /// drag starts.
  ///
  /// Keeping it is what stops the pill from jumping: without it the feedback's
  /// centre is pinned to the pointer, so the moment a long press lands the pill
  /// teleports out from under the finger. With it the pill stays exactly where
  /// it was grabbed and simply follows.
  Offset _grabDelta = Offset.zero;

  String? _targetBeforeId;
  NeoZone? _targetZone;

  /// Pill rectangles captured when the drag began, in scene coordinates.
  ///
  /// Frozen on purpose: the preview reflows while dragging, so measuring live
  /// positions would make the drop target depend on the layout that target
  /// produces. The pill sizes for the preview geometry come from here too.
  Map<String, Rect> _dragRects = const <String, Rect>{};

  /// Zone extents derived from [_dragRects], in bar order.
  List<NeoZoneExtent> _dragZones = const <NeoZoneExtent>[];

  /// A module widget per visible pill, built once when the drag starts.
  ///
  /// The drag preview is positioned from the pointer, so it rebuilds every
  /// frame. Reusing the same widget instances means Flutter only moves the
  /// existing elements instead of rebuilding every module's subtree — including
  /// the host-rendered tray — sixty times a second.
  Map<String, Widget> _dragChildren = const <String, Widget>{};

  bool get _horizontal => widget.side.isHorizontal;

  NeoModuleContext get _moduleContext => NeoModuleContext(
    services: widget.services,
    monitorId: widget.monitorId,
    side: widget.side,
    accent: widget.accent,
    density: widget.state.config.density.scale,
  );

  GlobalKey _keyFor(String id) =>
      _pillKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'neo-pill-$id'));

  Widget _module(
    BuildContext context,
    NeoModuleContext moduleContext,
    String id,
  ) => NeoTopBarModules.byId(id)!.build(context, moduleContext);

  bool _isVisible(NeoModulePlacement placement, NeoModuleContext context) {
    if (!placement.enabled) return false;
    final module = NeoTopBarModules.byId(placement.descriptor.id);
    return module != null && module.isAvailable(context);
  }

  List<NeoModulePlacement> _visiblePlacements(
    NeoTopBarConfig config,
    List<NeoModuleDescriptor> descriptors,
    NeoModuleContext context,
  ) => <NeoModulePlacement>[
    for (final placement in resolvePlacements(
      descriptors: descriptors,
      config: config,
    ))
      if (_isVisible(placement, context)) placement,
  ];

  void _startDrag(String id, Offset globalPosition) {
    // One drag at a time: the preview replaces the resting layout, so a second
    // long press would otherwise measure keys that are not mounted.
    if (_draggingId != null) return;
    final horizontal = _horizontal;
    final rects = <String, Rect>{};
    final zones = <NeoZoneExtent>[];
    for (final slot in _slots) {
      final box = slot.key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      rects[slot.id] = rect;
      final start = horizontal ? rect.left : rect.top;
      final end = horizontal ? rect.right : rect.bottom;
      if (zones.isNotEmpty && zones.last.zone == slot.zone) {
        final previous = zones.removeLast();
        zones.add(
          NeoZoneExtent(
            zone: slot.zone,
            start: start < previous.start ? start : previous.start,
            end: end > previous.end ? end : previous.end,
          ),
        );
      } else {
        zones.add(NeoZoneExtent(zone: slot.zone, start: start, end: end));
      }
    }
    final moduleContext = _moduleContext;
    final grabbed = rects[id];
    final strip = _stripKey.currentContext?.findRenderObject();
    if (strip is RenderBox && strip.attached && grabbed != null) {
      final pointerLocal = strip.globalToLocal(globalPosition);
      final centreLocal = strip.globalToLocal(grabbed.center);
      _grabDelta = centreLocal - pointerLocal;
    } else {
      _grabDelta = Offset.zero;
    }
    setState(() {
      _dragRects = rects;
      _dragZones = zones;
      _dragChildren = <String, Widget>{
        for (final slot in _slots)
          if (rects.containsKey(slot.id))
            slot.id: _module(context, moduleContext, slot.id),
      };
      _draggingId = id;
      _moveFeedback(globalPosition);
      _updateTarget(globalPosition);
    });
  }

  void _updateDrag(Offset globalPosition) {
    setState(() {
      _moveFeedback(globalPosition);
      _updateTarget(globalPosition);
    });
  }

  void _moveFeedback(Offset globalPosition) {
    final strip = _stripKey.currentContext?.findRenderObject();
    _feedbackCenter = strip is RenderBox && strip.attached
        ? strip.globalToLocal(globalPosition) + _grabDelta
        : null;
  }

  /// Resolves where a drop at [globalPosition] would land.
  ///
  /// The zone is decided first, from the extent each zone's pills occupied when
  /// the drag began, and only then the position inside that zone. Deciding the
  /// zone from "the pill after this gap" is the bug that made a pill dropped on
  /// the workspaces land next to the launcher: crossing the middle of a zone's
  /// last pill flipped the answer into the following zone.
  void _updateTarget(Offset globalPosition) {
    // Where the pill is, not where the cursor is: they differ by the grab
    // offset, and the drop should follow the pill the user is looking at.
    final dragged = globalPosition + _grabDelta;
    final pointer = _horizontal ? dragged.dx : dragged.dy;
    final zone = neoDropZoneAt(
      mainAxisPosition: pointer,
      zoneExtents: _dragZones,
    );
    if (zone == null) {
      _targetZone = null;
      _targetBeforeId = null;
      return;
    }

    String? beforeId;
    for (final slot in _slots) {
      if (slot.zone != zone || slot.id == _draggingId) continue;
      final rect = _dragRects[slot.id];
      if (rect == null) continue;
      final middle = _horizontal ? rect.center.dx : rect.center.dy;
      if (pointer < middle) {
        beforeId = slot.id;
        break;
      }
    }
    _targetZone = zone;
    _targetBeforeId = beforeId;
  }

  /// Whether [globalPosition] lands on one of the laid-out pills.
  ///
  /// Reuses the same rectangles the drag measures, so there is no second source
  /// of truth for where a pill is.
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

  void _endDragIfActive() {
    if (_draggingId == null) return;
    _endDrag();
  }

  void _clearDrag() {
    setState(() {
      _draggingId = null;
      _feedbackCenter = null;
      _targetBeforeId = null;
      _targetZone = null;
      _dragRects = const <String, Rect>{};
      _dragZones = const <NeoZoneExtent>[];
      _dragChildren = const <String, Widget>{};
      _grabDelta = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final horizontal = _horizontal;
    final density = widget.state.config.density.scale;
    final descriptors = NeoTopBarModules.descriptors;
    final moduleContext = _moduleContext;

    return Listener(
      // Without `opaque` the strip only counts as hit where a child is, because
      // Listener defaults to HitTestBehavior.deferToChild. The settings card
      // opens on right-clicks that deliberately miss every pill, so with the
      // default it could never fire at all: over a pill it is skipped on purpose,
      // and over the empty stretches between zones there is no child to hit.
      // `opaque` makes the strip itself a hit target while still delivering
      // events to its children, so the tray keeps its own right-click menus.
      behavior: HitTestBehavior.opaque,
      // Safety net for the drag state. The long-press callbacks normally end a
      // drag, but if the pointer is ever released without reaching them the bar
      // would stay in the preview layout, which has no long-press handlers — so
      // nothing would be draggable again until the shell restarted.
      onPointerUp: (_) => _endDragIfActive(),
      onPointerCancel: (_) => _endDragIfActive(),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_draggingId != null && _targetZone != null) {
            return _buildDragPreview(
              context: context,
              theme: theme,
              size: constraints.biggest,
              moduleContext: moduleContext,
              descriptors: descriptors,
              density: density,
            );
          }
          return _buildFlexLayout(
            context: context,
            theme: theme,
            horizontal: horizontal,
            density: density,
            moduleContext: moduleContext,
            descriptors: descriptors,
          );
        },
      ),
    );
  }

  /// The resting layout: zones spread, pills sized by their content.
  Widget _buildFlexLayout({
    required BuildContext context,
    required ShellThemeData theme,
    required bool horizontal,
    required double density,
    required NeoModuleContext moduleContext,
    required List<NeoModuleDescriptor> descriptors,
  }) {
    final zones = <NeoZone, List<Widget>>{};
    final slots = <_PillSlot>[];
    for (final placement in _visiblePlacements(
      widget.state.config,
      descriptors,
      moduleContext,
    )) {
      final id = placement.descriptor.id;
      final key = _keyFor(id);
      slots.add(_PillSlot(id: id, zone: placement.zone, key: key));
      (zones[placement.zone] ??= <Widget>[]).add(
        // The GlobalKey sits on the wrapper itself, not on a widget inside it:
        // that is what lets Flutter re-parent the whole state — the scale
        // controller and the long-press recogniser — into the drag feedback
        // instead of recreating them when the bar switches layouts.
        _DraggablePill(
          key: key,
          id: id,
          dragging: _draggingId == id,
          onDragStart: _startDrag,
          onDragUpdate: _updateDrag,
          onDragEnd: _endDrag,
          onDragCancel: _clearDrag,
          child: _module(context, moduleContext, id),
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

    return Stack(
      key: _stripKey,
      children: [
        Padding(
          padding: horizontal
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
              : const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: layout,
        ),
      ],
    );
  }

  /// The dragging layout: explicit offsets so the reflow can be animated.
  ///
  /// The preview is produced by the same pure function that will be persisted on
  /// drop, so what the user sees while dragging is exactly what they get. The
  /// dragged pill's slot shows a placeholder and the real pill follows the
  /// pointer.
  Widget _buildDragPreview({
    required BuildContext context,
    required ShellThemeData theme,
    required Size size,
    required NeoModuleContext moduleContext,
    required List<NeoModuleDescriptor> descriptors,
    required double density,
  }) {
    final horizontal = _horizontal;
    final draggingId = _draggingId!;
    final preview = _visiblePlacements(
      moveModuleToSlot(
        config: widget.state.config,
        descriptors: descriptors,
        moduleId: draggingId,
        targetZone: _targetZone!,
        beforeId: _targetBeforeId,
      ),
      descriptors,
      moduleContext,
    );

    final placed = neoDragLayout(
      pills: <NeoPillBox>[
        for (final placement in preview)
          if (_dragRects[placement.descriptor.id] case final rect?)
            NeoPillBox(
              id: placement.descriptor.id,
              zone: placement.zone,
              extent: horizontal ? rect.width : rect.height,
            ),
      ],
      mainExtent: horizontal ? size.width : size.height,
      crossExtent: horizontal ? size.height : size.width,
      mainPadding: 8,
      crossPadding: 5,
      gap: 6 * density,
    );

    final feedbackSize = _dragRects[draggingId]?.size;
    final feedbackCenter = _feedbackCenter;
    final feedback = _dragChildren[draggingId];
    return Stack(
      key: _stripKey,
      children: [
        for (final placement in preview)
          if (placed[placement.descriptor.id] case final at?)
            AnimatedPositioned(
              key: ValueKey<String>('neo-drag-${placement.descriptor.id}'),
              // Short enough to track the pointer, long enough to read as the
              // pills making room rather than jumping.
              duration: Motion.tile,
              curve: Motion.standard,
              left: horizontal ? at.main : at.cross,
              top: horizontal ? at.cross : at.main,
              width: horizontal ? at.extent : at.crossExtent,
              height: horizontal ? at.crossExtent : at.extent,
              child: placement.descriptor.id == draggingId
                  ? const _DragPlaceholder()
                  : _dragChildren[placement.descriptor.id] ??
                        _module(
                          context,
                          moduleContext,
                          placement.descriptor.id,
                        ),
            ),
        if (feedbackSize != null && feedbackCenter != null && feedback != null)
          Positioned(
            left: feedbackCenter.dx - feedbackSize.width / 2,
            top: feedbackCenter.dy - feedbackSize.height / 2,
            width: feedbackSize.width,
            height: feedbackSize.height,
            // The real pill follows the pointer, and it keeps the *same*
            // GlobalKey the resting layout gave it. That is load-bearing:
            // Flutter re-parents the keyed element instead of rebuilding it, so
            // the long-press recogniser driving this drag stays alive. Replacing
            // the widget that owns a gesture disposes its recogniser, and
            // disposal never calls onLongPressEnd — the drag would then sit
            // frozen on its first frame, with no pill draggable, forever.
            //
            // IgnorePointer is safe here: an accepted long press receives its
            // move and up events through the pointer router, not hit testing.
            child: IgnorePointer(
              child: _DraggablePill(
                key: _keyFor(draggingId),
                id: draggingId,
                dragging: false,
                onDragStart: _startDrag,
                onDragUpdate: _updateDrag,
                onDragEnd: _endDrag,
                onDragCancel: _clearDrag,
                child: feedback,
              ),
            ),
          ),
      ],
    );
  }
}

/// Wraps one pill with the press feedback and the long-press drag gesture.
///
/// The press feedback lives here rather than inside the card so that it belongs
/// to the **pill**: every module gets it, whether its card is interactive or not,
/// and pressing any control inside a pill grows that pill instead of just the
/// control. One language for the whole bar.
///
/// A long press grows the pill further and holds it there, so a pill reads as
/// lifted for as long as it is being dragged.
class _DraggablePill extends StatefulWidget {
  const _DraggablePill({
    required this.id,
    required this.dragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.child,
    super.key,
  });

  final String id;
  final bool dragging;
  final void Function(String id, Offset globalPosition) onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final Widget child;

  @override
  State<_DraggablePill> createState() => _DraggablePillState();
}

class _DraggablePillState extends State<_DraggablePill>
    with SingleTickerProviderStateMixin {
  /// A press grows the pill a little; a long press grows it further, as if
  /// lifting it off the bar. Both are small because the strip clips: at 1.08 a
  /// 45px-tall pill grows under two pixels per edge.
  static const double _pressedScale = 1.03;
  static const double _liftedScale = 1.08;

  /// The controller's value *is* the scale, so a spring drives it directly.
  ///
  /// Unbounded on purpose: [Motion.bouncy] overshoots on the way back, which is
  /// the rebound. A plain [Transform] is used rather than [ShellFadeScale]
  /// because a fade wrapper would put a layer around the pill's
  /// [ShellBackdropBlur], which then samples that layer instead of the wallpaper.
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool _pressed = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _growTo(double target, SpringDescription spring, String label) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
      return;
    }
    springTo(_scale, target, spring: spring, telemetryLabel: label);
  }

  void _handleDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _pressed = true;
    _growTo(_pressedScale, Motion.snappy, 'neo_top_bar.pill_press');
  }

  void _handleUp() {
    if (!_pressed) return;
    _pressed = false;
    _growTo(1, Motion.bouncy, 'neo_top_bar.pill_release');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // A raw Listener, not the tap callbacks: with the long-press recogniser
      // competing for the pointer, a tap recogniser does not fire onTapDown until
      // it wins the arena or its 100ms deadline expires, and a quick click
      // releases in the same frame — the grow would start and be cancelled
      // before it moved. A Listener does not join the arena and fires on the
      // down event itself. It also consumes nothing, so taps still land.
      onPointerDown: _handleDown,
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: GestureDetector(
        // Long-press opens the arena's other side: a fast drag rejects it (the
        // 18px slop), so flicking across the bar never starts a reorder.
        onLongPressStart: (details) {
          _growTo(_liftedScale, Motion.gentle, 'neo_top_bar.pill_lift');
          widget.onDragStart(widget.id, details.globalPosition);
        },
        onLongPressMoveUpdate: (details) =>
            widget.onDragUpdate(details.globalPosition),
        onLongPressEnd: (_) {
          _pressed = false;
          _growTo(1, Motion.bouncy, 'neo_top_bar.pill_release');
          widget.onDragEnd();
        },
        onLongPressCancel: () {
          _pressed = false;
          _growTo(1, Motion.bouncy, 'neo_top_bar.pill_release');
          widget.onDragCancel();
        },
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          // While the bar is still on its resting layout the dragged pill keeps
          // its slot but paints nothing, so the bar does not reflow under the
          // pointer. Deliberately not an Opacity fade: a partly transparent layer
          // around ShellBackdropBlur makes the glass sample that layer instead of
          // the wallpaper. At opacity 0 Flutter skips painting the child
          // entirely, so no layer is involved.
          child: Visibility(
            visible: !widget.dragging,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The silhouette left in the gap the dragged pill would drop into.
///
/// A shape rather than a second copy of the pill: a translucent copy would have
/// to wrap `ShellBackdropBlur` in a layer, which makes the glass sample that
/// layer instead of the wallpaper, and rebuilding the module would render the
/// host tray twice.
class _DragPlaceholder extends StatelessWidget {
  const _DragPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: theme.borderRadius(999),
          border: Border.all(color: theme.accent.withValues(alpha: 0.55)),
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
