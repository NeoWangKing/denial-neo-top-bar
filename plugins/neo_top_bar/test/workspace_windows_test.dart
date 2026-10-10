import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

NeoWorkspaceWindow window(
  int objectId, {
  int workspace = 1,
  int monitorId = 1,
  bool minimized = false,
  bool pinned = false,
  bool focused = false,
  String? appId,
}) => NeoWorkspaceWindow(
  objectId: objectId,
  appId: appId ?? 'app$objectId',
  title: 'window $objectId',
  workspaceId: workspace,
  monitorId: monitorId,
  minimized: minimized,
  pinned: pinned,
  focused: focused,
);

void main() {
  group('neoWorkspaceOptions', () {
    test('drawing icons is off until it is asked for', () {
      expect(
        neoWorkspaceOptions(const <String, Object?>{}).showWindowIcons,
        isFalse,
      );
      expect(neoWorkspaceOptions(const <String, Object?>{}).isDefault, isTrue);
    });

    test('a stored choice is honoured, and anything else reads as off', () {
      expect(
        neoWorkspaceOptions(<String, Object?>{neoWorkspaceShowWindowsKey: true})
            .showWindowIcons,
        isTrue,
      );
      for (final value in <Object?>[false, 'true', 1, null]) {
        expect(
          neoWorkspaceOptions(<String, Object?>{
            neoWorkspaceShowWindowsKey: value,
          }).showWindowIcons,
          isFalse,
          reason: '$value',
        );
      }
    });
  });

  group('neoWorkspaceWindowCells', () {
    test('produces one cell per workspace, in order, empty ones included', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[],
        monitorId: 1,
        workspaceCount: 4,
        activeWorkspace: 2,
      );
      expect(cells.map((cell) => cell.workspace), <int>[1, 2, 3, 4]);
      expect(cells.every((cell) => cell.isEmpty), isTrue);
    });

    test('puts each window in its own workspace', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[
          window(1, workspace: 1),
          window(2, workspace: 3),
          window(3, workspace: 1),
        ],
        monitorId: 1,
        workspaceCount: 3,
        activeWorkspace: 1,
      );
      expect(cells[0].windows.map((w) => w.objectId), <int>[1, 3]);
      expect(cells[1].isEmpty, isTrue);
      expect(cells[2].windows.map((w) => w.objectId), <int>[2]);
    });

    test('ignores windows on another output', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[
          window(1, monitorId: 2),
          window(2, monitorId: 1),
        ],
        monitorId: 1,
        workspaceCount: 2,
        activeWorkspace: 1,
      );
      expect(cells[0].windows.map((w) => w.objectId), <int>[2]);
      expect(cells[1].isEmpty, isTrue);
    });

    test('caps a busy workspace at the limit and counts the rest', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[
          for (var id = 1; id <= 7; id++) window(id, workspace: 2),
        ],
        monitorId: 1,
        workspaceCount: 2,
        activeWorkspace: 2,
      );
      expect(cells[1].windows, hasLength(neoWorkspaceWindowIconLimit));
      expect(cells[1].windows.map((w) => w.objectId), <int>[1, 2, 3]);
      expect(cells[1].hidden, 4);
    });

    test('a later window takes the last slot instead of reshuffling', () {
      final before = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[window(4), window(2)],
        monitorId: 1,
        workspaceCount: 1,
        activeWorkspace: 1,
      );
      final after = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[window(4), window(2), window(9)],
        monitorId: 1,
        workspaceCount: 1,
        activeWorkspace: 1,
      );
      expect(before.single.windows.map((w) => w.objectId), <int>[2, 4]);
      expect(after.single.windows.map((w) => w.objectId), <int>[2, 4, 9]);
      expect(after.single.hidden, 0);
    });

    test('sticky windows are drawn once, in the active cell', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[
          window(1, workspace: 3, pinned: true),
          window(2, workspace: 3),
        ],
        monitorId: 1,
        workspaceCount: 3,
        activeWorkspace: 2,
      );
      expect(cells[1].windows.map((w) => w.objectId), <int>[1]);
      expect(cells[2].windows.map((w) => w.objectId), <int>[2]);
    });

    test(
      'sticky windows come first, so the fixed ones never lose their slot',
      () {
        final cells = neoWorkspaceWindowCells(
          windows: <NeoWorkspaceWindow>[
            for (var id = 1; id <= 4; id++) window(id, workspace: 1),
            window(99, workspace: 5, pinned: true),
          ],
          monitorId: 1,
          workspaceCount: 1,
          activeWorkspace: 1,
        );
        expect(cells.single.windows.map((w) => w.objectId), <int>[99, 1, 2]);
        expect(cells.single.hidden, 2);
      },
    );

    test('minimized windows keep their place', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[window(1, workspace: 1, minimized: true)],
        monitorId: 1,
        workspaceCount: 1,
        activeWorkspace: 1,
      );
      expect(cells.single.windows.single.minimized, isTrue);
    });

    test('a window whose workspace no longer exists is not drawn', () {
      final cells = neoWorkspaceWindowCells(
        windows: <NeoWorkspaceWindow>[
          window(1, workspace: 9),
          window(2, workspace: 1),
        ],
        monitorId: 1,
        workspaceCount: 2,
        activeWorkspace: 1,
      );
      expect(cells.expand((cell) => cell.windows).map((w) => w.objectId), <int>[
        2,
      ]);
    });

    test('a disabled or empty bar draws no cells at all', () {
      for (final count in <int>[0, -1]) {
        expect(
          neoWorkspaceWindowCells(
            windows: <NeoWorkspaceWindow>[window(1)],
            monitorId: 1,
            workspaceCount: count,
            activeWorkspace: 1,
          ),
          isEmpty,
          reason: '$count',
        );
      }
      expect(
        neoWorkspaceWindowCells(
          windows: <NeoWorkspaceWindow>[window(1)],
          monitorId: 1,
          workspaceCount: 2,
          activeWorkspace: 1,
          limit: 0,
        ),
        isEmpty,
      );
    });
  });
}
