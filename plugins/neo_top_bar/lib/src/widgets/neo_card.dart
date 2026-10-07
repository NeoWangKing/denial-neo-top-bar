/// Shared pill-card chrome for bar modules.
///
/// Modules must not re-implement the bar's fill, radius, or blur: every card
/// goes through [NeoCard] so a theme change lands everywhere at once. The blur
/// is per-card, matching Denial's own bar, and stays outside any opacity
/// animation because a backdrop filter inside a fade layer would sample the
/// layer instead of the scene behind it.
library;

import 'package:denial_flutter_sdk/effects.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';

class NeoCard extends StatelessWidget {
  const NeoCard({
    required this.child,
    required this.accent,
    this.density = 1.0,
    this.horizontal = true,
    this.padding,
    super.key,
  });

  final Widget child;
  final WallpaperAccent accent;
  final double density;
  final bool horizontal;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final radius = theme.borderRadius(999);
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: 12 * density,
          vertical: horizontal ? 0 : 12 * density,
        );
    return ShellBackdropBlur(
      blur: theme.effectiveCardOpacity < 1.0,
      borderRadius: radius,
      // The bar often lands on fractional physical pixels at scaled outputs.
      // Keeping srcOver preserves the wallpaper under the rounded clip's
      // antialiasing fringe instead of replacing partial coverage with the
      // filter layer's transparent black.
      blendMode: BlendMode.srcOver,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.cardColor(accent.cardFillTop(theme)),
              theme.cardColor(accent.cardFill(theme)),
            ],
          ),
          borderRadius: radius,
        ),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}

/// A [NeoCard] that behaves as one control.
///
/// Hover and focus cannot use a semi-transparent overlay colour: that creates a
/// second layer over the glass. The base gradient is interpolated toward the
/// accent instead, so the highlight costs no extra layer and needs no fade.
class NeoCardButton extends StatefulWidget {
  const NeoCardButton({
    required this.child,
    required this.accent,
    required this.onPressed,
    this.tooltip,
    this.density = 1.0,
    this.horizontal = true,
    this.padding,
    super.key,
  });

  final Widget child;
  final WallpaperAccent accent;
  final VoidCallback onPressed;
  final String? tooltip;
  final double density;
  final bool horizontal;
  final EdgeInsetsGeometry? padding;

  @override
  State<NeoCardButton> createState() => _NeoCardButtonState();
}

class _NeoCardButtonState extends State<NeoCardButton>
    with SingleTickerProviderStateMixin {
  /// A press pops the pill slightly. Kept small because the strip clips: at 1.05
  /// a 45px-tall pill grows about a pixel per edge, so nothing is visibly cut
  /// off. Raise this for a punchier pop.
  static const double _pressedScale = 1.05;

  /// The controller's value *is* the scale, so the spring drives it directly.
  ///
  /// Unbounded on purpose: [Motion.bouncy] overshoots on the way back, which is
  /// the rebound. A plain [Transform] is used rather than [ShellFadeScale]
  /// because a fade wrapper would put a layer around the pill's
  /// [ShellBackdropBlur], which then samples that layer instead of the wallpaper.
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool _hovered = false;
  bool _focused = false;

  /// Whether the primary button is currently down on this pill. Pointer-up
  /// events carry no button mask, so the press has to be remembered to match it
  /// with the release.
  bool _pressed = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _press() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = _pressedScale;
      return;
    }
    springTo(
      _scale,
      _pressedScale,
      spring: Motion.snappy,
      telemetryLabel: 'neo_top_bar.pill_press',
    );
  }

  void _release() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = 1;
      return;
    }
    springTo(
      _scale,
      1,
      spring: Motion.bouncy,
      telemetryLabel: 'neo_top_bar.pill_release',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final radius = theme.borderRadius(999);
    final active = _hovered || _focused;
    final topFill = active
        ? Color.lerp(widget.accent.cardFillTop(theme), theme.accent, 0.12)!
        : widget.accent.cardFillTop(theme);
    final bottomFill = active
        ? Color.lerp(widget.accent.cardFill(theme), theme.accent, 0.08)!
        : widget.accent.cardFill(theme);
    final resolvedPadding =
        widget.padding ??
        EdgeInsets.symmetric(
          horizontal: 12 * widget.density,
          vertical: widget.horizontal ? 0 : 12 * widget.density,
        );

    // Animated rather than swapped: the highlight used to land in one frame,
    // which is what made hovering feel abrupt. Only the decoration animates, so
    // no layer is created and the blur keeps sampling the scene.
    Widget content = ShellBackdropBlur(
      blur: theme.effectiveCardOpacity < 1.0,
      borderRadius: radius,
      blendMode: BlendMode.srcOver,
      child: AnimatedContainer(
        duration: Motion.cardSettle,
        curve: Motion.standard,
        padding: resolvedPadding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.cardColor(topFill), theme.cardColor(bottomFill)],
          ),
          borderRadius: radius,
          border: _focused
              ? Border.all(color: theme.accent.withValues(alpha: 0.78))
              : null,
        ),
        child: widget.child,
      ),
    );

    content = Semantics(
      button: true,
      label: widget.tooltip,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: FocusableActionDetector(
              onShowFocusHighlight: (value) => setState(() => _focused = value),
              child: content,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip case final tooltip?) {
      content = Tooltip(message: tooltip, child: content);
    }
    // A raw Listener, not the tap callbacks: with the long-press drag recogniser
    // competing for the pointer, the tap recogniser does not fire `onTapDown`
    // until it wins the arena or its 100ms deadline expires, and a quick click
    // releases in the same frame — so the pop would be started and cancelled
    // before it moved. A Listener does not join the arena and fires on the down
    // event itself, so the press feedback is immediate. It also does not consume
    // anything, so the tap still reaches the pill.
    return Listener(
      onPointerDown: (event) {
        if (event.buttons != kPrimaryButton) return;
        _pressed = true;
        _press();
      },
      onPointerUp: (_) => _handleRelease(),
      onPointerCancel: (_) => _handleRelease(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: content,
      ),
    );
  }

  void _handleRelease() {
    if (!_pressed) return;
    _pressed = false;
    _release();
  }
}
