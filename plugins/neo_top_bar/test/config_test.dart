import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

const _descriptors = <NeoModuleDescriptor>[
  NeoModuleDescriptor(
    id: 'tray',
    label: 'Tray',
    description: '',
    zone: NeoZone.start,
    priority: 10,
  ),
  NeoModuleDescriptor(
    id: 'workspaces',
    label: 'Workspaces',
    description: '',
    zone: NeoZone.center,
    priority: 10,
  ),
  NeoModuleDescriptor(
    id: 'clock',
    label: 'Clock',
    description: '',
    zone: NeoZone.end,
    priority: 10,
  ),
  NeoModuleDescriptor(
    id: 'cpu',
    label: 'CPU',
    description: '',
    zone: NeoZone.end,
    priority: 50,
    defaultEnabled: false,
  ),
];

List<String> _ids(List<NeoModulePlacement> placements) =>
    placements.map((placement) => placement.descriptor.id).toList();

void main() {
  group('NeoTopBarConfig.fromJson', () {
    test('treats a missing schema as no configuration', () {
      final config = NeoTopBarConfig.fromJson(<String, Object?>{
        'modules': <String, Object?>{
          'tray': <String, Object?>{'enabled': false},
        },
      });
      expect(config.modules, isEmpty);
    });

    test('rejects a newer schema instead of guessing at it', () {
      final config = NeoTopBarConfig.fromJson(<String, Object?>{
        'schema': neoTopBarConfigSchema + 1,
        'modules': <String, Object?>{
          'tray': <String, Object?>{'enabled': false},
        },
      });
      expect(config.modules, isEmpty);
    });

    test('reads per-module overrides and the saved order', () {
      final config = NeoTopBarConfig.fromJson(<String, Object?>{
        'schema': 1,
        'modules': <String, Object?>{
          'tray': <String, Object?>{'enabled': false},
          'cpu': <String, Object?>{'enabled': true, 'zone': 'start'},
        },
        'order': <String, Object?>{
          'start': <Object?>['cpu', 'tray'],
        },
      });
      expect(config.isEnabled(_descriptors[0]), isFalse);
      expect(config.isEnabled(_descriptors[3]), isTrue);
      expect(config.zoneOf(_descriptors[3]), NeoZone.start);
      expect(config.order[NeoZone.start], <String>['cpu', 'tray']);
    });

    test('drops duplicate order entries and unknown zone names', () {
      final config = NeoTopBarConfig.fromJson(<String, Object?>{
        'schema': 1,
        'order': <String, Object?>{
          'start': <Object?>['tray', 'tray', 7, ''],
          'nowhere': <Object?>['tray'],
        },
      });
      expect(config.order[NeoZone.start], <String>['tray']);
      expect(config.order.containsKey(NeoZone.center), isFalse);
    });

    test('round-trips through toJson', () {
      final original = NeoTopBarConfig.fromJson(<String, Object?>{
        'schema': 1,
        'modules': <String, Object?>{
          'cpu': <String, Object?>{'enabled': true, 'zone': 'start'},
        },
        'order': <String, Object?>{
          'start': <Object?>['cpu'],
        },
      });
      final restored = NeoTopBarConfig.fromJson(original.toJson());
      expect(restored.isEnabled(_descriptors[3]), isTrue);
      expect(restored.zoneOf(_descriptors[3]), NeoZone.start);
      expect(restored.order[NeoZone.start], <String>['cpu']);
    });
  });

  group('resolvePlacements', () {
    test('uses descriptor defaults for a fresh configuration', () {
      final placements = resolvePlacements(
        descriptors: _descriptors,
        config: NeoTopBarConfig.empty,
      );
      expect(_ids(placements), <String>['tray', 'workspaces', 'clock', 'cpu']);
      expect(
        placements
            .where((placement) => placement.enabled)
            .map((p) => p.descriptor.id),
        <String>['tray', 'workspaces', 'clock'],
      );
    });

    test('keeps disabled modules in the list so they can be re-enabled', () {
      final config = NeoTopBarConfig.empty.withPreference(
        'tray',
        const NeoModulePreference(enabled: false),
      );
      final placements = resolvePlacements(
        descriptors: _descriptors,
        config: config,
      );
      expect(_ids(placements), contains('tray'));
      expect(
        placements.firstWhere((p) => p.descriptor.id == 'tray').enabled,
        isFalse,
      );
    });

    test('honours a saved order inside a zone', () {
      final config = NeoTopBarConfig(
        order: <NeoZone, List<String>>{
          NeoZone.end: <String>['cpu', 'clock'],
        },
      );
      final placements = resolvePlacements(
        descriptors: _descriptors,
        config: config,
      );
      expect(_ids(placements), <String>['tray', 'workspaces', 'cpu', 'clock']);
    });

    test('ignores a saved order entry whose module moved zone', () {
      final config = NeoTopBarConfig(
        modules: <String, NeoModulePreference>{
          'clock': const NeoModulePreference(zone: NeoZone.start),
        },
        order: <NeoZone, List<String>>{
          NeoZone.end: <String>['clock', 'cpu'],
        },
      );
      final placements = resolvePlacements(
        descriptors: _descriptors,
        config: config,
      );
      // clock moved to start, so the end zone keeps only cpu.
      expect(_ids(placements), <String>['clock', 'tray', 'workspaces', 'cpu']);
    });

    test('falls back to priority then id for unlisted modules', () {
      final descriptors = <NeoModuleDescriptor>[
        ..._descriptors,
        const NeoModuleDescriptor(
          id: 'aaa',
          label: 'A',
          description: '',
          zone: NeoZone.start,
          priority: 10,
        ),
      ];
      final placements = resolvePlacements(
        descriptors: descriptors,
        config: NeoTopBarConfig.empty,
      );
      expect(_ids(placements).take(2), <String>['aaa', 'tray']);
    });
  });

  group('default layout', () {
    // These expectations read the same constants the bar ships, so a module's
    // zone or priority cannot drift away from what this test asserts. Adding a
    // module to module_defaults.dart without deciding its place here fails the
    // first expectation below.
    test('is workspaces | launcher | tray, status, clock', () {
      final placements = resolvePlacements(
        descriptors: neoTopBarDefaultModules,
        config: NeoTopBarConfig.empty,
      );
      expect(_ids(placements), <String>[
        'workspaces',
        'launcher',
        'tray',
        'notifications',
        'media',
        'battery',
        'cpu',
        'gpu',
        'clock',
      ]);
      expect(
        placements
            .where((placement) => placement.enabled)
            .map((placement) => placement.descriptor.id),
        <String>[
          'workspaces',
          'launcher',
          'tray',
          'notifications',
          'battery',
          'clock',
        ],
      );
    });

    test('keeps the workspaces pill leading and the clock trailing', () {
      expect(workspacesModule.zone, NeoZone.start);
      expect(clockModule.zone, NeoZone.end);
      // Regression guard: the tray belongs on the trailing side with the other
      // status pills, not next to the workspaces.
      expect(trayModule.zone, NeoZone.end);
      expect(
        trayModule.priority,
        lessThan(clockModule.priority),
        reason: 'the tray must sit inboard of the clock',
      );
    });

    test('declares every id exactly once', () {
      final ids = neoTopBarDefaultModules
          .map((descriptor) => descriptor.id)
          .toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('keeps NeoModuleIds in step with the descriptors', () {
      // NeoModuleIds is the persisted, public spelling of each id. If a
      // descriptor and the ids class disagree, a saved user choice would silently
      // stop matching its module.
      final declared = <String>[
        NeoModuleIds.workspaces,
        NeoModuleIds.launcher,
        NeoModuleIds.tray,
        NeoModuleIds.notifications,
        NeoModuleIds.media,
        NeoModuleIds.battery,
        NeoModuleIds.cpu,
        NeoModuleIds.gpu,
        NeoModuleIds.clock,
      ];
      expect(declared.toSet(), hasLength(declared.length));
      expect(
        neoTopBarDefaultModules.map((descriptor) => descriptor.id).toSet(),
        declared.toSet(),
      );
    });
  });

  group('prune', () {
    test('drops ids the current build does not know', () {
      final config = NeoTopBarConfig(
        modules: <String, NeoModulePreference>{
          'tray': const NeoModulePreference(enabled: false),
          'ghost': const NeoModulePreference(enabled: true),
        },
        order: <NeoZone, List<String>>{
          NeoZone.start: <String>['ghost', 'tray'],
        },
      );
      final pruned = config.prune(_descriptors);
      expect(pruned.modules.keys, <String>['tray']);
      expect(pruned.order[NeoZone.start], <String>['tray']);
    });
  });

  group('neoBuildMonthGrid', () {
    test('always returns six full weeks', () {
      final days = neoBuildMonthGrid(
        DateTime(2026, 2, 15),
        today: DateTime(2026, 2, 15),
      );
      expect(days, hasLength(42));
    });

    test('marks today and out-of-month cells', () {
      final days = neoBuildMonthGrid(
        DateTime(2026, 2, 1),
        today: DateTime(2026, 2, 15),
      );
      final today = days.where((day) => day.isToday).toList();
      expect(today, hasLength(1));
      expect(today.single.date, DateTime(2026, 2, 15));
      expect(today.single.inMonth, isTrue);
    });

    test('starts a Monday-first grid on Monday', () {
      // 2026-02-01 is a Sunday, so the Monday-first grid must back up six days.
      final days = neoBuildMonthGrid(
        DateTime(2026, 2, 1),
        today: DateTime(2026, 2, 1),
      );
      expect(days.first.date, DateTime(2026, 1, 26));
      expect(days.first.date.weekday, DateTime.monday);
    });

    test('honours a Sunday-first grid', () {
      final days = neoBuildMonthGrid(
        DateTime(2026, 2, 1),
        today: DateTime(2026, 2, 1),
        weekStartsOn: DateTime.sunday,
      );
      expect(days.first.date.weekday, DateTime.sunday);
      expect(days.first.date, DateTime(2026, 2, 1));
    });

    test('handles a leap month', () {
      final days = neoBuildMonthGrid(
        DateTime(2028, 2, 10),
        today: DateTime(2028, 2, 10),
      );
      expect(
        days.where((day) => day.inMonth).map((day) => day.date.day),
        containsAll(<int>[28, 29]),
      );
    });
  });

  group('month arithmetic', () {
    test('adds across a year boundary in both directions', () {
      expect(neoAddMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 1));
      expect(neoAddMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 1));
      // June 2026 minus 18 months is December 2024, not January 2025.
      expect(neoAddMonths(DateTime(2026, 6, 15), -18), DateTime(2024, 12, 1));
    });

    test('reports month length including February', () {
      expect(neoDaysInMonth(DateTime(2026, 2, 1)), 28);
      expect(neoDaysInMonth(DateTime(2028, 2, 1)), 29);
      expect(neoDaysInMonth(DateTime(2026, 4, 1)), 30);
    });
  });

  group('moveModuleInZone', () {
    List<String> zoneOrder(NeoTopBarConfig config, NeoZone zone) => <String>[
      for (final placement in resolvePlacements(
        descriptors: neoTopBarDefaultModules,
        config: config,
      ))
        if (placement.zone == zone) placement.descriptor.id,
    ];

    test('materializes the effective order on the first move', () {
      // Nothing was ever ordered, so a move must derive the starting list from
      // the registry defaults before swapping anything. Default end-zone order:
      // tray, notifications, media, battery, cpu, gpu, clock.
      final moved = moveModuleInZone(
        config: NeoTopBarConfig.empty,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.battery,
        offset: -1,
      );
      expect(moved.order[NeoZone.end], <String>[
        NeoModuleIds.tray,
        NeoModuleIds.notifications,
        NeoModuleIds.battery,
        NeoModuleIds.media,
        NeoModuleIds.cpu,
        NeoModuleIds.gpu,
        NeoModuleIds.clock,
      ]);
    });

    test('moves a module one place toward the front of its zone', () {
      final before = zoneOrder(NeoTopBarConfig.empty, NeoZone.end);
      expect(before.first, NeoModuleIds.tray);
      final moved = moveModuleInZone(
        config: NeoTopBarConfig.empty,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.notifications,
        offset: -1,
      );
      final after = zoneOrder(moved, NeoZone.end);
      expect(after.take(2).toList(), <String>[
        NeoModuleIds.notifications,
        NeoModuleIds.tray,
      ]);
      // Same members, only reordered.
      expect(after.toSet(), before.toSet());
    });

    test('is a no-op at the zone boundaries', () {
      final config = NeoTopBarConfig.empty;
      expect(
        moveModuleInZone(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: NeoModuleIds.tray,
          offset: -1,
        ).order,
        config.order,
      );
      expect(
        moveModuleInZone(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: NeoModuleIds.clock,
          offset: 1,
        ).order,
        config.order,
      );
    });

    test('fills in the rest of the zone before moving', () {
      // Only two of the seven end-zone modules are listed. The move has to
      // resolve the complete zone order first, swap inside it, and keep the
      // unlisted modules after the ones the user ordered.
      final config = NeoTopBarConfig(
        order: <NeoZone, List<String>>{
          NeoZone.end: <String>[NeoModuleIds.media, NeoModuleIds.tray],
        },
      );
      final moved = moveModuleInZone(
        config: config,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.media,
        offset: 1,
      );
      expect(zoneOrder(moved, NeoZone.end), <String>[
        NeoModuleIds.tray,
        NeoModuleIds.media,
        NeoModuleIds.notifications,
        NeoModuleIds.battery,
        NeoModuleIds.cpu,
        NeoModuleIds.gpu,
        NeoModuleIds.clock,
      ]);
    });

    test('reorders inside the zone a module was moved to', () {
      final config = NeoTopBarConfig.empty.withPreference(
        NeoModuleIds.clock,
        const NeoModulePreference(zone: NeoZone.start),
      );
      final moved = moveModuleInZone(
        config: config,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.clock,
        offset: 1,
      );
      expect(zoneOrder(moved, NeoZone.start), <String>[
        NeoModuleIds.workspaces,
        NeoModuleIds.clock,
      ]);
      expect(
        zoneOrder(moved, NeoZone.end),
        isNot(contains(NeoModuleIds.clock)),
      );
    });

    test('ignores an unknown id and a zero offset', () {
      final config = NeoTopBarConfig.empty;
      expect(
        moveModuleInZone(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: 'ghost',
          offset: 1,
        ).order,
        isEmpty,
      );
      expect(
        moveModuleInZone(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: NeoModuleIds.tray,
          offset: 0,
        ).order,
        isEmpty,
      );
    });
  });

  group('moveModuleToSlot', () {
    List<String> zoneOrder(NeoTopBarConfig config, NeoZone zone) => <String>[
      for (final placement in resolvePlacements(
        descriptors: neoTopBarDefaultModules,
        config: config,
      ))
        if (placement.zone == zone) placement.descriptor.id,
    ];

    test('drops a module before another one in the same zone', () {
      final moved = moveModuleToSlot(
        config: NeoTopBarConfig.empty,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.clock,
        targetZone: NeoZone.end,
        beforeId: NeoModuleIds.tray,
      );
      expect(zoneOrder(moved, NeoZone.end).first, NeoModuleIds.clock);
      expect(zoneOrder(moved, NeoZone.end).toSet(), <String>{
        NeoModuleIds.tray,
        NeoModuleIds.notifications,
        NeoModuleIds.media,
        NeoModuleIds.battery,
        NeoModuleIds.cpu,
        NeoModuleIds.gpu,
        NeoModuleIds.clock,
      });
    });

    test('appends when the drop gap is past the last pill', () {
      final moved = moveModuleToSlot(
        config: NeoTopBarConfig.empty,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.tray,
        targetZone: NeoZone.end,
        beforeId: null,
      );
      expect(zoneOrder(moved, NeoZone.end).last, NeoModuleIds.tray);
    });

    test('dragging into another zone changes both zone and order', () {
      final moved = moveModuleToSlot(
        config: NeoTopBarConfig.empty,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.clock,
        targetZone: NeoZone.start,
        beforeId: null,
      );
      expect(zoneOrder(moved, NeoZone.start), <String>[
        NeoModuleIds.workspaces,
        NeoModuleIds.clock,
      ]);
      expect(
        zoneOrder(moved, NeoZone.end),
        isNot(contains(NeoModuleIds.clock)),
      );
      // A zone override is recorded because start is not the descriptor default.
      expect(moved.modules[NeoModuleIds.clock]?.zone, NeoZone.start);
    });

    test('drops the zone override when a module lands back home', () {
      final away = moveModuleToSlot(
        config: NeoTopBarConfig.empty,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.clock,
        targetZone: NeoZone.start,
        beforeId: null,
      );
      expect(away.modules[NeoModuleIds.clock]?.zone, NeoZone.start);
      final home = moveModuleToSlot(
        config: away,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.clock,
        targetZone: NeoZone.end,
        beforeId: null,
      );
      expect(home.modules[NeoModuleIds.clock]?.zone, isNull);
      expect(zoneOrder(home, NeoZone.end).last, NeoModuleIds.clock);
    });

    test('leaves no stale entry in the zone it left', () {
      final config = NeoTopBarConfig(
        order: <NeoZone, List<String>>{
          NeoZone.end: <String>[
            NeoModuleIds.tray,
            NeoModuleIds.clock,
            NeoModuleIds.battery,
          ],
        },
      );
      final moved = moveModuleToSlot(
        config: config,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.clock,
        targetZone: NeoZone.center,
        beforeId: null,
      );
      expect(moved.order[NeoZone.end], isNot(contains(NeoModuleIds.clock)));
      expect(moved.order[NeoZone.center], contains(NeoModuleIds.clock));
    });

    test('preserves an existing enabled preference while moving', () {
      final config = NeoTopBarConfig.empty.withPreference(
        NeoModuleIds.media,
        const NeoModulePreference(enabled: true),
      );
      final moved = moveModuleToSlot(
        config: config,
        descriptors: neoTopBarDefaultModules,
        moduleId: NeoModuleIds.media,
        targetZone: NeoZone.start,
        beforeId: null,
      );
      expect(moved.modules[NeoModuleIds.media]?.enabled, isTrue);
      expect(moved.modules[NeoModuleIds.media]?.zone, NeoZone.start);
    });

    test('ignores unknown ids and a drop on itself', () {
      final config = NeoTopBarConfig.empty;
      expect(
        moveModuleToSlot(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: 'ghost',
          targetZone: NeoZone.end,
          beforeId: NeoModuleIds.tray,
        ).order,
        isEmpty,
      );
      expect(
        moveModuleToSlot(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: NeoModuleIds.tray,
          targetZone: NeoZone.end,
          beforeId: NeoModuleIds.tray,
        ).order,
        isEmpty,
      );
      expect(
        moveModuleToSlot(
          config: config,
          descriptors: neoTopBarDefaultModules,
          moduleId: NeoModuleIds.tray,
          targetZone: NeoZone.end,
          beforeId: 'ghost',
        ).order,
        isEmpty,
      );
    });
  });

  group('neoDropZoneAt', () {
    // A bar with one pill on the left, one in the middle and one on the right,
    // i.e. huge empty stretches between the zones.
    const workspacesStart = NeoZoneExtent(
      zone: NeoZone.start,
      start: 20,
      end: 140,
    );
    const launcherStart = NeoZoneExtent(
      zone: NeoZone.center,
      start: 1160,
      end: 1320,
    );
    const trayStart = NeoZoneExtent(zone: NeoZone.end, start: 1780, end: 1900);
    const extents = <NeoZoneExtent>[workspacesStart, launcherStart, trayStart];

    test('returns the zone whose pills the pointer is over', () {
      expect(
        neoDropZoneAt(mainAxisPosition: 80, zoneExtents: extents),
        NeoZone.start,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 1200, zoneExtents: extents),
        NeoZone.center,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 1850, zoneExtents: extents),
        NeoZone.end,
      );
    });

    test('keeps the whole of a pill in its own zone', () {
      // Regression: dropping on the trailing half of the last pill of a zone
      // used to fall through to the next zone.
      expect(
        neoDropZoneAt(mainAxisPosition: 139, zoneExtents: extents),
        NeoZone.start,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 21, zoneExtents: extents),
        NeoZone.start,
      );
    });

    test('splits the empty stretch at its midpoint', () {
      // Gap runs 140..1160, so the boundary is 650.
      expect(
        neoDropZoneAt(mainAxisPosition: 500, zoneExtents: extents),
        NeoZone.start,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 800, zoneExtents: extents),
        NeoZone.center,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 650, zoneExtents: extents),
        NeoZone.center,
      );
    });

    test('clamps positions outside every extent', () {
      expect(
        neoDropZoneAt(mainAxisPosition: -400, zoneExtents: extents),
        NeoZone.start,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 4000, zoneExtents: extents),
        NeoZone.end,
      );
    });

    test('handles a single zone and no zones', () {
      expect(
        neoDropZoneAt(
          mainAxisPosition: 999,
          zoneExtents: const <NeoZoneExtent>[launcherStart],
        ),
        NeoZone.center,
      );
      expect(
        neoDropZoneAt(mainAxisPosition: 999, zoneExtents: const []),
        isNull,
      );
    });
  });
}
