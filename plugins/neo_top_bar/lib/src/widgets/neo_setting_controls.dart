/// The two controls a module's settings are built from.
///
/// They live here rather than inside the settings panel because modules draw
/// their own settings: a module row must look like the row above it, and three
/// slightly different toggles in one card is exactly the kind of drift that
/// makes a panel feel assembled rather than designed.
library;

import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';

/// Label and description on the left, a control on the right.
class NeoSettingRow extends StatelessWidget {
  const NeoSettingRow({
    required this.label,
    required this.description,
    required this.child,
    super.key,
  });

  final String label;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.text.systemBarValue.copyWith(fontSize: 13),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.text.systemBarCaption.copyWith(
                      fontSize: 11.5,
                      color: theme.colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

/// On/off switch with an optional disabled state.
///
/// [onChanged] is null when the setting cannot be changed right now — the last
/// enabled pill glyph, for instance — and the switch then shows as dimmed rather
/// than silently ignoring the click.
class NeoSettingToggle extends StatelessWidget {
  const NeoSettingToggle({
    required this.value,
    required this.onChanged,
    this.tooltip,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final enabled = onChanged != null;
    Widget toggle = Semantics(
      toggled: value,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44,
            height: 24,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value
                  ? (enabled
                        ? theme.accent
                        : theme.accent.withValues(alpha: 0.45))
                  : theme.colors.tileOff,
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
    if (tooltip case final tooltip?) {
      toggle = Tooltip(message: tooltip, child: toggle);
    }
    return toggle;
  }
}

/// A row of mutually exclusive choices, drawn the way Denial's own settings draw
/// them: one bordered chip per choice, spaced apart, the selected one filled with
/// a translucent accent and outlined in the accent colour.
///
/// One rounded rectangle per choice on purpose. An earlier version was a single
/// plate with an accent-coloured segment inside it, and two rounded rectangles
/// sharing an edge anti-alias against each other — the selected segment's corners
/// came out ragged. It is also the shape the rest of Denial uses.
class NeoSettingChips<T> extends StatelessWidget {
  const NeoSettingChips({
    required this.values,
    required this.selected,
    required this.onSelected,
    this.enabled,
    super.key,
  });

  final Map<T, String> values;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Whether a choice can be picked at all. Choices that cannot are shown
  /// dimmed rather than hidden, so the setting still says what is coming.
  final bool Function(T value)? enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    explicitChildNodes: true,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in values.entries)
          _SettingChip(
            label: entry.value,
            selected: entry.key == selected,
            onPressed: enabled == null || enabled!(entry.key)
                ? () => onSelected(entry.key)
                : null,
          ),
      ],
    ),
  );
}

class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;

  /// Null disables the chip.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final enabled = onPressed != null;
    final accent = theme.accent;
    return Semantics(
      checked: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: AnimatedContainer(
              duration: Motion.cardSettle,
              curve: Motion.standard,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: enabled ? 0.22 : 0.10)
                    : theme.colors.tileOff,
                borderRadius: theme.borderRadius(theme.chipRadius),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: enabled ? 1 : 0.45)
                      : theme.colors.hairline,
                ),
              ),
              child: Text(
                label,
                style: theme.text.systemBarCaption.copyWith(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: !enabled
                      ? theme.colors.textTertiary
                      : (selected ? accent : theme.colors.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group of settings inside an expanded row.
class NeoSettingGroup extends StatelessWidget {
  const NeoSettingGroup({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.text.systemBarCaption.copyWith(
            fontSize: 12,
            color: theme.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }
}
