/// Grouping rules behind the workspace pill's window icons.
///
/// Deliberately free of Flutter and of the SDK's window model: the module maps
/// `DenialWindow` into [NeoWorkspaceWindow], and every decision with an edge —
/// which workspace a window belongs to, where a pinned window is drawn, what
/// happens when one workspace holds more windows than fit, and the order the
/// icons appear in — is made here, where it can be unit-tested. The widget only
/// draws the result.
library;

/// How many window icons one workspace cell shows.
///
/// Three, because a workspace cell is itself a small pill inside the bar's pill:
/// past three it stops reading as "one workspace". What does not fit is reported
/// as `+N`, the same way the launcher caps its window strip.
const int neoWorkspaceWindowIconLimit = 3;

/// One window, reduced to what a workspace cell draws.
class NeoWorkspaceWindow {
  const NeoWorkspaceWindow({
    required this.objectId,
    required this.appId,
    required this.title,
    required this.workspaceId,
    required this.monitorId,
    this.minimized = false,
    this.pinned = false,
    this.focused = false,
  });

  /// Stable identity while the window is open; also the draw order.
  final int objectId;

  final String appId;

  /// Shown as the icon's tooltip and read out by screen readers.
  final String title;

  final int workspaceId;

  /// Output the window is on; each bar instance draws only its own.
  final int monitorId;

  /// A minimized window stays in its own workspace's cell, dimmed: the pill
  /// reports what the workspace holds, not only what is on screen right now.
  final bool minimized;

  /// A pinned (sticky) window is visible on every workspace. Drawing it in every
  /// cell would repeat one icon up to nine times, so it is collected into the
  /// cell the user is actually looking at — the active workspace.
  final bool pinned;

  /// The window Denial currently has focused, which gets the accent plate.
  final bool focused;
}

/// The windows one workspace cell draws, already capped.
class NeoWorkspaceCell {
  const NeoWorkspaceCell({
    required this.workspace,
    required this.windows,
    required this.hidden,
  });

  final int workspace;

  /// At most [neoWorkspaceWindowIconLimit] windows, pinned first.
  final List<NeoWorkspaceWindow> windows;

  /// How many windows of this workspace did not fit, drawn as `+N`.
  final int hidden;

  /// Whether the cell holds anything at all. An empty cell still exists — the
  /// workspace itself is what the user clicks.
  bool get isEmpty => windows.isEmpty && hidden == 0;
}

/// The cells for one bar, in workspace order (Denial numbers them from 1).
///
/// [windows] may contain every window of every output; only [monitorId]'s are
/// used, because a bar shows its own output's workspaces. A window whose
/// workspace no longer exists is dropped: the compositor clamps those when the
/// workspace count shrinks, so this is only defence against a stale snapshot.
List<NeoWorkspaceCell> neoWorkspaceWindowCells({
  required Iterable<NeoWorkspaceWindow> windows,
  required int monitorId,
  required int workspaceCount,
  required int activeWorkspace,
  int limit = neoWorkspaceWindowIconLimit,
}) {
  if (workspaceCount <= 0 || limit <= 0) return const <NeoWorkspaceCell>[];
  final byWorkspace = <int, List<NeoWorkspaceWindow>>{
    for (var workspace = 1; workspace <= workspaceCount; workspace++)
      workspace: <NeoWorkspaceWindow>[],
  };
  final sticky = <NeoWorkspaceWindow>[];
  for (final window in windows) {
    if (window.monitorId != monitorId) continue;
    if (window.pinned) {
      sticky.add(window);
      continue;
    }
    byWorkspace[window.workspaceId]?.add(window);
  }
  // Sticky windows are on screen whichever workspace is active, so that is the
  // cell that reports them.
  byWorkspace[activeWorkspace]?.addAll(sticky);

  return <NeoWorkspaceCell>[
    for (var workspace = 1; workspace <= workspaceCount; workspace++)
      _cell(workspace, byWorkspace[workspace]!, limit),
  ];
}

NeoWorkspaceCell _cell(
  int workspace,
  List<NeoWorkspaceWindow> windows,
  int limit,
) {
  if (windows.isEmpty) {
    return NeoWorkspaceCell(
      workspace: workspace,
      windows: const <NeoWorkspaceWindow>[],
      hidden: 0,
    );
  }
  // Pinned first, then by identity: a window that opens later takes the last
  // slot, so the icons already on screen never reshuffle just because something
  // new appeared.
  final ordered = List<NeoWorkspaceWindow>.of(windows)
    ..sort((left, right) {
      if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
      return left.objectId.compareTo(right.objectId);
    });
  final shown = ordered.length > limit ? ordered.sublist(0, limit) : ordered;
  return NeoWorkspaceCell(
    workspace: workspace,
    windows: List<NeoWorkspaceWindow>.unmodifiable(shown),
    hidden: ordered.length - shown.length,
  );
}
