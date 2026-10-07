/// Shared chrome for bar-owned popup panels.
///
/// Popups are transient UI, not plugin contributions: they are created through
/// Denial's popup host so dismissal, focus and input lifetime stay managed by
/// the shell.
library;

import 'package:denial_flutter_sdk/effects.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/popup_geometry.dart';

/// A panel card, attached to the control that opened it, inside its own output.
///
/// Three separate requirements, each of which was its own bug:
///
/// 1. **Break the host's tight constraints.** The popup host expands every popup
///    to the whole scene with tight constraints. The centered fallback therefore
///    goes through [Center] before limiting its size; without that a bare
///    [ConstrainedBox] cannot shrink tight constraints and the card is stretched
///    to the full screen — which also covers the host's outside-tap scrim and
///    makes the panel look impossible to close.
/// 2. **Attach to the control**, not the middle of the screen. When [anchor] is
///    known the card hangs just below (or above) it, with their trailing edges
///    lined up.
/// 3. **Stay inside the owning output.** The Flutter scene spans every monitor,
///    so both placement and the centered fallback are computed against
///    `monitorBounds(monitorId)` rather than the whole scene.
class NeoPopupSurface extends ConsumerWidget {
  const NeoPopupSurface({
    required this.child,
    required this.services,
    required this.monitorId,
    this.anchor,
    this.maxWidth = 420,
    this.maxHeight = 620,
    super.key,
  });

  final Widget child;

  /// Host services, used to read this output's bounds in scene coordinates.
  final ShellServices services;

  /// Output this panel belongs to; the bar's monitor for bar-owned panels.
  final int monitorId;

  /// Scene-space rectangle of the control that opened the panel. When null the
  /// card falls back to centering inside the output.
  final Rect? anchor;

  /// Preferred card width, also used for exact horizontal clamping.
  final double maxWidth;

  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitorBounds = ref.watch(services.monitorBounds(monitorId));
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          // Without a measurable scene there is nothing to place against; still
          // center the card in whatever space the host provided.
          return _centered(maxWidth, maxHeight, child);
        }
        final size = constraints.biggest;
        final scene = NeoSceneRect(
          left: 0,
          top: 0,
          width: size.width,
          height: size.height,
        );
        final monitor = _toSceneRect(monitorBounds);
        final output = monitor == null || monitor.isEmpty ? scene : monitor;
        final anchorRect = _toSceneRect(anchor);

        final placement = anchorRect == null
            ? null
            : neoAnchoredPopupPlacement(
                scene: scene,
                output: output,
                anchor: anchorRect,
                width: maxWidth,
                maxHeight: maxHeight,
              );

        if (placement == null) {
          // No usable anchor, or no room beside it: center inside the output.
          // Padding rather than Positioned keeps the card's own Center working.
          final insets = neoPopupTargetPadding(
            scene: scene,
            target: neoPopupTargetRect(scene: scene, monitor: monitor),
          );
          return Padding(
            padding: EdgeInsets.only(
              left: insets.left,
              top: insets.top,
              right: insets.right,
              bottom: insets.bottom,
            ),
            child: _centered(maxWidth, maxHeight, child),
          );
        }

        return Stack(
          children: [
            Positioned(
              left: placement.left,
              top: placement.top,
              bottom: placement.bottom,
              width: placement.width,
              child: _NeoPopupCard(
                // The Positioned supplies a tight width and the card hugs its
                // content, so it hangs right under the control instead of
                // filling the strip below it.
                maxWidth: placement.width,
                maxHeight: placement.maxHeight,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _centered(double maxWidth, double maxHeight, Widget child) =>
      SafeArea(
        // Denial's own detail popups use this shape, which keeps the fallback
        // consistent with the rest of the shell.
        minimum: const EdgeInsets.all(16),
        child: Center(
          child: _NeoPopupCard(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            child: child,
          ),
        ),
      );

  /// Adapts the host's `Rect?` to the pure-geometry type.
  static NeoSceneRect? _toSceneRect(Rect? rect) => rect == null
      ? null
      : NeoSceneRect(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
        );
}

class _NeoPopupCard extends StatelessWidget {
  const _NeoPopupCard({
    required this.child,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final radius = theme.panelRadius;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: ShellBackdropBlur(
        // The foreground must paint after the backdrop assignment, so the
        // panel's own controls stay out of the filter's colour layer. This
        // requires the default `BlendMode.src`; overriding the blend mode would
        // trip the widget's assert.
        separateChild: true,
        blur: theme.effectivePanelOpacity < 1.0,
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.panelColor(theme.colors.panelBackground),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.colors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A small icon button used inside popup panels.
class NeoPopupIconButton extends StatefulWidget {
  const NeoPopupIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  State<NeoPopupIconButton> createState() => _NeoPopupIconButtonState();
}

class _NeoPopupIconButtonState extends State<NeoPopupIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    Widget content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? theme.colors.chip : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.roundButtonRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(widget.icon, size: 18, color: theme.colors.textPrimary),
          ),
        ),
      ),
    );
    if (widget.tooltip case final tooltip?) {
      content = Tooltip(message: tooltip, child: content);
    }
    return content;
  }
}
