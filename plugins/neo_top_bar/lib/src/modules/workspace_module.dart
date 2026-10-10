/// Workspace indicator: one pill showing every workspace, the active one, which
/// ones hold windows, and — when the user asks for it — those windows themselves
/// as small icons inside each workspace's cell.
///
/// Placement is the user's choice, so this module never assumes it sits in the
/// middle of the bar. Everything about *which* icon goes in *which* cell is
/// decided by `core/workspace_windows.dart`, which is pure and tested; this file
/// only draws the result.
library;

import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/theme.dart';
// Material rather than widgets for `Tooltip`, which a window icon needs so it can
// say which window it is.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n_context.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../core/workspace_options.dart';
import '../core/workspace_windows.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_setting_controls.dart';

class WorkspaceModule implements NeoModule, NeoModuleSettings {
  const WorkspaceModule();

  @override
  NeoModuleDescriptor get descriptor => workspacesModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _WorkspaceContent(module: module);

  /// One switch: whether each cell carries its windows' icons. Default off, so a
  /// bar that never asked for this looks exactly as it did before.
  @override
  Widget buildSettings(BuildContext context, NeoModuleSettingsScope scope) {
    final s = context.neoStrings;
    final options = neoWorkspaceOptions(scope.options);
    return NeoSettingGroup(
      title: s.moduleLabel(NeoModuleIds.workspaces),
      children: [
        NeoSettingRow(
          label: s.workspaceShowWindows,
          description: s.workspaceShowWindowsHint,
          child: NeoSettingToggle(
            value: options.showWindowIcons,
            onChanged: (value) => scope.setOption(
              neoWorkspaceShowWindowsKey,
              value ? true : null,
            ),
          ),
        ),
      ],
    );
  }
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
    final options = neoWorkspaceOptions(module.options);
    // The window snapshot is only watched when the icons are actually drawn: it
    // rebuilds on every window event, and a dot-only indicator has no reason to
    // pay for that.
    final windows = options.showWindowIcons
        ? ref.watch(
            shellControllerProvider.select((state) => state.openAppWindows),
          )
        : const <DenialWindow>[];
    final cells = <int, NeoWorkspaceCell>{
      if (options.showWindowIcons)
        for (final cell in neoWorkspaceWindowCells(
          windows: <NeoWorkspaceWindow>[
            for (final window in windows)
              NeoWorkspaceWindow(
                objectId: window.objectId,
                appId: window.appId,
                title: window.title.isEmpty ? window.appId : window.title,
                workspaceId: window.workspaceId,
                monitorId: window.monitorId,
                minimized: window.minimized,
                pinned: window.pinned,
                focused: window.objectId == _focusedObjectId(ref),
              ),
          ],
          monitorId: module.monitorId,
          workspaceCount: status.count,
          activeWorkspace: status.active,
        ))
          cell.workspace: cell,
    };

