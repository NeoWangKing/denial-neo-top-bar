/// The bar itself: three zones, user-ordered modules, per-card glass.
library;

import 'dart:io' show File, FileSystemException;

import 'package:denial_flutter_sdk/panels.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
// `_RenderPillSizeReporter` is a render object, and `widgets.dart` re-exports
// only a slice of the rendering library.
import 'package:flutter/rendering.dart';
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
import 'neo_bar_menu.dart';

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

/// Eased motion for picking a pill up: it grows and slides until it is centred
/// under the pointer.
///
/// Deliberately a duration and curve rather than a spring. The spring tokens
/// settle in about 0.2s and are front-loaded, which reads as a snap followed by a
/// slow creep; picking a pill up should feel deliberate and continuous.
///
/// A symmetric emphasised ease, shortened rather than replaced: the decelerating
/// curves start far too fast (Motion.md3EmphasizedDecelerate covers most of the
/// distance in the first tenth), which is the snap this is meant to avoid.
const Duration _pickUpDuration = Duration(milliseconds: 360);
const Curve _pickUpCurve = Motion.md3Emphasized;

/// Padding between the strip's edge and the outermost pill, along the bar and
/// across it. Shared by both layouts and by the drag preview so they agree.
const double _mainPadding = 8;
const double _crossPadding = 5;

/// Space between two pills along the bar, scaled with the configured density.
///
/// One function so the fitted check, the explicit layout and the flex fallback
/// cannot drift apart.
double _gap(double density) => 6 * density;

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

