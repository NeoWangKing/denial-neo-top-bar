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
        'control_center',
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
          'control_center',
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
        NeoModuleIds.controlCenter,
        NeoModuleIds.clock,
      ];
      expect(declared.toSet(), hasLength(declared.length));
      expect(
        neoTopBarDefaultModules.map((descriptor) => descriptor.id).toSet(),
        declared.toSet(),
      );
    });
  });

  group('per-module settings', () {
    test('round-trips through JSON', () {
      final config = NeoTopBarConfig.empty.withOption(
        'control_center',
        'glyphs',
        <String>['volume', 'battery'],
      );
      final restored = NeoTopBarConfig.fromJson(config.toJson());
      expect(restored.optionsOf('control_center'), <String, Object?>{
        'glyphs': <String>['volume', 'battery'],
      });
    });

    test('a module with only settings still gets an entry', () {
      final config = NeoTopBarConfig.empty.withOption('clock', 'format', '24h');
      expect(config.modules.containsKey('clock'), isTrue);
      expect(config.isEnabled(clockModule), isTrue);
      expect(config.zoneOf(clockModule), NeoZone.end);
    });

    test('clearing the last setting drops the whole entry', () {
      final withOption = NeoTopBarConfig.empty.withOption(
        'clock',
        'format',
        '24h',
      );
      final cleared = withOption.withOption('clock', 'format', null);
      expect(cleared.modules, isEmpty);
      expect(cleared.optionsOf('clock'), isEmpty);
    });

    test('toggling a module keeps its zone and its settings', () {
      // Regression guard: the config state used to build a fresh preference from
      // scratch, which silently forgot the zone the user had chosen and would
      // now forget every module-specific setting as well.
      final moved = NeoTopBarConfig.empty
          .withPreference('clock', NeoModulePreference(zone: NeoZone.start))
          .withOption('clock', 'format', '24h');
      final toggled = moved.withPreference(
        'clock',
        moved.modules['clock']!.withEnabled(false),
      );
      expect(toggled.zoneOf(clockModule), NeoZone.start);
      expect(toggled.optionsOf('clock'), <String, Object?>{'format': '24h'});
      expect(toggled.isEnabled(clockModule), isFalse);
    });

    test('moving a module keeps its settings', () {
      final moved = NeoTopBarConfig.empty
          .withOption('clock', 'format', '24h')
          .withPreference(
            'clock',
            (NeoTopBarConfig.empty
                    .withOption('clock', 'format', '24h')
                    .modules['clock'])!
                .withZone(NeoZone.start),
          );
      expect(moved.optionsOf('clock'), <String, Object?>{'format': '24h'});
      expect(moved.zoneOf(clockModule), NeoZone.start);
    });

    test('drops values a JSON file could not round-trip', () {
      final restored = NeoTopBarConfig.fromJson(<String, Object?>{
        'schema': 1,
        'modules': <String, Object?>{
          'clock': <String, Object?>{
            'options': <String, Object?>{
              'format': '24h',
              'broken': Object(),
              'nested': <String, Object?>{'ok': true, 'broken': Object()},
            },
          },
        },
      });
      // The whole value is dropped rather than partly repaired: a module should
      // never be handed a half-filtered structure that nothing could have
      // written, and the option falls back to its default instead.
      expect(restored.optionsOf('clock'), <String, Object?>{'format': '24h'});
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
      // tray, notifications, media, battery, cpu, gpu, control centre, clock.
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
        NeoModuleIds.controlCenter,
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
        NeoModuleIds.controlCenter,
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
        NeoModuleIds.controlCenter,
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

  group('neoDragLayout', () {
    Map<String, NeoPlacedPill> layout(List<NeoPillBox> pills) => neoDragLayout(
      pills: pills,
      mainExtent: 1000,
      crossExtent: 55,
      mainPadding: 8,
      crossPadding: 5,
      gap: 6,
    );

    test('pins the start zone to the leading edge', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        NeoPillBox(id: 'b', zone: NeoZone.start, extent: 50),
      ]);
      expect(placed['a']!.main, 8);
      expect(placed['b']!.main, 8 + 100 + 6);
    });

    test('pins the end zone to the trailing edge', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.end, extent: 100),
        NeoPillBox(id: 'b', zone: NeoZone.end, extent: 50),
      ]);
      // total = 100 + 6 + 50, so the group ends 8 from the right edge.
      expect(placed['a']!.main, 1000 - 8 - 156);
      expect(placed['b']!.main, 1000 - 8 - 50);
    });

    test('centres the centre zone in the strip', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.center, extent: 100),
      ]);
      expect(placed['a']!.main, 450);
    });

    test('keeps all three zones independent', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'l', zone: NeoZone.start, extent: 100),
        NeoPillBox(id: 'm', zone: NeoZone.center, extent: 60),
        NeoPillBox(id: 'r', zone: NeoZone.end, extent: 80),
      ]);
      expect(placed['l']!.main, 8);
      expect(placed['m']!.main, 470);
      expect(placed['r']!.main, 1000 - 8 - 80);
    });

    test('stretches every pill across the padded cross axis', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
      ]);
      expect(placed['a']!.cross, 5);
      expect(placed['a']!.crossExtent, 45);
    });

    test('places nothing for the zones that have no pills', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'm', zone: NeoZone.center, extent: 60),
      ]);
      expect(placed.keys, <String>['m']);
    });

    test('gives up rather than placing into a degenerate strip', () {
      expect(
        neoDragLayout(
          pills: const <NeoPillBox>[
            NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
          ],
          mainExtent: 0,
          crossExtent: 55,
          mainPadding: 8,
          crossPadding: 5,
          gap: 6,
        ),
        isEmpty,
      );
      expect(
        neoDragLayout(
          pills: const <NeoPillBox>[
            NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
          ],
          mainExtent: 1000,
          crossExtent: 10,
          mainPadding: 8,
          crossPadding: 5,
          gap: 6,
        ),
        isEmpty,
      );
    });

    test('a reordered pill lands where the flex layout would put it', () {
      // Same three pills, one moved from the end zone into the start zone. The
      // remaining end-zone pill has to slide to the trailing edge.
      final before = layout(const <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        NeoPillBox(id: 'b', zone: NeoZone.end, extent: 60),
        NeoPillBox(id: 'c', zone: NeoZone.end, extent: 40),
      ]);
      final after = layout(const <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        NeoPillBox(id: 'b', zone: NeoZone.start, extent: 60),
        NeoPillBox(id: 'c', zone: NeoZone.end, extent: 40),
      ]);
      expect(before['b']!.main, 1000 - 8 - 106);
      expect(after['b']!.main, 8 + 100 + 6);
      expect(after['c']!.main, 1000 - 8 - 40);
    });

    test('a pill that renders nothing reserves neither room nor a gap', () {
      // The media pill with no player, an empty tray: still placed — it has to
      // stay mounted to be able to come back — but collapsed and taking no gap.
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'tray', zone: NeoZone.end, extent: 100),
        NeoPillBox(id: 'media', zone: NeoZone.end, extent: 0),
        NeoPillBox(id: 'battery', zone: NeoZone.end, extent: 60),
      ]);
      // Only two pills occupy room, so exactly one gap: the same as if the
      // hidden pill did not exist at all.
      expect(placed['battery']!.main, 1000 - 8 - 60);
      expect(placed['tray']!.main, 1000 - 8 - 166);
      expect(placed['media']!.extent, 0);
      expect(placed['media']!.main, 1000 - 8 - 166);
      // Three pills of these widths with two gaps would have been 4px further
      // left for the tray, which is the hole this rule removes.
      expect(placed['tray']!.main, isNot(1000 - 8 - 172));
    });

    test('a zero-extent pill in an otherwise empty zone is still placed', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'ghost', zone: NeoZone.center, extent: 0),
      ]);
      expect(placed['ghost']!.extent, 0);
      expect(placed['ghost']!.main, 500);
    });

    test('the centre zone centres the pills that occupy room', () {
      final placed = layout(const <NeoPillBox>[
        NeoPillBox(id: 'ghost', zone: NeoZone.center, extent: 0),
        NeoPillBox(id: 'real', zone: NeoZone.center, extent: 100),
      ]);
      expect(placed['real']!.main, 450);
      expect(placed['ghost']!.main, 450);
    });
  });

  group('neoPillsFit', () {
    bool fits(List<NeoPillBox> pills, double main) =>
        neoPillsFit(pills: pills, mainExtent: main, mainPadding: 8, gap: 6);

    test('counts both paddings and the gaps between sized pills', () {
      // 8 + 100 + 6 + 50 + 8 = 172
      const pills = <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        NeoPillBox(id: 'b', zone: NeoZone.end, extent: 50),
      ];
      expect(fits(pills, 172), isTrue);
      expect(fits(pills, 171), isFalse);
    });

    test('ignores pills that occupy no room', () {
      const pills = <NeoPillBox>[
        NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        NeoPillBox(id: 'ghost', zone: NeoZone.start, extent: 0),
        NeoPillBox(id: 'b', zone: NeoZone.start, extent: 50),
      ];
      // One gap, not two: 8 + 100 + 6 + 50 + 8.
      expect(fits(pills, 172), isTrue);
      expect(fits(pills, 171), isFalse);
    });

    test('one pill needs no gap', () {
      expect(
        fits(const <NeoPillBox>[
          NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        ], 116),
        isTrue,
      );
      expect(
        fits(const <NeoPillBox>[
          NeoPillBox(id: 'a', zone: NeoZone.start, extent: 100),
        ], 115),
        isFalse,
      );
    });

    test('an empty bar fits anything, including nothing', () {
      expect(fits(const <NeoPillBox>[], 16), isTrue);
      expect(fits(const <NeoPillBox>[], 15), isFalse);
    });
  });
}
