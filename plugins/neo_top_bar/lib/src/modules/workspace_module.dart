/// Workspace indicator: one pill showing every workspace, the active one, and
/// which ones hold windows.
///
/// Placement is the user's choice, so this module never assumes it sits in the
/// middle of the bar.
library;

import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_card.dart';

class WorkspaceModule implements NeoModule {
  const WorkspaceModule();

  @override
  NeoModuleDescriptor get descriptor => workspacesModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _WorkspaceContent(module: module);
}

class _WorkspaceContent extends ConsumerWidget {
  const _WorkspaceContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = module.services;
    // Workspaces can be disabled in Denial's layout settings. The widget can
    // read the provider safely because it only ever builds inside the scope.
    if (!ref.watch(services.workspacesEnabled)) {
      return const SizedBox.shrink();
    }
    final status = ref.watch(services.workspace(module.monitorId));
    if (status.count <= 0) return const SizedBox.shrink();

    final horizontal = module.horizontal;
    final children = <Widget>[];
    for (var workspace = 1; workspace <= status.count; workspace++) {
      if (workspace > 1) {
        children.add(
          SizedBox(
            width: horizontal ? 6 * module.density : 0,
            height: horizontal ? 0 : 6 * module.density,
          ),
        );
      }
      children.add(
        _WorkspaceDot(
          workspace: workspace,
          active: workspace == status.active,
          occupied: status.occupied.contains(workspace),
          accent: module.accent,
          strings: services.strings(context),
          onSelected: () => services.switchWorkspace(
            monitorId: module.monitorId,
            workspaceId: workspace,
          ),
        ),
      );
    }
    return NeoCard(
      accent: module.accent,
      density: module.density,
      horizontal: horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * module.density,
        vertical: horizontal ? 0 : 12 * module.density,
      ),
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _WorkspaceDot extends StatelessWidget {
  const _WorkspaceDot({
    required this.workspace,
    required this.active,
    required this.occupied,
    required this.accent,
    required this.strings,
    required this.onSelected,
  });

  final int workspace;
  final bool active;
  final bool occupied;
  final WallpaperAccent accent;
  final ShellStrings strings;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final colors = theme.colors;
    final base = active
        ? theme.accent
        : occupied
        ? colors.textSecondary
        : colors.textTertiary;
    // Plain painted boxes: no blur, no offscreen layer. Switching workspaces
    // animates a size change only, which keeps the indicator allocation-free.
    return Semantics(
      button: true,
      selected: active,
      label: strings.workspaceLabel(workspace),
      onTap: onSelected,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSelected,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: active ? 10 : 6,
                  height: active ? 10 : 6,
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: active ? 1.0 : 0.82),
                    borderRadius: BorderRadius.circular(999),
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