class _BarContentState extends State<_BarContent>
    with SingleTickerProviderStateMixin {
  /// The strip's coordinate space, for placing the drag feedback.
  final GlobalKey _stripKey = GlobalKey(debugLabel: 'neo-top-bar-strip');

  final Map<String, GlobalKey> _pillKeys = <String, GlobalKey>{};

  /// Height of a pill, measured in the frame being built.
  ///
  /// Read from the strip's own constraints rather than from Denial's settings, so
  /// the icons follow what is actually on screen — including the edge padding
  /// this bar applies — and not a number that could disagree with it.
  double _pillCrossExtent = 40;

  /// Measured size of each visible pill along the bar's main axis.
  ///
  /// Explicit positioning has to know a pill's size before placing it, and that
  /// size comes from the pill's own content. Pills report their own size from
  /// the layout pass ([_PillSizeReporter]), so this is refreshed whenever a size
  /// actually changes — including in frames the bar itself does not rebuild.
  /// A missing entry means "not measured yet"; a **zero** entry means the pill
  /// renders nothing right now, which the layout treats as "no room, no gap".
  Map<String, double> _pillExtents = const <String, double>{};

  /// Whether a rebuild has been asked for after the current frame.
  bool _relayoutScheduled = false;

  /// Visible pills in bar order, refreshed on every non-drag build.
  List<_PillSlot> _slots = const <_PillSlot>[];

  String? _draggingId;

  /// Pointer position in strip coordinates.
  ///
  /// The raw pointer, not the feedback's centre: the centre depends on the grab
  /// animation, so it has to be recomputed on every frame the animation runs.
  /// Storing the computed centre meant the pill only moved when a pointer event
  /// arrived, which is why the centring slide never happened on its own.
  Offset? _pointerLocal;

  /// Distance, along the bar's own axis, from the pointer to the dragged pill's
  /// centre when it was grabbed. Animated to zero so the pill settles under the
  /// pointer instead of teleporting there.
  double _grabMain = 0;

  /// Cross-axis position of the dragged pill, in strip coordinates, held for the
  /// whole drag.
  ///
  /// The pill is nearly as tall as the strip, so following the pointer across the
  /// bar would only slide it out of the strip and clip it. A reorder is a move
  /// along the bar, so that axis is the only one that moves.
  double _anchorCross = 0;

  /// 0 leaves the grab offset in full effect; 1 means the pill is centred on the
  /// pointer. Starts settled, because outside a drag there is nothing to offset.
  late final AnimationController _grab = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

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

  bool get _horizontal => widget.side.isHorizontal;

  /// The grab distance still in effect: full when the drag starts, zero once the
  /// pill has settled under the pointer.
  double get _currentGrabMain => _grabMain * (1 - _grab.value);

  /// Centre of the drag feedback, in strip coordinates.
  Offset _feedbackCentre(Offset pointerLocal) {
    final main =
        (_horizontal ? pointerLocal.dx : pointerLocal.dy) + _currentGrabMain;
    return _horizontal
        ? Offset(main, _anchorCross)
        : Offset(_anchorCross, main);
  }

  @override
  void initState() {
    super.initState();
    _grab.addListener(_handleGrabTick);
  }

  void _handleGrabTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _grab.removeListener(_handleGrabTick);
    _grab.dispose();
    super.dispose();
  }

  /// The shared half of a module's context, without its own settings.
  ///
  /// Used where a module's options are irrelevant — availability, the drag
  /// preview's bookkeeping — while [_moduleContextFor] adds them for the one
  /// call that actually renders a pill.
  NeoModuleContext get _moduleContext => _moduleContextFor(null);

  NeoModuleContext _moduleContextFor(String? id) => NeoModuleContext(
    services: widget.services,
    monitorId: widget.monitorId,
    side: widget.side,
    accent: widget.accent,
    density: widget.state.config.density.scale,
    // Icon sizes follow the strip's own thickness, so a module never has to
    // guess it from a `LayoutBuilder` that may or may not be inside the card's
    // padding.
    crossExtent: _pillCrossExtent,
    options: id == null
        ? const <String, Object?>{}
        : widget.state.config.optionsOf(id),
  );

  GlobalKey _keyFor(String id) =>
      _pillKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'neo-pill-$id'));

  /// Module widgets, reused across builds.
  ///
  /// Returning the same instance makes Flutter skip rebuilding that module's
  /// subtree — the tray is rendered by the host and is not cheap — so this
  /// matters on every frame the pointer moves. Invalidated whenever the context
  /// the widgets were built from changes.
  Map<String, Widget> _moduleCache = const <String, Widget>{};
  int? _moduleCacheKey;

  /// The widget for one *instance*: [instanceId] is what it is keyed and cached
  /// by, [moduleId] decides which implementation draws it.
  Widget _module(BuildContext context, String instanceId, String moduleId) {
    final moduleContext = _moduleContextFor(instanceId);
    final key = Object.hash(
      moduleContext.services,
      moduleContext.monitorId,
      moduleContext.side,
      moduleContext.accent,
      moduleContext.density,
      moduleContext.optionsFingerprint,
    );
    if (_moduleCacheKey != key) {
      _moduleCacheKey = key;
      _moduleCache = <String, Widget>{};
    }
    return _moduleCache.putIfAbsent(
      instanceId,
      () => NeoTopBarModules.byId(moduleId)!.build(context, moduleContext),
    );
  }

  bool _isVisible(NeoModulePlacement placement, NeoModuleContext context) {
    if (!placement.enabled) return false;
    final module = NeoTopBarModules.byId(placement.moduleId);
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
    final grabbed = rects[id];
    final strip = _stripKey.currentContext?.findRenderObject();
    if (strip is RenderBox && strip.attached && grabbed != null) {
      final pointerLocal = strip.globalToLocal(globalPosition);
      final centreLocal = strip.globalToLocal(grabbed.center);
      _grabMain = _horizontal
          ? centreLocal.dx - pointerLocal.dx
          : centreLocal.dy - pointerLocal.dy;
      _anchorCross = _horizontal ? centreLocal.dy : centreLocal.dx;
    } else {
      _grabMain = 0;
      _anchorCross = 0;
    }
    // Start with the offset in full effect: the first frame of the drag puts the
    // pill exactly where it was grabbed, so nothing jumps.
    _grab.value = 0;
    setState(() {
      _dragRects = rects;
      _dragZones = zones;
      _draggingId = id;
      _moveFeedback(globalPosition);
      _updateTarget(globalPosition);
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _grab.value = 1;
    } else {
      MotionTelemetry.observe(
        _grab,
        _grab.animateTo(1, duration: _pickUpDuration, curve: _pickUpCurve),
        'neo_top_bar.pill_centre',
        target: 1,
      );
    }
  }

  void _updateDrag(Offset globalPosition) {
    setState(() {
      _moveFeedback(globalPosition);
      _updateTarget(globalPosition);
    });
  }

  void _moveFeedback(Offset globalPosition) {
    final strip = _stripKey.currentContext?.findRenderObject();
    _pointerLocal = strip is RenderBox && strip.attached
        ? strip.globalToLocal(globalPosition)
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
    // Where the pill is along the bar, not where the cursor is: they differ until
    // the pill has finished centring, and the drop should follow the pill the
    // user is looking at.
    final pointer =
        (_horizontal ? globalPosition.dx : globalPosition.dy) +
        _currentGrabMain;
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

  /// Opens one pill's settings card at [position], which is where the user
  /// right-clicked.
  ///
  /// The placement is resolved from the current configuration rather than carried
  /// on the slot, so the card reads what is true now: the pill may have been
  /// reordered or re-configured by another surface since the layout was built.
  void _openPillSettings(
    BuildContext context,
    String instanceId,
    Offset position,
  ) {
    openNeoPillSettings(
      context: context,
      state: widget.state,
      services: widget.services,
      monitorId: widget.monitorId,
      instanceId: instanceId,
      position: position,
    );
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
    _grab.stop();
    setState(() {
      _draggingId = null;
      _pointerLocal = null;
      _targetBeforeId = null;
      _targetZone = null;
      _dragRects = const <String, Rect>{};
      _dragZones = const <NeoZoneExtent>[];
      _grabMain = 0;
      _anchorCross = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final horizontal = _horizontal;
    final density = widget.state.config.density.scale;
    final descriptors = NeoTopBarModules.descriptors;
    final moduleContext = _moduleContext;

    return GestureDetector(
      // The blank strip's own menu. A **gesture recogniser**, not a raw
      // `Listener`, so the arena decides who gets the secondary button: a pill is
      // wrapped in a recogniser of its own, and a tray icon or a control-centre
      // glyph sits deeper still, so whatever the pointer is actually over wins and
      // this handler only runs on genuinely empty bar. That is what keeps
      // "right-click the pill" and "right-click the tray icon inside it" apart
      // without hit-testing anything here.
      //
      // `opaque` keeps the empty stretches between zones hit-testable: without it
      // the strip only counts as hit where a child is, and a right-click a few
      // pixels away from the last pill would fall through to the wallpaper.
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => openNeoBarMenu(
        context: context,
        services: widget.services,
        monitorId: widget.monitorId,
        position: details.globalPosition,
      ),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        // Safety net for the drag state. The long-press callbacks normally end a
        // drag, but if the pointer is ever released without reaching them the bar
        // would stay in the preview layout, which has no long-press handlers — so
        // nothing would be draggable again until the shell restarted.
        onPointerUp: (_) => _endDragIfActive(),
        onPointerCancel: (_) => _endDragIfActive(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final measuredCross =
                (horizontal ? size.height : size.width) - _crossPadding * 2;
            _pillCrossExtent = measuredCross > 0
                ? measuredCross
                : _pillCrossExtent;
            // While dragging, the order on screen is a preview of the drop; the
            // same pure function that will be persisted produces it.
            final draggingId = _draggingId;
            final targetZone = _targetZone;
            final config = draggingId != null && targetZone != null
                ? moveModuleToSlot(
                    config: widget.state.config,
                    descriptors: descriptors,
                    instanceId: draggingId,
                    targetZone: targetZone,
                    beforeId: _targetBeforeId,
                  )
                : widget.state.config;
            final visible = _visiblePlacements(
              config,
              descriptors,
              moduleContext,
            );

            // Explicit positions whenever they are known, so that *any* change of
            // order animates — a drag, or a reorder from the settings card. The
            // flex layout is the fallback for the first frame and for a bar whose
            // content is too wide to place, where scrolling matters more than
            // animation.
            final boxes = _pillBoxes(visible);
            if (boxes != null &&
                neoPillsFit(
                  pills: boxes,
                  mainExtent: horizontal ? size.width : size.height,
                  mainPadding: _mainPadding,
                  gap: _gap(density),
                )) {
              return _buildPositionedLayout(
                context: context,
                theme: theme,
                size: size,
                boxes: boxes,
                visible: visible,
                density: density,
              );
            }
            return _buildFlexLayout(
              context: context,
              theme: theme,
              horizontal: horizontal,
              density: density,
              visible: visible,
            );
          },
        ),
      ),
    );
  }

  /// The measured size of every visible pill, or null when one is still unknown.
  ///
  /// A missing entry means "not measured yet", which is different from a
  /// measured zero: zero is a pill that renders nothing right now, and the
  /// layout is expected to place it without giving it room.
  List<NeoPillBox>? _pillBoxes(List<NeoModulePlacement> visible) {
    final boxes = <NeoPillBox>[];
    for (final placement in visible) {
      final extent = _pillExtents[placement.id];
      if (extent == null) return null;
      boxes.add(
        NeoPillBox(id: placement.id, zone: placement.zone, extent: extent),
      );
    }
    return boxes;
  }

  /// Records a pill's size, straight from the layout pass that produced it.
  ///
  /// Always one frame behind by construction — the value can only be used by the
  /// next build — which is why the flex layout is a fallback rather than a
  /// special case: the two agree on positions, so falling back for a frame is
  /// invisible, and a content change is corrected the frame after it happens.
  void _reportPillExtent(String id, double extent) {
    if (_pillExtents[id] == extent) return;
    // Written without `setState` on purpose: this arrives from `performLayout`,
    // where marking the bar dirty is illegal, and the value cannot be used
    // before the next build anyway. The rebuild is requested below.
    _pillExtents = <String, double>{..._pillExtents, id: extent};
    _requestRelayout();
  }

  /// Rebuilds the bar after the current frame, the earliest legal moment.
  ///
  /// Coalesced: several pills may report in the same layout pass, and one
  /// rebuild serves all of them.
  void _requestRelayout() {
    if (_relayoutScheduled) return;
    _relayoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _relayoutScheduled = false;
      if (mounted) setState(() {});
    });
  }

  /// Wraps a pill so the bar hears about its size from the layout pass itself.
  ///
  /// A pill's size is decided by its own content: the tray grows and shrinks as
  /// status items come and go, the clock's width changes when the minute rolls
  /// over, the media pill collapses when playback stops. Those changes happen in
  /// a frame where only the *pill* is rebuilt — the bar is not dirty — so
  /// measuring from a callback scheduled by the bar's `build` never runs for
  /// that frame, and the layout keeps placing pills by a width that is no longer
  /// true. The symptom is specific and was reported as a bug: the tray pill
  /// shrinks in place instead of hugging the trailing edge, so the gap in front
  /// of it stays bigger than every other gap; and a pill that stops rendering
  /// keeps a hole the size it used to be.
  ///
  /// `performLayout` is the one place where the new size is knowable whatever
  /// caused it, in whichever frame it happens, which is why the report is taken
  /// from there rather than from a `SizeChangedLayoutNotifier`.
  Widget _reportSizeOf(String id, Widget pill) => _PillSizeReporter(
    horizontal: _horizontal,
    onExtent: (extent) => _reportPillExtent(id, extent),
    child: pill,
  );

  /// The resting layout, with every pill at an explicit offset.
  ///
  /// Positions are explicit so that `AnimatedPositioned` can carry a pill to its
  /// new place whenever the order changes — from a drag, or from the settings
  /// card. The pill the user is holding is the exception: it sits under the
  /// pointer and is moved by the grab animation, not by the layout.
  Widget _buildPositionedLayout({
    required BuildContext context,
    required ShellThemeData theme,
    required Size size,
    required List<NeoPillBox> boxes,
    required List<NeoModulePlacement> visible,
    required double density,
  }) {
    final horizontal = _horizontal;
    final draggingId = _draggingId;
    final placed = neoDragLayout(
      pills: boxes,
      mainExtent: horizontal ? size.width : size.height,
      crossExtent: horizontal ? size.height : size.width,
      mainPadding: _mainPadding,
      crossPadding: _crossPadding,
      gap: _gap(density),
    );

    final pointer = _pointerLocal;
    final slots = <_PillSlot>[];
    final children = <Widget>[];
    // The pill the user is holding is collected separately: it is lifted, so it
    // has to paint above the rest of the bar. A `Stack` paints in list order,
    // and this one sits at its *preview* position in `boxes` — which put it
    // under every pill that follows it, and under the ghost as well. The pill
    // under the pointer sliding beneath its neighbours is exactly what was
    // reported.
    final lifted = <Widget>[];
    for (final placement in visible) {
      final id = placement.id;
      final at = placed[id];
      if (at == null) continue;
      final key = _keyFor(id);
      slots.add(_PillSlot(id: id, zone: placement.zone, key: key));

      final held = id == draggingId && pointer != null;
      final heldCentre = held ? _feedbackCentre(pointer) : null;
      // `at.main` is a leading edge, `_feedbackCentre` is the pill's middle, so
      // the held pill subtracts half of itself on both axes to stay centred
      // under the pointer exactly where `_grabMain`/`_anchorCross` put it.
      final main = heldCentre == null
          ? at.main
          : (horizontal ? heldCentre.dx : heldCentre.dy) - at.extent / 2;
      final cross = heldCentre == null
          ? at.cross
          : (horizontal ? heldCentre.dy : heldCentre.dx) - at.crossExtent / 2;
      final pill = AnimatedPositioned(
        key: ValueKey<String>('neo-pill-$id'),
        // Zero while held: the grab animation already carries that pill, and
        // letting the layout chase it too would ease everything twice. The
        // moment the drag ends this returns to the settle duration, which is
        // what glides the pill from the pointer into its new slot.
        duration: held ? Duration.zero : Motion.cardSettle,
        curve: Motion.standard,
        left: horizontal ? main : cross,
        top: horizontal ? cross : main,
        // Positioned by its leading edge with no size along the main axis, so a
        // pill keeps sizing itself from its content; the measured extent is only
        // used to work out where the next pill goes.
        width: horizontal ? null : at.crossExtent,
        height: horizontal ? at.crossExtent : null,
        child: _reportSizeOf(
          id,
          _DraggablePill(
            key: key,
            id: id,
            onDragStart: _startDrag,
            onDragUpdate: _updateDrag,
            onDragEnd: _endDrag,
            onDragCancel: _clearDrag,
            onSecondaryTap: (position) =>
                _openPillSettings(context, id, position),
            child: _module(context, id, placement.moduleId),
          ),
        ),
      );
      (held ? lifted : children).add(pill);
    }
    _slots = slots;

    // The silhouette marking the gap the held pill would drop into. Above the
    // resting pills — it is in a free slot, so it must not be hidden by a
    // neighbour if the layout has not settled yet — but below the lifted pill.
    if (draggingId != null && placed[draggingId] != null) {
      final at = placed[draggingId]!;
      children.add(
        AnimatedPositioned(
          key: ValueKey<String>('neo-ghost-$draggingId'),
          duration: Motion.cardSettle,
          curve: Motion.standard,
          left: horizontal ? at.main : at.cross,
          top: horizontal ? at.cross : at.main,
          width: horizontal ? at.extent : at.crossExtent,
          height: horizontal ? at.crossExtent : at.extent,
          child: const _DragPlaceholder(),
        ),
      );
    }
    children.addAll(lifted);

    return Stack(key: _stripKey, children: children);
  }

  /// The fallback layout: zones packed by flex, scrolling if they overflow.
  ///
  /// Also the measuring pass — a pill laid out here reports the size its content
  /// wants, which the explicit layout then positions pills by.
  Widget _buildFlexLayout({
    required BuildContext context,
    required ShellThemeData theme,
    required bool horizontal,
    required double density,
    required List<NeoModulePlacement> visible,
  }) {
    final zones = <NeoZone, List<Widget>>{};
    final slots = <_PillSlot>[];
    for (final placement in visible) {
      final id = placement.id;
      final key = _keyFor(id);
      slots.add(_PillSlot(id: id, zone: placement.zone, key: key));
      (zones[placement.zone] ??= <Widget>[]).add(
        _reportSizeOf(
          id,
          _DraggablePill(
            key: key,
            id: id,
            onDragStart: _startDrag,
            onDragUpdate: _updateDrag,
            onDragEnd: _endDrag,
            onDragCancel: _clearDrag,
            onSecondaryTap: (position) =>
                _openPillSettings(context, id, position),
            child: _module(context, id, placement.moduleId),
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
                width: horizontal ? _gap(density) : 0,
                height: horizontal ? 0 : _gap(density),
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
              ? const EdgeInsets.symmetric(
                  horizontal: _mainPadding,
                  vertical: _crossPadding,
                )
              : const EdgeInsets.symmetric(
                  horizontal: _crossPadding,
                  vertical: _mainPadding,
                ),
          child: layout,
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
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onSecondaryTap,
    required this.child,
    super.key,
  });

  final String id;
  final void Function(String id, Offset globalPosition) onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  /// Right-click on the pill itself: opens this pill's settings at the pointer.
  ///
  /// Only reachable when nothing inside the pill claimed the secondary button —
  /// the tray's own icons and the control-centre glyphs are deeper recognisers and
  /// win the arena first, which is exactly the separation that is wanted.
  final ValueChanged<Offset> onSecondaryTap;
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

  /// The pickup grow, eased over the same span as the centring slide so the two
  /// read as one motion rather than two.
  void _easeTo(double target, String label) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
      return;
    }
    MotionTelemetry.observe(
      _scale,
      _scale.animateTo(target, duration: _pickUpDuration, curve: _pickUpCurve),
      label,
      target: target,
    );
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
        // Right-click belongs to the pill: the settings for *this* pill open at
        // the pointer. Anything interactive inside the pill — a tray icon, a
        // control-centre glyph — is a deeper recogniser, so it takes the secondary
        // button first and this never fires. Left clicks still fall through to the
        // card, which owns the primary tap.
        // `onSecondaryTapUp`, not `...Down`: a nested pair of tap recognisers
        // both fire their *down* callback once the 100ms deadline passes, so a
        // held right-click on a pill would open both this card and whatever the
        // inner target did. The up callback is guarded by the arena win, so
        // exactly one handler — the innermost — ever runs.
        onSecondaryTapUp: (details) =>
            widget.onSecondaryTap(details.globalPosition),
        // Long-press opens the arena's other side: a fast drag rejects it (the
        // 18px slop), so flicking across the bar never starts a reorder.
        onLongPressStart: (details) {
          _easeTo(_liftedScale, 'neo_top_bar.pill_lift');
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
          child: widget.child,
        ),
      ),
    );
  }
}

