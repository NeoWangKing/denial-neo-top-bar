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