    void activate(NeoWorkspaceWindow target) {
      // A sticky window is already on screen wherever the user is, so it needs
      // no workspace switch; anything else is on another workspace, and Denial
      // focuses a window only once its workspace is the active one.
      if (!target.pinned && target.workspaceId != status.active) {
        services.switchWorkspace(
          monitorId: module.monitorId,
          workspaceId: target.workspaceId,
        );
      }
      for (final window in windows) {
        if (window.objectId != target.objectId) continue;
        ref.read(shellControllerProvider.notifier).focusWindow(window);
        return;
      }
    }

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
        _WorkspaceCell(
          workspace: workspace,
          active: workspace == status.active,
          occupied: status.occupied.contains(workspace),
          accent: module.accent,
          strings: services.strings(context),
          services: services,
          module: module,
          cell: cells[workspace],
          onSelected: () => services.switchWorkspace(
            monitorId: module.monitorId,
            workspaceId: workspace,
          ),
          onActivate: activate,
        ),
      );
    }
    return NeoCard(
      accent: module.accent,
      density: module.density,
      horizontal: horizontal,
      padding: EdgeInsets.symmetric(
        // A vertical pill is only as wide as the strip; see `neoCardPadding`.
        horizontal: (horizontal ? 12 : 6) * module.density,
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

/// The window Denial has focused, from the snapshot the module already watches.
int? _focusedObjectId(WidgetRef ref) => ref.watch(
  shellControllerProvider.select((state) => state.foregroundObjectId),
);

/// One workspace: a dot, plus its windows' icons when the option is on.
///
/// With the option off this is exactly the plain dot the pill has always drawn.
/// With it on, the cell becomes a small pill of its own — the shape the whole bar
/// speaks in, which is also how niri's own widgets read — and only the active
/// cell carries a fill, so the eye still lands on the current workspace first.
class _WorkspaceCell extends StatelessWidget {
  const _WorkspaceCell({
    required this.workspace,
    required this.active,
    required this.occupied,
    required this.accent,
    required this.strings,
    required this.services,
    required this.module,
    required this.cell,
    required this.onSelected,
    required this.onActivate,
  });

  final int workspace;
  final bool active;
  final bool occupied;
  final WallpaperAccent accent;
  final ShellStrings strings;
  final ShellServices services;
  final NeoModuleContext module;
  final NeoWorkspaceCell? cell;
  final VoidCallback onSelected;
  final ValueChanged<NeoWorkspaceWindow> onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final colors = theme.colors;
    final horizontal = module.horizontal;
    final base = active
        ? theme.accent
        : occupied
        ? colors.textSecondary
        : colors.textTertiary;
    final windows = cell?.windows ?? const <NeoWorkspaceWindow>[];
    final hidden = cell?.hidden ?? 0;
    final iconSize = module.glyphSize(0.40, min: 10, max: 16);
    final gap = 3 * module.density;

    // Plain painted boxes: no blur, no offscreen layer. Switching workspaces
    // animates a size change only, which keeps the indicator allocation-free.
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: active ? 10 : 6,
      height: active ? 10 : 6,
      decoration: BoxDecoration(
        color: base.withValues(alpha: active ? 1.0 : 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    final content = <Widget>[
      SizedBox(
        width: horizontal ? 22 : 18,
        height: horizontal ? 18 : 22,
        child: Center(child: dot),
      ),
    ];
    for (final window in windows) {
      content.add(
        SizedBox(width: horizontal ? gap : 0, height: horizontal ? 0 : gap),
      );
      content.add(
        _WorkspaceWindowIcon(
          window: window,
          services: services,
          size: iconSize,
          onActivate: () => onActivate(window),
        ),
      );
    }
    if (hidden > 0) {
      content.add(
        SizedBox(width: horizontal ? gap : 0, height: horizontal ? 0 : gap),
      );
      content.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 1 * module.density),
          child: Text(
            '+$hidden',
            style: ShellText.systemBarCaption.copyWith(
              fontSize: 10,
              color: colors.textTertiary,
            ),
          ),
        ),
      );
    }

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              // The fill only appears once a cell has icons to hold: a dot-only
              // indicator keeps the bare look it has always had.
              padding: windows.isEmpty
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(
                      horizontal: (horizontal ? 5 : 3) * module.density,
                      vertical: (horizontal ? 3 : 5) * module.density,
                    ),
              decoration: BoxDecoration(
                color: windows.isEmpty
                    ? const Color(0x00000000)
                    : active
                    ? accent.cardFill(theme).withValues(alpha: 0.55)
                    : colors.surfaceContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Flex(
                direction: horizontal ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One window inside a workspace cell, focused by clicking it.
///
/// This sits inside the cell's own tap target; the deeper gesture wins the
/// arena, so clicking an icon focuses that window and clicking the rest of the
/// cell switches to the workspace.
class _WorkspaceWindowIcon extends StatelessWidget {
  const _WorkspaceWindowIcon({
    required this.window,
    required this.services,
    required this.size,
    required this.onActivate,
  });

  final NeoWorkspaceWindow window;
  final ShellServices services;
  final double size;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Tooltip(
      message: window.title,
      child: Semantics(
        button: true,
        label: window.title,
        onTap: onActivate,
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onActivate,
              child: Padding(
                padding: EdgeInsets.all(size * 0.10),
                child: Opacity(
                  // A minimized window keeps its place but reads as hidden, the
                  // same treatment the launcher gives it.
                  opacity: window.minimized ? 0.55 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: window.focused
                          ? theme.accent.withValues(alpha: 0.30)
                          : const Color(0x00000000),
                      borderRadius: theme.borderRadius(size),
                    ),
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: services.buildApplicationIcon(
                        context,
                        window.appId,
                      ),
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