/// Reports a pill's size along the bar's main axis, from inside the layout pass.
///
/// The bar places pills by their measured size, and a pill's size is decided by
/// its own content, in frames the bar itself does not rebuild. `performLayout`
/// is the only place where the new size is knowable whatever changed it, so the
/// report is taken here rather than from a post-frame read or a
/// `SizeChangedLayoutNotifier`: there is nothing to schedule and nothing to
/// interpret, the size simply is what it is at that moment.
///
/// It reports **only on change**, and only the main axis. The cross axis is
/// fixed by the layout (`AnimatedPositioned` gives the pill an explicit cross
/// size), so a change there carries no information; the first layout always
/// reports, which is what fills the bar's table of sizes on start-up.
///
/// The callback runs during layout and must therefore not rebuild anything
/// synchronously — `_reportPillExtent` records the value and asks for a rebuild
/// after the frame.
class _PillSizeReporter extends SingleChildRenderObjectWidget {
  const _PillSizeReporter({
    required this.horizontal,
    required this.onExtent,
    required super.child,
  });

  /// Which of the pill's dimensions is the bar's main axis.
  final bool horizontal;

  final ValueChanged<double> onExtent;

  @override
  _RenderPillSizeReporter createRenderObject(BuildContext context) =>
      _RenderPillSizeReporter(horizontal: horizontal, onExtent: onExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPillSizeReporter renderObject,
  ) {
    renderObject
      ..horizontal = horizontal
      ..onExtent = onExtent;
  }
}

class _RenderPillSizeReporter extends RenderProxyBox {
  _RenderPillSizeReporter({required this.horizontal, required this.onExtent});

  bool horizontal;
  ValueChanged<double> onExtent;

  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final size = this.size;
    if (size == _reported) return;
    _reported = size;
    onExtent(horizontal ? size.width : size.height);
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
